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
  private string[] args = {"-o3", "-preserve"};

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
  public void addImage (string image) {
    this.images += image;
  }

  /**
   * Compress the images using optipng.
   *
   * @return void
   */
  public void compress () throws Error {
    var command = "optipng " + Utils.join(" ", this.args);

    ThreadFunc<void*> run = () => {
      foreach (var image in this.images) {
        string stdout;
        string stderr;
        int status;

        try {
          Process.spawn_command_line_sync (
            command + " " + image.replace(" ", "\\ "),
            out stderr,
            out stdout,
            out status
          );

          var new_size = 0;

          if (! stdout.contains ("is already optimized")) {
            new_size = this.getNewSize(stdout);
          }

          this.list.updateSize(image, new_size);
        } catch (SpawnError e) {
          stdout.printf ("Error: %s\n", e.message);
        }
      }

      return null;
    };

    new Thread<void*>.try("thread", run);
  }

  /**
   * Get the optimized image size from stdout.
   *
   * @param  string stdout
   * @return int
   */
  public int getNewSize (string stdout) {
    // After the piece of text and a space there should be the new size in bytes.
    var text = stdout.split("Output file size = ")[1];

    // The first integer until a space should be the new size in bytes.
    return int.parse(text.split(" ")[0]);
  }
}
