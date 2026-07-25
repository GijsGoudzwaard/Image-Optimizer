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
   * Whether the optimizer is still working on this image.
   *
   * @var bool
   */
  public bool optimizing = true;

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
   * The savings percentage, formatted for display. Empty while still
   * optimizing.
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
  }
}
