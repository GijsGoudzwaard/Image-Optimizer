using Gtk;

public class List {

  /**
   * The images that are currently known to the list.
   *
   * @var Image[]
   */
  private Image[] images;

  /**
   * Backing model of the column view. Holds one ImageRow per image.
   *
   * @var GLib.ListStore
   */
  private GLib.ListStore listmodel;

  /**
   * The bar under the list, showing progress and then the result.
   *
   * @var SummaryBar
   */
  private SummaryBar summary;

  /**
   * Everything that was ever added to the list.
   *
   * These counters are only ever touched from apply_result and the two methods
   * that add images, all of which run on the main loop, so they need no locking
   * of their own.
   *
   * @var uint
   */
  private uint total_files = 0;

  /**
   * Everything that is no longer pending, whatever became of it.
   *
   * @var uint
   */
  private uint finished_files = 0;

  /**
   * Files that came out smaller than they went in.
   *
   * @var uint
   */
  private uint optimized_files = 0;

  /**
   * Files the app could not write.
   *
   * @var uint
   */
  private uint failed_files = 0;

  /**
   * Files no optimizer here can do anything with.
   *
   * @var uint
   */
  private uint unsupported_files = 0;

  /**
   * Original size of the optimized files only.
   *
   * Files that were already optimal are left out on purpose. Counting them
   * would drag the percentage down with files there was nothing to be done
   * about, which reads as a worse result than the app delivered.
   *
   * @var int64
   */
  private int64 total_before = 0;

  /**
   * New size of the same files.
   *
   * @var int64
   */
  private int64 total_after = 0;

  /**
   * Returns the text a column should show for a given row.
   */
  private delegate string CellText (ImageRow row);

  /**
   * Whether that text is a word standing in for a number, which is shown a
   * shade back from the numbers around it.
   */
  private delegate bool CellMuted (ImageRow row);

  public List (Image[] images) {
    this.images = images;
  }

  public Gtk.Box window () {
    var main = new Gtk.ScrolledWindow ();
    main.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);

    this.listmodel = new GLib.ListStore (typeof (ImageRow));
    this.summary = new SummaryBar ();

    foreach (var image in this.images) {
      this.listmodel.append (new ImageRow (image));
    }

    // NoSelection: the list is a progress report, there is nothing to select.
    var view = new Gtk.ColumnView (new Gtk.NoSelection (this.listmodel));
    view.add_css_class ("tree_view");
    // The columns have one right order and the widths are fixed, so there is
    // nothing to gain from being able to drag them about.
    view.set_reorderable (false);
    main.set_child (view);

    // The widths are fixed rather than shared out evenly, so a number never
    // moves when the one beside it grows a digit. Each one is the width of the
    // text plus the 10px gap in front of it, and the last one carries the 14px
    // the window keeps free on the right.
    view.append_column (this.status_column ());
    view.append_column (this.name_column ());
    view.append_column (this.text_column (_("Size"), 1, 88, 10, 0, (row) => row.size_text, (row) => row.status == Status.UNSUPPORTED));
    view.append_column (this.text_column (_("New size"), 1, 92, 10, 0, (row) => row.new_size_text, (row) => row.status == Status.FAILED));
    view.append_column (this.text_column (_("Savings"), 1, 94, 10, 14, (row) => row.savings_text, (row) => row.status != Status.OPTIMIZED));

    this.style_headers (view);

    this.start (this.images);

    // The list scrolls, the bar does not: it stays visible at the bottom of the
    // window however long the list gets.
    var container = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

    main.set_vexpand (true);
    container.append (main);
    container.append (this.summary);

    return container;
  }

  /**
   * Take a batch into the counts and hand the part of it that can be optimized
   * to the optimizers.
   *
   * @param  Image[] batch
   * @return void
   */
  private void start (Image[] batch) {
    Image[] to_optimize = {};

    foreach (var image in batch) {
      this.total_files++;

      if (image.supported) {
        to_optimize += image;

        continue;
      }

      // It has a row saying so, but there is nothing to wait for, so it is done
      // the moment it arrives.
      this.unsupported_files++;
      this.finished_files++;
    }

    this.refresh_summary ();

    // Starting the optimizers on an empty batch would spawn workers with nothing
    // to do, which is what happens when every file that was added is one of the
    // types the app turns away.
    if (to_optimize.length == 0) {
      return;
    }

    var optimizer = new Optimizer (to_optimize);
    optimizer.optimize (this);
  }

  /**
   * Hand the current counts to the bar.
   *
   * @return void
   */
  private void refresh_summary () {
    this.summary.update (
      this.finished_files,
      this.total_files,
      this.optimized_files,
      this.failed_files,
      this.unsupported_files,
      this.total_before,
      this.total_after
    );
  }

  /**
   * Build the column in front of every row: a spinner while the image is being
   * worked on, and afterwards an icon saying how it went. Gtk.Spinner animates
   * itself, so unlike Gtk.CellRendererSpinner it does not need to be pulsed
   * from a timeout.
   *
   * @return Gtk.ColumnViewColumn
   */
  private Gtk.ColumnViewColumn status_column () {
    var factory = new Gtk.SignalListItemFactory ();

    factory.setup.connect ((object) => {
      var item = (Gtk.ListItem) object;

      // Both children live in the row and only their visibility changes. A
      // Gtk.Stack would do the same for more code, and the factory reuses these
      // widgets across rows either way.
      var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
      box.set_valign (Gtk.Align.CENTER);
      box.set_margin_start (14);

      var spinner = new Gtk.Spinner ();
      spinner.set_size_request (14, 14);

      var icon = new Gtk.Image ();
      icon.set_pixel_size (14);
      icon.set_visible (false);

      box.append (spinner);
      box.append (icon);

      item.set_child (box);
    });

    factory.bind.connect ((object) => {
      var item = (Gtk.ListItem) object;
      var row = (ImageRow) item.get_item ();
      var box = (Gtk.Box) item.get_child ();
      var spinner = (Gtk.Spinner) box.get_first_child ();
      var icon = (Gtk.Image) box.get_last_child ();

      var pending = row.status == Status.PENDING;

      spinner.set_visible (pending);

      if (pending) {
        spinner.start ();
      } else {
        spinner.stop ();
      }

      if (row.icon_resource != null) {
        icon.set_from_resource (row.icon_resource);
      }

      icon.set_visible (! pending && row.icon_resource != null);
    });

    var column = new Gtk.ColumnViewColumn ("", factory);
    // 14 of padding plus the 20 the icon sits in, so the file name starts at 44.
    column.set_fixed_width (34);

    return column;
  }

  /**
   * The file name, with a second line underneath saying why nothing happened to
   * it. The line only appears on the rows that need it, so a row that came out
   * smaller stays as short as it was.
   *
   * @return Gtk.ColumnViewColumn
   */
  private Gtk.ColumnViewColumn name_column () {
    var factory = new Gtk.SignalListItemFactory ();

    factory.setup.connect ((object) => {
      var item = (Gtk.ListItem) object;

      var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
      box.set_valign (Gtk.Align.CENTER);
      box.set_margin_top (11);
      box.set_margin_bottom (11);
      box.set_margin_start (10);

      // Ellipsized, so a long file name asks for no more room than there is.
      // Without this one long name sets the smallest width the window can have.
      var name = new Gtk.Label (null);
      name.add_css_class ("cell_text");
      name.set_xalign (0);
      name.set_ellipsize (Pango.EllipsizeMode.END);

      var note = new Gtk.Label (null);
      note.add_css_class ("cell_note");
      note.set_xalign (0);
      note.set_ellipsize (Pango.EllipsizeMode.END);

      box.append (name);
      box.append (note);

      item.set_child (box);
    });

    factory.bind.connect ((object) => {
      var item = (Gtk.ListItem) object;
      var row = (ImageRow) item.get_item ();
      var box = (Gtk.Box) item.get_child ();
      var name = (Gtk.Label) box.get_first_child ();
      var note = (Gtk.Label) box.get_last_child ();

      name.set_label (row.image.name);
      note.set_label (row.note ?? "");
      note.set_visible (row.note != null);

    });

    var column = new Gtk.ColumnViewColumn (_("File"), factory);
    column.set_expand (true);

    return column;
  }

  /**
   * Build a column that shows a piece of text per row.
   *
   * @param  string title
   * @param  float xalign  0 to read as text, 1 to line up as a number
   * @param  int width  fixed width in pixels, or -1 to take up the slack
   * @param  int lead  space in front of the text
   * @param  int trail  space behind it, which only the last column needs
   * @param  CellText get_text
   * @param  CellMuted get_muted
   * @return Gtk.ColumnViewColumn
   */
  private Gtk.ColumnViewColumn text_column (
    string title,
    float xalign,
    int width,
    int lead,
    int trail,
    owned CellText get_text,
    owned CellMuted get_muted
  ) {
    var factory = new Gtk.SignalListItemFactory ();

    factory.setup.connect ((object) => {
      var item = (Gtk.ListItem) object;

      var label = new Gtk.Label (null);
      label.add_css_class ("cell_text");
      label.set_xalign (xalign);
      // Without this the label is only as wide as its text, and then xalign has
      // nothing to align inside.
      label.set_hexpand (true);
      label.set_margin_top (11);
      label.set_margin_bottom (11);

      // The gap belongs in front of the text, so the numbers end where the
      // column does. Only the last column keeps space behind it, which is what
      // the window leaves free on the right.
      if (xalign > 0) {
        label.set_margin_start (lead);
        label.set_margin_end (trail);
      } else {
        label.set_margin_start (lead);
      }

      item.set_child (label);
    });

    factory.bind.connect ((object) => {
      var item = (Gtk.ListItem) object;
      var row = (ImageRow) item.get_item ();
      var label = (Gtk.Label) item.get_child ();

      label.set_label (get_text (row));

      if (get_muted (row)) {
        label.add_css_class ("muted");
      } else {
        label.remove_css_class ("muted");
      }
    });

    var column = new Gtk.ColumnViewColumn (title, factory);

    if (width < 0) {
      column.set_expand (true);
    } else {
      column.set_fixed_width (width);
    }

    return column;
  }

  /**
   * Line the column headings up with the values under them.
   *
   * Gtk.ColumnViewColumn exposes no widget for its heading, so this walks to the
   * labels the column view built for them. It is written to give up quietly
   * rather than to fail: if that structure ever changes the headings stay where
   * GTK put them, which is the way they looked before this existed.
   *
   * @param  Gtk.ColumnView view
   * @return void
   */
  private void style_headers (Gtk.ColumnView view) {
    var header = view.get_first_child ();

    if (header == null) {
      return;
    }

    // One entry per column, in order, with the same numbers the columns above
    // use so a heading sits exactly over its values.
    float[] xalign = { 0, 0, 1, 1, 1 };
    int[] lead = { 0, 10, 10, 10, 10 };
    int[] trail = { 0, 0, 0, 0, 14 };

    var child = header.get_first_child ();
    var index = 0;

    while (child != null && index < xalign.length) {
      var label = this.find_label (child);

      if (label != null) {
        label.set_hexpand (true);
        label.set_xalign (xalign[index]);
        label.set_margin_start (lead[index]);
        label.set_margin_end (trail[index]);
      }

      child = child.get_next_sibling ();
      index++;
    }
  }

  /**
   * The first Gtk.Label at or below a widget, or null if there is none.
   *
   * @param  Gtk.Widget widget
   * @return Gtk.Label?
   */
  private Gtk.Label? find_label (Gtk.Widget widget) {
    if (widget is Gtk.Label) {
      return (Gtk.Label) widget;
    }

    var child = widget.get_first_child ();

    while (child != null) {
      var found = this.find_label (child);

      if (found != null) {
        return found;
      }

      child = child.get_next_sibling ();
    }

    return null;
  }

  /**
   * Store what became of an image and refresh its row.
   *
   * This is called from the optimizer worker threads, so the actual model
   * update is deferred to the main loop where GTK is safe to touch.
   *
   * @param  string path
   * @param  Status status
   * @param  int size
   * @param  string? reason  what the optimizer ran into, when it knows
   * @return void
   */
  public void update_result (string path, Status status, int size, string? reason = null) {
    // Owned copies, the closure outlives this call.
    string image_path = path;
    string? image_reason = reason;

    Idle.add (() => {
      this.apply_result (image_path, status, size, image_reason);

      return Source.REMOVE;
    });
  }

  /**
   * Apply a result to the row belonging to a path and add it to the totals.
   * Runs on the main loop.
   *
   * @param  string path
   * @param  Status status
   * @param  int size
   * @param  string? reason
   * @return void
   */
  private void apply_result (string path, Status status, int size, string? reason) {
    for (uint i = 0; i < this.listmodel.get_n_items (); i++) {
      var row = (ImageRow) this.listmodel.get_item (i);

      if (row.image.path != path) {
        continue;
      }

      var image = row.image;
      var outcome = status;

      // The optimizers report what their tool did, but only here is the original
      // size known, so this is where "smaller" is decided. Anything that did not
      // actually shrink is not counted as a saving, or the total would grow on a
      // file that stayed the same.
      if (outcome == Status.OPTIMIZED && (size <= 0 || size >= image.size)) {
        outcome = Status.ALREADY_OPTIMAL;
      }

      image.new_size = (outcome == Status.OPTIMIZED) ? size : image.size;

      // A GLib.ListStore has no "this item changed" signal. Splicing the same
      // object back in is not enough either: the column view sees an identical
      // item and skips rebinding it. Hand it a fresh row so it rebinds.
      var updated = new ImageRow (image);
      updated.apply_status (outcome, reason);

      this.listmodel.splice (i, 1, {updated});

      this.finished_files++;

      switch (outcome) {
        case Status.OPTIMIZED:
          this.optimized_files++;
          this.total_before += image.size;
          this.total_after += image.new_size;
          break;

        case Status.FAILED:
          this.failed_files++;
          break;

        default:
          break;
      }

      this.refresh_summary ();

      return;
    }
  }

  public void update_tree_view (Image[] images) {
    Image[] fresh = {};

    foreach (var image in images) {
      var duplicate = false;
      for (int i = 0; i < this.images.length; i++) {
        if (this.images[i].path == image.path) {
          duplicate = true;
        }
      }

      if (duplicate) {
        continue;
      }

      this.listmodel.append (new ImageRow (image));
      this.images += image;
      fresh += image;
    }

    // Only the images that were actually added. Handing over the whole batch
    // sent duplicates through the optimizers a second time, and an all
    // duplicate drop started workers with nothing to do.
    if (fresh.length == 0) {
      return;
    }

    // The totals are not reset here. Dropping more files halfway through is
    // still the same session, so the bar keeps counting rather than starting
    // over on what is already on screen.
    this.start (fresh);
  }
}
