public class Optimizer {

  /**
   * Contains the images that have yet to be optimized.
   *
   * @var Image[]
   */
  private Image[] images;

  /**
   * Add the images to this instance that have yet to be optimized.
   *
   * @param Image[] images
   */
  public Optimizer (Image[] images) {
    this.images = images;
  }

  /**
   * Add the images to their respective optimizer and start optimizing.
   *
   * @return void
   */
  public void optimize (List list) {
    var jpegoptim = new JpegOptim (list);
    var optipng = new OptiPng (list);

    foreach (var image in this.images) {
      if (Utils.inArray ({"jpg", "jpeg"}, image.type)) {
        jpegoptim.addImage (image.path);
      } else if (Utils.inArray ({"png", "bmp", "gif", "pnm", "tiff"}, image.type)) {
        optipng.addImage (image.path);
      }
    }

    try {
      jpegoptim.compress ();
      optipng.compress ();
    } catch (Error e) {
      stdout.printf ("Error: %s\n", e.message);
    }
  }
}
