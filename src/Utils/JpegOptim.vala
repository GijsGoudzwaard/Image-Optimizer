public class JpegOptim {

  /**
   * Images in queue for optimizing.
   *
   * @var string[]
   */
  private string[] images;

  /**
   * Jpegoptim arguments.
   *
   * @var string[]
   */
  private string[] args = {
    // Strip everything, then put back the one marker that is not just weight:
    // without the ICC profile a wide gamut image renders as sRGB afterwards.
    // Naming what to keep beats naming what to drop, because jpegoptim also
    // knows Adobe APP14 and JFXX markers that a list of individual --strip-*
    // flags would silently leave behind.
    "--strip-all",
    "--keep-icc",
    // Reorders the scans without touching a single coefficient. Lossless, free,
    // and by far the largest win available here.
    "--all-progressive",
    // Keeps the modification time, which optipng was already doing through its
    // own -preserve. Without it a JPEG comes back stamped with the time it was
    // optimized, which reorders any photo library sorted by date.
    // --preserve-perms is deliberately not here: the mode survives without it,
    // and it would switch jpegoptim to overwriting the file in place.
    "--preserve"
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
  public JpegOptim (List list) {
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
   * Compress the images using jpegoptim.
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

      new Thread<void*>.try ("jpegoptim", (owned) run);
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
      this.list.update_result (image, Status.FAILED, 0);

      return;
    }

    string[] argv = { "jpegoptim" };

    foreach (var arg in this.args) {
      argv += arg;
    }

    argv += rewrite.working_path;

    var new_size = 0;
    var status_result = Status.FAILED;

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

      // jpegoptim prints its " --> " line before it tries to put the result in
      // place, so that line is not proof that anything was written. A directory
      // it cannot create its temporary file in gets the optimistic line on
      // stdout and exit code 3, and parsing the line anyway made the list report
      // a saving on a file that was never touched. The status is the only honest
      // signal, so read it.
      if (status == 0) {
        // jpegoptim reports on stdout and ends its line with ", skipped." when
        // its own result was not smaller than what it was given. Committing then
        // would write bytes identical to the original back over the original,
        // which is work and risk for nothing.
        if (", skipped" in standard_output) {
          status_result = Status.ALREADY_OPTIMAL;
        } else if (this.get_new_size (standard_output) > 0) {
          // The size jpegoptim prints describes the copy, so it only tells "it
          // did something" from "it could not"; the size that reaches the list
          // is the number of bytes actually written.
          new_size = rewrite.commit ();
          status_result = (new_size > 0) ? Status.OPTIMIZED : Status.FAILED;
        }
      } else {
        warning (
          "jpegoptim exited with status %d for \"%s\": %s",
          status,
          image,
          standard_error
        );
      }
    } catch (Error e) {
      warning ("Failed to run jpegoptim on \"%s\": %s", image, e.message);
    }

    // Always, so a failure or a quit halfway through does not leave the copy
    // behind.
    rewrite.cleanup ();

    // The status is what the row and the summary bar go by. A size only means
    // anything alongside OPTIMIZED, and the list checks that it really is
    // smaller before it counts as a saving.
    this.list.update_result (image, status_result, new_size);
  }

  /**
   * Get the optimized image size from the jpegoptim output.
   *
   * jpegoptim prints "41777 --> 33746 bytes" on stdout, so the size sits right
   * after the arrow. A file it cannot read gets "[ERROR]" and no arrow at all,
   * which yields 0 here.
   *
   * @param  string output
   * @return int
   */
  public int get_new_size (string output) {
    var size = Utils.size_after (output, " --> ");

    if (size == 0) {
      warning ("Could not read a size from the jpegoptim output: %s", output);
    }

    return size;
  }
}
