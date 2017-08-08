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
  private string[] args;

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
    //  print(string.join(" ", this.images));
  }
}
