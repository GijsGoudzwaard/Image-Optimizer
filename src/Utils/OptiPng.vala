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
   * Index of the next image to pick up. Workers bump it atomically, which is
   * all the coordination they need.
   *
   * @var int
   */
  private int next_image = 0;

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
  public void compress (int max_workers) throws Error {
    var workers = int.min (max_workers, this.images.length);

    for (var i = 0; i < workers; i++) {
      ThreadFunc<void*> run = () => {
        while (true) {
          var index = AtomicInt.add (ref this.next_image, 1);

          if (index >= this.images.length) {
            break;
          }

          this.compress_one (this.images[index]);
        }

        return null;
      };

      new Thread<void*>.try ("optipng", (owned) run);
    }
  }

  /**
   * Compress a single image and hand its new size to the list.
   *
   * @param  string image
   * @return void
   */
  private void compress_one (string image) {
    // The optimizer runs on a copy inside the sandbox, never on the file the
    // user picked. See Rewrite for why.
    var rewrite = new Rewrite (image);

    if (rewrite.working_path == null) {
      this.list.update_size (image, 0);

      return;
    }

    string[] argv = { "optipng" };

    foreach (var arg in this.args) {
      argv += arg;
    }

    argv += rewrite.working_path;

    var new_size = 0;

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

      // Same reasoning as in JpegOptim: only the exit status says whether the
      // result reached the disk. optipng fails with "Can't back up the input
      // file" when it cannot write next to the original, and without this check
      // that turned into a reported saving on an untouched file.
      if (status != 0) {
        warning (
          "optipng exited with status %d for \"%s\": %s",
          status,
          image,
          standard_error
        );
      } else if (! standard_error.contains ("is already optimized")) {
        // optipng reports on stderr, stdout stays empty. Its number describes
        // the copy, so it only decides whether there is anything to write back;
        // the size handed to the list is what was actually written.
        if (this.get_new_size (standard_error) > 0) {
          new_size = rewrite.commit ();
        }
      }
    } catch (Error e) {
      warning ("Failed to run optipng on \"%s\": %s", image, e.message);
    }

    // Always, so a failure or a quit halfway through does not leave the copy
    // behind.
    rewrite.cleanup ();

    // A zero means "nothing was written", which the list turns back into the
    // original size, so the row reports no saving instead of a made up one.
    this.list.update_size (image, new_size);
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
