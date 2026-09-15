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

    var title = new Gtk.Label (_("Drag and drop images or folders here"));
    title.add_css_class ("h1");

    var otherwise = new Gtk.Label (_("or"));
    otherwise.add_css_class ("h4");

    this.upload_button = new Gtk.Button.with_label (_("Browse files"));
    // Deliberately not "suggested-action": that class hands the button to the
    // theme's accent colour, which on a red system accent drew a red outline
    // around it. The stylesheet gives it the app's own purple instead.
    this.upload_button.add_css_class ("upload_button");
    this.upload_button.set_valign (Gtk.Align.CENTER);
    ((Gtk.Widget) this.upload_button).set_focus_on_click (false);

    // One control and not two. A folder cannot come through the same dialog as a
    // file, because the chooser is asked for one or the other and there is no
    // dialog that offers both, but that is the portal's problem and not
    // something to hand to the person looking at this screen. So the button does
    // the ordinary thing when it is pressed, and the arrow beside it offers the
    // other one.
    // A menu model, for the same reason the header bar uses one: built out of a
    // button, the one item in here took keyboard focus the moment the menu
    // opened and was painted with the system accent colour, which on a red
    // accent looked like it had already been chosen.
    var choices = new GLib.Menu ();
    choices.append (_("Browse a folder"), "app.open-folder");

    var more = new Gtk.MenuButton ();
    more.set_icon_name ("pan-down-symbolic");
    more.set_tooltip_markup (_("Other ways to add images"));
    more.set_menu_model (choices);
    more.add_css_class ("upload_more");

    var menu = more.get_popover ();

    if (menu != null) {
      menu.add_css_class ("app_popover");
    }

    // "linked" is what makes the two read as one control rather than as two that
    // happen to touch: it is the class GTK's own themes use for exactly this.
    var buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
    buttons.add_css_class ("linked");
    buttons.set_halign (Gtk.Align.CENTER);
    buttons.append (this.upload_button);
    buttons.append (more);

    upload_area.append (icon);
    upload_area.append (title);
    upload_area.append (otherwise);
    upload_area.append (buttons);

    append (upload_area);

    return this;
  }
}
