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
   * Hand the batch to the optimizer and start it.
   *
   * There used to be a queue per format here, because there was a tool per
   * format. One tool does both now, so there is one queue, and every file in it
   * goes through the same code whatever it is. Only supported files ever arrive:
   * List.start keeps the rest out and gives them a row saying why.
   *
   * @return void
   */
  public void optimize (List list) {
    var ect = new Ect (list);

    foreach (var image in this.images) {
      ect.add_image (image.path);
    }

    // One worker per core, and one file per worker. There is no arithmetic to do
    // here beyond that: the optimizer stays single threaded unless it is asked
    // otherwise, which it is not, so the number of workers is the number of
    // files being worked on at once.
    try {
      ect.compress ((int) get_num_processors ());
    } catch (Error e) {
      warning ("Failed to compress: %s", e.message);
    }
  }
}
