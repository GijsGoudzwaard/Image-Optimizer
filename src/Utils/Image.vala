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
   * @var int64
   */
  public int64 size;

  /**
   * The image size after optimizing.
   *
   * @var int64
   */
  public int64 new_size = 0;

  /**
   * Set the image properties.
   *
   * @param string path
   * @param string name
   * @param string type
   */
  public Image (string path, string name, string type) {
    this.path = path;
    this.name = name;
    this.type = type;

    File file = File.new_for_path (path);
    int64 file_size = 0;

    try {
      file_size = file.query_info ("*", FileQueryInfoFlags.NONE).get_size ();
    } catch (Error e) {
      stdout.printf ("Error occurred");
    }

    this.size = file_size;
  }

  /**
   * Get file name from a path.
   *
   * @param  string path
   * @return string
   */
  public static string getFileName (string path) {
    var array = path.split("/");

    return array[array.length - 1];
  }

  /**
   * Get file type from a file.
   *
   * @param  string name
   * @return string
   */
  public static string getFileType (string name) {
    var array = name.split(".");

    return array[array.length - 1];
  }

  /**
   * Check if a file type is a supported image.
   *
   * @param  string type
   * @return bool
   */
  public static bool isValid (string type) {
    string[] supported_types = {
      "png",
      "jpg",
      "jpeg"
    };

    return Utils.inArray (supported_types, type);
  }

  /**
   * Get size in bytes and return in proper units (bytes, KB, MB).
   *
   * @param  int64 bytes
   * @return string
   */
  public static string getUnit (int64 bytes) {
    var unit = "";

    if (bytes > 1000 && bytes < 1000000) {
      var size = "%.2f".printf (((double) bytes) / 1000);
      unit = size.to_string ().replace (".", ",") + " kb";
    } else if (bytes > 1000000) {
      var size = "%.2f".printf (((double) bytes) / 1000000);
      unit = size.to_string ().replace (".", ",") + " mb";
    } else {
      unit = bytes.to_string () + " bytes";
    }

    return unit;
  }

  public static string calcSavings (float size, float new_size) {
    float savings = 100.00f - (new_size / size * 100.00f);

    return "%.2f%%".printf(savings);
  }
}
