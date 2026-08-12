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
   * Set the status and the display strings that follow from it. Keeping the two
   * together is what stops a row from showing a size the app never wrote.
   *
   * @param  Status status
   * @return void
   */
  public void apply_status (Status status) {
    this.status = status;

    switch (status) {
      case Status.OPTIMIZED:
        this.new_size_text = GLib.format_size (this.image.new_size);
        this.savings_text = Image.calc_savings ((float) this.image.size, (float) this.image.new_size);
        break;

      case Status.ALREADY_OPTIMAL:
        this.new_size_text = GLib.format_size (this.image.new_size);
        this.savings_text = _("Already optimal");
        break;

      case Status.FAILED:
        // No size, because nothing was written. A "0.00%" here reads as a
        // successful run that happened to gain nothing, which is the confusion
        // this whole status exists to end.
        this.new_size_text = "";
        this.savings_text = _("Failed");
        break;

      case Status.UNSUPPORTED:
        // Not even a size: the app is not going to touch this file, so showing
        // how big it is only suggests it is waiting its turn.
        this.size_text = "";
        this.new_size_text = "";
        this.savings_text = _("Not supported");
        break;

      default:
        this.new_size_text = "";
        this.savings_text = "";
        break;
    }
  }
}
