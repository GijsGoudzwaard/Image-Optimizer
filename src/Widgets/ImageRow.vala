/**
 * A single row in the image list.
 *
 * Derives from GLib.Object because a GLib.ListStore can only hold GObjects.
 * The formatted display strings are kept here so the column factories only
 * have to read them instead of formatting on every bind.
 */
public class ImageRow : GLib.Object {

  /**
   * The image this row represents.
   *
   * @var Image
   */
  public Image image;

  /**
   * What happened to this image so far. Replaces the plain "optimizing" flag
   * this class used to carry, which could not tell a failure from a file that
   * had nothing left to give.
   *
   * @var Status
   */
  public Status status = Status.PENDING;

  /**
   * The original size, formatted for display.
   *
   * @var string
   */
  public string size_text;

  /**
   * The optimized size, formatted for display. Empty while still optimizing.
   *
   * @var string
   */
  public string new_size_text = "";

  /**
   * What became of the image, either a savings percentage or the reason there
   * is none. Empty while still optimizing.
   *
   * @var string
   */
  public string savings_text = "";

  /**
   * The icon in front of the row, or null while there is still a spinner there.
   *
   * @var string?
   */
  public string? icon_resource = null;

  /**
   * The line under the file name saying why nothing happened to it, or null for a
   * row that needs no explaining.
   *
   * @var string?
   */
  public string? note = null;

  /**
   * Create a row for an image.
   *
   * @param Image image
   */
  public ImageRow (Image image) {
    this.image = image;
    this.size_text = GLib.format_size (image.size);

    if (! image.supported) {
      this.apply_status (Status.UNSUPPORTED);
    }
  }

  /**
   * Set the status, the icon and the display strings that follow from it.
   * Keeping them together is what stops a row from showing a size the app never
   * wrote.
   *
   * The icon carries the outcome, so the columns only hold numbers wherever
   * there is a number to hold. A word appears in them exactly when there is no
   * figure to put there instead.
   *
   * @param  Status status
   * @param  string? reason  what the optimizer ran into, when it knows
   * @return void
   */
  public void apply_status (Status status, string? reason = null) {
    this.status = status;

    switch (status) {
      case Status.OPTIMIZED:
        this.icon_resource = "/com/github/gijsgoudzwaard/image-optimizer/icons/check.svg";
        this.new_size_text = GLib.format_size (this.image.new_size);
        this.savings_text = Image.calc_savings ((float) this.image.size, (float) this.image.new_size);
        // Nothing to explain: the three numbers on the row say it all.
        this.note = null;
        break;

      case Status.ALREADY_OPTIMAL:
        // The dash says nothing went wrong, so the row can keep its numbers and
        // report the 0.00% it honestly gained.
        this.icon_resource = "/com/github/gijsgoudzwaard/image-optimizer/icons/dash.svg";
        this.new_size_text = GLib.format_size (this.image.new_size);
        this.savings_text = Image.calc_savings ((float) this.image.size, (float) this.image.new_size);
        this.note = _("Already as small as it gets");
        break;

      case Status.FAILED:
        // No new size, because nothing was written. A "0.00%" here reads as a
        // successful run that happened to gain nothing, which is the confusion
        // this whole status exists to end.
        this.icon_resource = "/com/github/gijsgoudzwaard/image-optimizer/icons/error.svg";
        this.new_size_text = _("Failed");
        this.savings_text = "";
        // The optimizer usually knows exactly what it ran into. The generic line
        // is only for the cases where it does not.
        this.note = reason ?? _("This file could not be optimized");
        break;

      case Status.UNSUPPORTED:
        // Not even a size: the app is not going to touch this file, so showing
        // how big it is only suggests it is waiting its turn.
        this.icon_resource = "/com/github/gijsgoudzwaard/image-optimizer/icons/error.svg";
        this.size_text = _("Skipped");
        this.new_size_text = "";
        this.savings_text = "";
        this.note = _("Only PNG and JPEG are supported");
        break;

      default:
        this.icon_resource = null;
        this.new_size_text = "";
        this.savings_text = "";
        this.note = null;
        break;
    }
  }
}
