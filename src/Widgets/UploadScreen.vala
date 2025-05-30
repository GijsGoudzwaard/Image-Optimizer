using Gtk;

public class UploadScreen : Gtk.Box {

  public Gtk.Button upload_button;

  public Gtk.Box window () {
    this.border_width = 10;
    this.get_style_context ().add_class ("main");

    var upload_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
    upload_area.set_spacing (15);
    upload_area.set_valign (Gtk.Align.CENTER);
    upload_area.set_halign (Gtk.Align.CENTER);

    var icon = new Gtk.Image.from_resource ("/com/github/gijsgoudzwaard/image-optimizer/icons/upload_icon.svg");

    var title = new Gtk.Label (_("Drag and drop images here"));
    title.get_style_context ().add_class ("h1");

    var otherwise = new Gtk.Label (_("or"));
    otherwise.get_style_context ().add_class ("h4");

    this.upload_button = new Gtk.Button.with_label (_("Browse files"));
    this.upload_button.get_style_context ().add_class ("suggested-action");
    this.upload_button.get_style_context ().add_class ("upload_button");
    this.upload_button.set_valign (Gtk.Align.CENTER);
    this.upload_button.set_halign (Gtk.Align.CENTER);
    ((Gtk.Widget) this.upload_button).set_focus_on_click (false);

    upload_area.pack_start (icon, false, false, 0);
    upload_area.pack_start (title, false, false, 0);
    upload_area.pack_start (otherwise, false, false, 0);
    upload_area.pack_start (this.upload_button, false, false, 0);

    pack_start (upload_area);

    return this;
  }
}
