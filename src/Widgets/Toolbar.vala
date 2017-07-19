using Gtk;

public class Toolbar : Gtk.HeaderBar {

  public Toolbar () {
    var header_context = this.get_style_context ();
    header_context.add_class ("toolbar");

    this.show_close_button = true;
    this.show_all ();
  }

}
