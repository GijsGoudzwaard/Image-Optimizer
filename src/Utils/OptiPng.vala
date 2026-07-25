public class OptiPng {

  /**
   * Images in queue for optimizing.
   *
   * @var string[]
   */
  private string[] images;

  /**
   * Optipng arguments.
   *
   * @var string[]
   */
  private string[] args = {
    // -o3 stays. Measured on a mixed set, -o4 and -o5 gain nothing over it and
    // -o6 only pays off on smooth gradients while costing four to ten times the
    // time: 104 seconds for a single 3000x2000 image against 15 for -o3.
    "-o3",
    // Free, and it brings PNG in line with what the app already does to JPEG
    // metadata. The gain is exactly the size of the metadata carried.
    "-strip", "all",
    "-preserve"
  };

  /**
   * Used to update the treeview when done compressing.
   *
   * @var List
   */
  private List list;

  /**
   * Create a new instance.
   *
   * @param List list
   */
  public OptiPng (List list) {
    this.list = list;
  }

  /**
   * Add images to the current object.
   *
   * @return void
   */
  public void add_image (string image) {
    this.images += image;
  }

  /**
   * Compress the images using optipng.
   *
   * @return void
   */
  public void compress () throws Error {
    ThreadFunc<void*> run = () => {
      foreach (var image in this.images) {
        this.compress_one (image);
      }

      return null;
    };

    new Thread<void*>.try ("optipng", (owned) run);
  }

  /**
   * Compress a single image and hand its new size to the list.
   *
   * @param  string image
   * @return void
   */
  private void compress_one (string image) {
    string[] argv = { "optipng" };

    foreach (var arg in this.args) {
      argv += arg;
    }

    argv += image;

    try {
      string standard_output;
      string standard_error;
      int status;

      Process.spawn_sync (
        null,
        argv,
        null,
        SpawnFlags.SEARCH_PATH,
        null,
        out standard_output,
        out standard_error,
        out status
      );

      var new_size = 0;

      // optipng reports on stderr, stdout stays empty.
      if (! standard_error.contains ("is already optimized")) {
        new_size = this.get_new_size (standard_error);
      }

      this.list.update_size (image, new_size);
    } catch (Error e) {
      warning ("Failed to run optipng on \"%s\": %s", image, e.message);
    }
  }

  /**
   * Get the optimized image size from the optipng output.
   *
   * optipng prints "Output file size = 19906 bytes" on stderr. A file it cannot
   * read gets "Error: Unrecognized image file format" and no size at all, which
   * yields 0 here. The already optimized case never reaches this method, the
   * caller checks for it first, so a 0 really is a failure worth reporting.
   *
   * @param  string output
   * @return int
   */
  public int get_new_size (string output) {
    var size = Utils.size_after (output, "Output file size = ");

    if (size == 0) {
      warning ("Could not read a size from the optipng output: %s", output);
    }

    return size;
  }
}
