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
   * Add images to the current object.
   *
   * @return void
   */
  public void addImage(string image) {
    this.images += image;
  }

  /**
   * Optimize the images using optipng.
   *
   * @return void
   */
  public void optimize() {
    var command = "optipng " + Utils.join(" ", this.args);

    foreach (var image in this.images) {
      try {
        Process.spawn_command_line_async (command + " " + image.replace(" ", "\\ "));
      } catch (SpawnError e) {
        stdout.printf ("Error: %s\n", e.message);
      }
    }
  }
}
