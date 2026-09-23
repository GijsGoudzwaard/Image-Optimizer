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
   * How an action's keyboard shortcut is written for somebody to read, or an
   * empty string when it has none.
   *
   * Read from the application rather than typed out wherever it is shown, so
   * that a shortcut and the label claiming it cannot drift apart. GTK does this
   * by itself for an item in a menu model, which is how both ways of adding
   * something are labelled in the header bar, but a plain button gets nothing.
   *
   * @param  string action  e.g. "app.open-files"
   * @return string
   */
  public static string accelerator_label (string action) {
    var application = GLib.Application.get_default () as Gtk.Application;

    if (application == null) {
      return "";
    }

    var accelerators = application.get_accels_for_action (action);

    if (accelerators.length == 0) {
      return "";
    }

    uint key;
    Gdk.ModifierType modifiers;

    if (! Gtk.accelerator_parse (accelerators[0], out key, out modifiers)) {
      return "";
    }

    return Gtk.accelerator_get_label (key, modifiers);
  }
}
