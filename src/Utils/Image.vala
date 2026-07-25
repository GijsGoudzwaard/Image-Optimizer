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

    if (file.query_exists ()) {
      try {
        // Only the size is wanted, so do not make gio collect every attribute
        // it can find for every image that gets added.
        file_size = file.query_info (
          FileAttribute.STANDARD_SIZE,
          FileQueryInfoFlags.NONE
        ).get_size ();
      } catch (Error e) {
        warning ("Failed to get size of \"%s\": %s", this.path, e.message);
      }
    }

    this.size = file_size;
  }

  /**
   * Convert a URI to a path.
   *
   * @param  string uri  URI e.g. "file:///home/user/Pictures/test_pr%C3%BCfen_%E3%83%86%E3%82%B9%E3%83%88_%E6%B5%8B%E8%AF%95.png"
   * @return string?     Path e.g. "/home/user/Pictures/prüfen_测试.png" or null if no such file exists
   */
  public static string? to_path (string uri) {
    var file = File.new_for_uri (uri);
    return file.get_path ();
  }

  /**
   * Get file name from a path.
   *
   * @param  string path
   * @return string
   */
  public static string get_file_name (string path) {
    var array = path.split ("/");

    return array[array.length - 1];
  }

  /**
   * Get file type from a file.
   *
   * @param  string name
   * @return string
   */
  public static string get_file_type (string name) {
    var array = name.split (".");

    return array[array.length - 1];
  }

  /**
   * Check if a file type is a supported image.
   *
   * @param  string type
   * @return bool
   */
  public static bool is_valid (string type) {
    string[] supported_types = {
      "png",
      "jpg",
      "jpeg",
      "bmp"
    };

    return Utils.in_array (supported_types, type);
  }

  /**
   * Calculate the savings from the new size compared to the old size.
   * Returns a percentage.
   *
   * @param  float size
   * @param  float new_size
   * @return string
   */
  public static string calc_savings (float size, float new_size) {
    // A size of 0 means the file could not be read when it was added. Dividing
    // by it put a literal "-nan%" in the Savings column.
    if (size <= 0) {
      return "0.00%";
    }

    float savings = 100.00f - (new_size / size * 100.00f);

    return "%.2f%%".printf (savings);
  }
}
