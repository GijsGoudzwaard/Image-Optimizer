public class Utils {

  /**
   * Check if a needle can be found in a haystack.
   *
   * @return bool
   */
  public static bool inArray (string[] haystack, string needle) {
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
}
