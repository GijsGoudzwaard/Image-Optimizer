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

    var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);

    this.spinner = new Gtk.Spinner ();
    this.spinner.set_valign (Gtk.Align.CENTER);
    this.spinner.start ();

    // These two names were picked by rendering them, not by reading a list.
    // process-completed-symbolic reads better but is elementary only, and
    // emblem-ok-symbolic exists in Adwaita yet still painted the missing icon
    // placeholder on Ubuntu, where the emblems directory does not resolve even
    // though IconTheme.has_icon claims it does. object-select and dialog-warning
    // both come out of actions and status, which do resolve everywhere the app
    // ships: elementary's theme on Flathub and Adwaita on the GNOME runtime the
    // snap builds against.
    this.icon = new Gtk.Image.from_icon_name ("object-select-symbolic");
    this.icon.set_valign (Gtk.Align.CENTER);
    this.icon.set_visible (false);

    var text = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
    text.set_hexpand (true);
    text.set_halign (Gtk.Align.START);
    text.set_valign (Gtk.Align.CENTER);

    this.headline = new Gtk.Label (null);
    this.headline.set_xalign (0);
    this.headline.add_css_class ("headline");

    this.sub = new Gtk.Label (null);
    this.sub.set_xalign (0);
    this.sub.add_css_class ("sub");

    text.append (this.headline);
    text.append (this.sub);

    var numbers = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
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

    row.append (this.spinner);
    row.append (this.icon);
    row.append (text);
    row.append (numbers);

    this.progress = new Gtk.ProgressBar ();
    this.progress.add_css_class ("summary_progress");
    this.progress.set_margin_top (10);

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

    this.done (optimized, skipped, failed, unsupported, before, after, saved);
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
    uint optimized,
    uint skipped,
    uint failed,
    uint unsupported,
    int64 before,
    int64 after,
    int64 saved
  ) {
    this.spinner.stop ();
    this.spinner.set_visible (false);

    // A warning icon whenever something did not go the way it was meant to, so
    // the bar never claims a clean run over files it could not handle.
    this.icon.set_from_icon_name (
      (failed > 0 || unsupported > 0) ? "dialog-warning-symbolic" : "object-select-symbolic"
    );
    this.icon.set_visible (true);

    this.sub.set_label (this.counts (optimized, skipped, failed, unsupported));

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
   * @param  uint optimized
   * @param  uint skipped
   * @param  uint failed
   * @param  uint unsupported
   * @return string
   */
  private string counts (uint optimized, uint skipped, uint failed, uint unsupported) {
    string[] parts = {};

    // "0 files optimized" only earns its place when there is nothing else to
    // report. Next to "3 already optimal" it is noise.
    if (optimized > 0 || (skipped == 0 && failed == 0 && unsupported == 0)) {
      parts += ngettext ("%u file optimized", "%u files optimized", optimized).printf (optimized);
    }

    if (skipped > 0) {
      parts += _("%u already optimal").printf (skipped);
    }

    if (failed > 0) {
      parts += _("%u failed").printf (failed);
    }

    if (unsupported > 0) {
      parts += _("%u not supported").printf (unsupported);
    }

    // Not translatable on purpose: a bare ", " gives a translator nothing to go
    // on, and every language this app ships in separates a short list this way.
    return string.joinv (", ", parts);
  }
}
