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
  private string[] args = {"--strip-all"};

  /**
   * Add images to the current object.
   *
   * @return void
   */
  public void addImage(string image) {
    this.images += image;
  }

  /**
   * Optimize the images using jpegoptim.
   *
   * @return void
   */
  public void optimize() {
    var command = "jpegoptim " + Utils.join(" ", this.args);

    foreach (var image in this.images) {
      try {
        print(command + " " + image);
        Process.spawn_command_line_sync (command + " " + image);
      } catch (SpawnError e) {
        stdout.printf ("Error: %s\n", e.message);
      }
    }

  }
}
