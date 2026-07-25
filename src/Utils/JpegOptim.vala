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
    "--all-progressive"
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
  public void compress () throws Error {
    var command = "jpegoptim " + Utils.join (" ", this.args);

    ThreadFunc<void*> run = () => {
      foreach (var image in this.images) {
        string stdout;
        string stderr;
        int status;

        try {
          Process.spawn_command_line_sync (
            command + " " + image.replace (" ", "\\ "),
            out stdout,
            out stderr,
            out status
          );

          var new_size = this.get_new_size (stdout);
          this.list.update_size (image, new_size);

        } catch (SpawnError e) {
          warning ("Failed to spawn jpegoptim: %s", e.message);
        }
      }

      return null;
    };

    new Thread<void*>.try ("thread", (owned) run);
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
