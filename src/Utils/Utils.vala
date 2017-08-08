public class Utils {

  /**
   * Check if a needle can be found in a haystack.
   *
   * @return bool
   */
  public static bool inArray(string[] haystack, string needle) {
    foreach (var item in haystack) {
      if (item == needle) {
        return true;
      }
    }

    return false;
  }
}
