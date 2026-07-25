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
    var jpegs = 0;
    var pngs = 0;

    foreach (var image in this.images) {
      if (Utils.in_array ({"jpg", "jpeg"}, image.type)) {
        jpegoptim.add_image (image.path);
        jpegs++;
      } else if (Utils.in_array ({"png", "bmp"}, image.type)) {
        optipng.add_image (image.path);
        pngs++;
      }
    }

    // Both tools are single threaded per file, so the way to use the machine is
    // to run several files at once. One worker per core, split between the two
    // tools when both have work, so together they never start more processes
    // than there are cores. A single core machine gets one worker per tool,
    // which is what the app did before this.
    var cores = (int) get_num_processors ();
    var workers = (jpegs > 0 && pngs > 0) ? int.max (1, cores / 2) : cores;

    try {
      if (jpegs > 0) {
        jpegoptim.compress (workers);
      }

      if (pngs > 0) {
        optipng.compress (workers);
      }
    } catch (Error e) {
      warning ("Failed to compress: %s", e.message);
    }
  }
}
