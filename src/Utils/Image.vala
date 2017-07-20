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
   * Set the image properties.
   *
   * @param string path
   * @param string name
   * @param string type
   */
  public Image(string path, string name, string type) {
    this.path = path;
    this.name = name;
    this.type = type;
  }

  /*
   * Get file name from a path.
   *
   * @param  string path
   * @return string
   */
  public static string getFileName(string path) {
    var array = path.split("/");

    return array[array.length - 1];
  }

  /*
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
    var is_image = false;

    string[] supported_types = {
      "png",
      "jpg",
      "jpeg"
    };

    foreach (string image_type in supported_types) {
      if (image_type == type) {
        is_image = true;

        break;
      }
    }

    return is_image;
  }
}