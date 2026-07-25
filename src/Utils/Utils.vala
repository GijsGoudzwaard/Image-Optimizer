public class Utils {

  /**
   * Check if a needle can be found in a haystack.
   *
   * @return bool
   */
  public static bool in_array (string[] haystack, string needle) {
    foreach (var item in haystack) {
      if (item == needle) {
        return true;
      }
    }

    return false;
  }

  /**
   * Glue a string array together.
   *
   * @param  string glue
   * @param  string[] pieces
   * @return string
   */
  public static string join (string glue, string[] pieces) {
    string glued_string = "";

    foreach (var piece in pieces) {
      glued_string += piece + glue;
    }

    return glued_string;
  }

  /**
   * Read the byte count that directly follows a marker in an optimizer's
   * output.
   *
   * Returns 0 when the marker is not there. That happens whenever a tool could
   * not read the file, and callers already treat 0 as "size unchanged". Before
   * this was guarded, indexing past the split result handed a null string to
   * the next split and the app died with SIGSEGV on any file that had an image
   * extension but unreadable contents.
   *
   * @param  string output
   * @param  string marker
   * @return int
   */
  public static int size_after (string output, string marker) {
    var parts = output.split (marker);

    if (parts.length < 2) {
      return 0;
    }

    var fields = parts[1].split (" ");

    if (fields.length < 1) {
      return 0;
    }

    return int.parse (fields[0]);
  }
}
