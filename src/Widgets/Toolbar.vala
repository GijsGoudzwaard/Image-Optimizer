using Gtk;

public class Toolbar : Gtk.HeaderBar {

  public Toolbar () {
    var header_context = this.get_style_context ();
    header_context.add_class ("default-decoration");
    header_context.add_class ("flat");

    this.show_close_button = true;
    this.show_all ();
  }

}
