/**
 * The bar under the list. It shows progress while the optimizers are running
 * and the result of the batch once they are done.
 *
 * It calculates nothing about the batch itself. Every number comes from List,
 * which is the only place that knows what happened to each file, and this class
 * only decides how to word and format it.
 */
public class SummaryBar : Gtk.Box {

  /**
   * Shown when every file was dealt with without trouble.
   */
  private const string ICON_OK = "/com/github/gijsgoudzwaard/image-optimizer/icons/check-circle.svg";

  /**
   * Shown when the batch held something the app could not handle.
   */
  private const string ICON_PROBLEM = "/com/github/gijsgoudzwaard/image-optimizer/icons/error.svg";

  /**
   * Runs while there is still work, hidden afterwards.
   *
   * @var Gtk.Spinner
   */
  private Gtk.Spinner spinner;

  /**
   * Takes the spinner's place when the batch is done.
   *
   * @var Gtk.Image
   */
  private Gtk.Image icon;

  /**
   * The one line to read if you read nothing else.
   *
   * @var Gtk.Label
   */
  private Gtk.Label headline;

  /**
   * The file counts under the headline.
   *
   * @var Gtk.Label
   */
  private Gtk.Label sub;

  /**
   * The large number on the right.
   *
   * @var Gtk.Label
   */
  private Gtk.Label figure;

  /**
   * The small line under the figure.
   *
   * @var Gtk.Label
   */
  private Gtk.Label caption;

  /**
   * Progress over the whole batch, hidden once it is finished.
   *
   * @var Gtk.ProgressBar
   */
  private Gtk.ProgressBar progress;

  construct {
    this.set_orientation (Gtk.Orientation.VERTICAL);
    this.set_spacing (0);
    this.add_css_class ("summary_bar");

    // The text sits in its own padded box so the progress bar underneath can run
    // the full width of the window instead of stopping at the padding.
    // 16 between the two groups, 9 between the icon and the text it belongs to.
    var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
    row.add_css_class ("summary_content");

    this.spinner = new Gtk.Spinner ();
    this.spinner.set_size_request (17, 17);
    this.spinner.set_valign (Gtk.Align.CENTER);
    this.spinner.start ();

    // Bundled with the app rather than looked up in the icon theme. The two
    // themes it ships against do not agree on which of the obvious names exist,
    // and emblem-ok-symbolic painted a missing icon placeholder on Ubuntu even
    // though IconTheme.has_icon said it was there. These also carry their own
    // colour, which a symbolic icon from the theme would not.
    this.icon = new Gtk.Image.from_resource (SummaryBar.ICON_OK);
    this.icon.set_pixel_size (17);
    this.icon.set_valign (Gtk.Align.CENTER);
    this.icon.set_visible (false);

    // The icon and the two lines belong together, so they sit in one box with
    // the tighter gap and that box is what the wider gap separates.
    var left = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 9);
    left.set_hexpand (true);
    left.set_halign (Gtk.Align.START);
    left.set_valign (Gtk.Align.CENTER);

    var text = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
    text.set_valign (Gtk.Align.CENTER);

    this.headline = new Gtk.Label (null);
    this.headline.set_xalign (0);
    this.headline.add_css_class ("headline");

    this.sub = new Gtk.Label (null);
    this.sub.set_xalign (0);
    this.sub.add_css_class ("sub");

    text.append (this.headline);
    text.append (this.sub);

    var numbers = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
    numbers.set_halign (Gtk.Align.END);
    numbers.set_valign (Gtk.Align.CENTER);

    this.figure = new Gtk.Label (null);
    this.figure.set_xalign (1);
    this.figure.add_css_class ("figure");

    this.caption = new Gtk.Label (null);
    this.caption.set_xalign (1);
    this.caption.add_css_class ("caption");

    numbers.append (this.figure);
    numbers.append (this.caption);

    left.append (this.spinner);
    left.append (this.icon);
    left.append (text);

    row.append (left);
    row.append (numbers);

    this.progress = new Gtk.ProgressBar ();
    this.progress.add_css_class ("summary_progress");

    this.append (row);
    this.append (this.progress);
  }

  /**
   * Show where the batch stands.
   *
   * The counts are passed in rather than derived here, so there is one place
   * that decides what counts as optimized. Already optimal files are the ones
   * that are finished and did not end up in any of the other buckets, which is
   * why they are not a parameter of their own.
   *
   * @param  uint finished
   * @param  uint total
   * @param  uint optimized
   * @param  uint failed
   * @param  uint unsupported
   * @param  int64 before
   * @param  int64 after
   * @return void
   */
  public void update (
    uint finished,
    uint total,
    uint optimized,
    uint failed,
    uint unsupported,
    int64 before,
    int64 after
  ) {
    if (total == 0) {
      return;
    }

    var accounted = optimized + failed + unsupported;
    uint skipped = finished > accounted ? finished - accounted : 0;
    var saved = before - after;

    if (finished < total) {
      this.working (finished, total, saved);

      return;
    }

    this.done (total, optimized, skipped, failed, unsupported, before, after, saved);
  }

  /**
   * The state while the optimizers are still going.
   *
   * @param  uint finished
   * @param  uint total
   * @param  int64 saved
   * @return void
   */
  private void working (uint finished, uint total, int64 saved) {
    // The figure is the app's own colour while it is working and green once it
    // has something to show, so the state is readable without reading a word.
    this.remove_css_class ("done");

    this.spinner.set_visible (true);
    this.spinner.start ();
    this.icon.set_visible (false);

    this.headline.set_label (_("Optimizing…"));
    this.sub.set_label (
      ngettext ("%u of %u file done", "%u of %u files done", total).printf (finished, total)
    );

    this.figure.set_visible (true);
    this.figure.set_label (GLib.format_size (saved));
    this.caption.set_visible (true);
    this.caption.set_label (_("saved so far"));

    this.progress.set_visible (true);
    this.progress.set_fraction ((double) finished / (double) total);
  }

  /**
   * The state once every file has been dealt with.
   *
   * @param  uint total
   * @param  uint optimized
   * @param  uint skipped
   * @param  uint failed
   * @param  uint unsupported
   * @param  int64 before
   * @param  int64 after
   * @param  int64 saved
   * @return void
   */
  private void done (
    uint total,
    uint optimized,
    uint skipped,
    uint failed,
    uint unsupported,
    int64 before,
    int64 after,
    int64 saved
  ) {
    this.add_css_class ("done");

    this.spinner.stop ();
    this.spinner.set_visible (false);

    // The red icon whenever something did not go the way it was meant to, so the
    // bar never claims a clean run over files it could not handle.
    this.icon.set_from_resource (
      (failed > 0 || unsupported > 0) ? SummaryBar.ICON_PROBLEM : SummaryBar.ICON_OK
    );
    this.icon.set_visible (true);

    this.sub.set_label (this.counts (total, optimized, skipped, failed, unsupported));

    this.progress.set_visible (false);

    if (saved <= 0) {
      // "0%" next to a run that did everything it could reads as a failure, so
      // there is no figure at all in this case.
      this.headline.set_label (_("Nothing left to save"));
      this.figure.set_visible (false);
      this.caption.set_visible (false);

      return;
    }

    this.headline.set_label (_("%s saved").printf (GLib.format_size (saved)));

    this.figure.set_visible (true);
    this.figure.set_label (this.percentage (before, after));
    this.caption.set_visible (true);
    this.caption.set_label (
      _("%s to %s").printf (GLib.format_size (before), GLib.format_size (after))
    );
  }

  /**
   * The savings as a percentage of the whole batch.
   *
   * Whole numbers, except when the batch rounds down to nothing. One large file
   * that barely moved is enough for that, and a big "0%" beside a headline that
   * says kilobytes were saved reads as a broken app rather than a modest result.
   *
   * @param  int64 before
   * @param  int64 after
   * @return string
   */
  private string percentage (int64 before, int64 after) {
    var whole = Image.calc_savings_rounded (before, after);

    if (whole == 0 && before > 0) {
      return "%.1f%%".printf (100.0 - ((double) after / (double) before * 100.0));
    }

    return "%d%%".printf (whole);
  }

  /**
   * The file counts as one sentence, leaving out whatever did not happen.
   *
   * @param  uint total
   * @param  uint optimized
   * @param  uint skipped
   * @param  uint failed
   * @param  uint unsupported
   * @return string
   */
  private string counts (uint total, uint optimized, uint skipped, uint failed, uint unsupported) {
    string[] parts = {};

    // "0 of 3 files optimized" only earns its place when there is nothing else
    // to report. Next to "3 already optimal" it is noise.
    if (optimized > 0 || (skipped == 0 && failed == 0 && unsupported == 0)) {
      parts += ngettext (
        "%u of %u file optimized",
        "%u of %u files optimized",
        total
      ).printf (optimized, total);
    }

    if (skipped > 0) {
      parts += _("%u already optimal").printf (skipped);
    }

    if (failed > 0) {
      parts += _("%u failed").printf (failed);
    }

    if (unsupported > 0) {
      parts += _("%u skipped").printf (unsupported);
    }

    // Not translatable on purpose: a bare ", " gives a translator nothing to go
    // on, and every language this app ships in separates a short list this way.
    return string.joinv (", ", parts);
  }
}
