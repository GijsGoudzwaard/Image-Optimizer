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
  private string[] args = {"-o7", "-preserve"};

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
  public void addImage(string image) {
    this.images += image;
  }

  /**
   * Compress the images using optipng.
   *
   * @return void
   */
  public void compress() throws ThreadError {
    var command = "optipng " + Utils.join(" ", this.args);

    ThreadFunc<void*> run = () => {
      foreach (var image in this.images) {
        string ls_stdout;
        string ls_stderr;
        int ls_status;

        try {
          Process.spawn_command_line_sync (
            command + " " + image.replace(" ", "\\ "),
            out ls_stdout,
            out ls_stderr,
            out ls_status
          );

          var new_size = this.getNewSize(ls_stdout);
          this.list.updateSize(image, new_size);

        } catch (SpawnError e) {
          stdout.printf ("Error: %s\n", e.message);
        }
      }

      return null;
    };

    Thread.create<void*>(run, false);
    yield;
  }

  /**
   * Get the optimized image size from stdout.
   *
   * @param  string stdout
   * @return int
   */
  public int getNewSize (string stdout) {
    // If stdout contains this piece of text, there was no change.
    if (stdout.contains("is already optimized")) {
      return 0;
    }

    // The first integer until a space should be the new size in bytes.
    return 0;
  }
}
