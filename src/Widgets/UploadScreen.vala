using Gtk;

public class UploadScreen : Gtk.Box {

  public Gtk.Button upload_button;

  public Gtk.Box window () {
    this.margin_top = 10;
    this.margin_bottom = 10;
    this.margin_start = 10;
    this.margin_end = 10;
    this.add_css_class ("main");

    var upload_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
    upload_area.set_spacing (15);
    upload_area.set_valign (Gtk.Align.CENTER);
    upload_area.set_halign (Gtk.Align.CENTER);
    upload_area.set_vexpand (true);
    upload_area.set_hexpand (true);

    var icon = new Gtk.Image.from_resource ("/com/github/gijsgoudzwaard/image-optimizer/icons/upload_icon.svg");
    icon.set_pixel_size (64);

    var title = new Gtk.Label (_("Drag and drop images here"));
    title.add_css_class ("h1");

    var otherwise = new Gtk.Label (_("or"));
    otherwise.add_css_class ("h4");

    this.upload_button = new Gtk.Button.with_label (_("Browse files"));
    // Deliberately not "suggested-action": that class hands the button to the
    // theme's accent colour, which on a red system accent drew a red outline
    // around it. The stylesheet gives it the app's own purple instead.
    this.upload_button.add_css_class ("upload_button");
    this.upload_button.set_valign (Gtk.Align.CENTER);
    this.upload_button.set_halign (Gtk.Align.CENTER);
    ((Gtk.Widget) this.upload_button).set_focus_on_click (false);

    upload_area.append (icon);
    upload_area.append (title);
    upload_area.append (otherwise);
    upload_area.append (this.upload_button);

    append (upload_area);

    return this;
  }
}
