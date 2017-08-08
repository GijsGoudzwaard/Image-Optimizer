using Gtk;

public class Image {
  /**
   * The image path.
   *
   * @var string
   */
  public string path;

  /**
   * The image name.
   *
   * @var string
   */
  public string name;

  /**
   * The image type.
   *
   * @var string
   */
  public string type;

  /**
   * The image size before optimizing.
   *
   * @var int
   */
  public int size;

  /**
   * The image size after optimizing.
   *
   * @var int
   */
  public int new_size = 0;

  /**
   * The image savings percentage after the image is optimized.
   *
   * @var int
   */
  public int savings = 0;

  /**
   * Set the image properties.
   *
   * @param string path
   * @param string name
   * @param string type
   * @param int size
   */
  public Image(string path, string name, string type, int size) {
    this.path = path;
    this.name = name;
    this.type = type;
    this.size = size;

    this.savings = 0;
  }

  /**
   * Get file name from a path.
   *
   * @param  string path
   * @return string
   */
  public static string getFileName(string path) {
    var array = path.split("/");

    return array[array.length - 1];
  }

  /**
   * Get file type from a file.
   *
   * @param  string name
   * @return string
   */
  public static string getFileType(string name) {
    var array = name.split(".");

    return array[array.length - 1];
  }

  /**
   * Check if a file type is a supported image.
   *
   * @param  string type
   * @return bool
   */
  public static bool isValid(string type) {
    string[] supported_types = {
      "png",
      "jpg",
      "jpeg"
    };

    return Utils.inArray(supported_types, type);
  }
}
