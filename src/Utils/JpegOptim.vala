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
    // Not --strip-all: that takes the ICC colour profile with it, which makes a
    // wide gamut image render as sRGB afterwards. These four drop the metadata
    // that costs bytes and leave the profile alone.
    "--strip-com",
    "--strip-exif",
    "--strip-iptc",
    "--strip-xmp",
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
    string[] argv = { "jpegoptim" };

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

      // jpegoptim reports on stdout.
      this.list.update_size (image, this.get_new_size (standard_output));
    } catch (Error e) {
      warning ("Failed to run jpegoptim on \"%s\": %s", image, e.message);
    }
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
