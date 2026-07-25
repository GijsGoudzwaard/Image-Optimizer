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

  public Gtk.Button upload_button;

  /**
   * Returns the text a column should show for a given row.
   */
  private delegate string CellText (ImageRow row);

  public List (Image[] images) {
    this.images = images;
  }

  public Gtk.ScrolledWindow window () {
    var main = new Gtk.ScrolledWindow ();
    main.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);

    this.listmodel = new GLib.ListStore (typeof (ImageRow));

    this.upload_button = new Gtk.Button.with_label ("+");
    this.upload_button.add_css_class ("upload_button");
    this.upload_button.add_css_class ("add");
    this.upload_button.set_valign (Gtk.Align.START);
    this.upload_button.set_halign (Gtk.Align.END);
    ((Gtk.Widget) this.upload_button).set_focus_on_click (false);

    foreach (var image in this.images) {
      this.listmodel.append (new ImageRow (image));
    }

    // NoSelection: the list is a progress report, there is nothing to select.
    var view = new Gtk.ColumnView (new Gtk.NoSelection (this.listmodel));
    view.add_css_class ("tree_view");
    main.set_child (view);

    view.append_column (this.spinner_column ());
    view.append_column (this.text_column (_("File"), (row) => row.image.name));
    view.append_column (this.text_column (_("Size"), (row) => row.size_text));
    view.append_column (this.text_column (_("New size"), (row) => row.new_size_text));
    view.append_column (this.text_column (_("Savings"), (row) => row.savings_text));

    var optimizer = new Optimizer (this.images);
    optimizer.optimize (this);

    return main;
  }

  /**
   * Build the column holding the spinner that runs while an image is being
   * optimized. Gtk.Spinner animates itself, so unlike Gtk.CellRendererSpinner
   * it does not need to be pulsed from a timeout.
   *
   * @return Gtk.ColumnViewColumn
   */
  private Gtk.ColumnViewColumn spinner_column () {
    var factory = new Gtk.SignalListItemFactory ();

    factory.setup.connect ((object) => {
      var item = (Gtk.ListItem) object;

      var spinner = new Gtk.Spinner ();
      spinner.set_valign (Gtk.Align.CENTER);
      spinner.set_margin_start (6);
      spinner.set_margin_end (6);

      item.set_child (spinner);
    });

    factory.bind.connect ((object) => {
      var item = (Gtk.ListItem) object;
      var row = (ImageRow) item.get_item ();
      var spinner = (Gtk.Spinner) item.get_child ();

      spinner.set_visible (row.optimizing);

      if (row.optimizing) {
        spinner.start ();
      } else {
        spinner.stop ();
      }
    });

    return new Gtk.ColumnViewColumn ("", factory);
  }

  /**
   * Build a column that shows a piece of text per row.
   *
   * @param  string title
   * @param  CellText get_text
   * @return Gtk.ColumnViewColumn
   */
  private Gtk.ColumnViewColumn text_column (string title, owned CellText get_text) {
    var factory = new Gtk.SignalListItemFactory ();

    factory.setup.connect ((object) => {
      var item = (Gtk.ListItem) object;

      var label = new Gtk.Label (null);
      label.set_xalign (0);
      label.set_margin_top (14);
      label.set_margin_bottom (14);
      label.set_margin_start (6);
      label.set_margin_end (6);

      item.set_child (label);
    });

    factory.bind.connect ((object) => {
      var item = (Gtk.ListItem) object;
      var row = (ImageRow) item.get_item ();

      ((Gtk.Label) item.get_child ()).set_label (get_text (row));
    });

    var column = new Gtk.ColumnViewColumn (title, factory);
    column.set_expand (true);

    return column;
  }

  /**
   * Store the optimized size for an image and refresh its row.
   *
   * This is called from the optimizer worker threads, so the actual model
   * update is deferred to the main loop where GTK is safe to touch.
   *
   * @param  string path
   * @param  int size
   * @return void
   */
  public void update_size (string path, int size) {
    // Owned copy, the closure outlives this call.
    string image_path = path;

    Idle.add (() => {
      this.apply_size (image_path, size);

      return Source.REMOVE;
    });
  }

  /**
   * Apply a new size to the row belonging to a path. Runs on the main loop.
   *
   * @param  string path
   * @param  int size
   * @return void
   */
  private void apply_size (string path, int size) {
    for (uint i = 0; i < this.listmodel.get_n_items (); i++) {
      var row = (ImageRow) this.listmodel.get_item (i);

      if (row.image.path != path) {
        continue;
      }

      var image = row.image;
      image.new_size = (size == 0 || image.size < size) ? image.size : size;

      // A GLib.ListStore has no "this item changed" signal. Splicing the same
      // object back in is not enough either: the column view sees an identical
      // item and skips rebinding it. Hand it a fresh row so it rebinds.
      var updated = new ImageRow (image);
      updated.optimizing = false;
      updated.new_size_text = GLib.format_size (image.new_size);
      updated.savings_text = Image.calc_savings ((float) image.size, (float) image.new_size);

      this.listmodel.splice (i, 1, {updated});

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

    var optimizer = new Optimizer (fresh);
    optimizer.optimize (this);
  }
}
