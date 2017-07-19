using Gtk;

class MainWindow : Gtk.Window {

  private Image[] images;

  public MainWindow(Gtk.Application application) {
    Object (
      application: application,
      height_request: 680,
      icon_name: "com.github.gijsgoudzwaard.image-optimizer",
      resizable: true,
      title: "Image Optimizer",
      width_request: 980
    );

    Granite.Widgets.Utils.set_theming_for_screen (
        this.get_screen(),
        Stylesheet.STYLES,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    );
  }

  construct {
    this.window_position = Gtk.WindowPosition.CENTER;

    if (images.length == 0) {
      this.uploadScreen();
    } else {
      this.imageList();
    }
  }

  private void imageList() {
    //
  }

  private void uploadScreen() {
    this.set_titlebar(new Toolbar());

    var main = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
    main.border_width = 10;
    main.get_style_context().add_class("main");

    var upload_area = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
    upload_area.set_spacing(15);
    upload_area.set_valign(Gtk.Align.CENTER);
    upload_area.set_halign(Gtk.Align.CENTER);

    Gtk.Image icon = new Gtk.Image();

    try {
      var icon_pixbuf = new Gdk.Pixbuf.from_file_at_scale("/usr/share/icons/hicolor/scalable/apps/upload_icon.svg", 64, 64, true);
      icon = new Gtk.Image.from_pixbuf(icon_pixbuf);
    } catch (Error e) {}

    var title = new Gtk.Label("Drag and drop images here");
    title.get_style_context().add_class("h1");

    var otherwise = new Gtk.Label("or");
    otherwise.get_style_context().add_class("h4");

    var upload_button = new Gtk.Button.with_label("Browse files");
    upload_button.get_style_context().add_class("upload_button");
    upload_button.clicked.connect(on_open_clicked);
    upload_button.set_valign(Gtk.Align.CENTER);
    upload_button.set_halign(Gtk.Align.CENTER);
    upload_button.set_focus_on_click(false);

    if (icon != null) {
      upload_area.pack_start(icon, false, false, 0);
    }

    upload_area.pack_start(title, false, false, 0);
    upload_area.pack_start(otherwise, false, false, 0);
    upload_area.pack_start(upload_button, false, false, 0);

    main.pack_start(upload_area);

    add(main);
  }

    private void on_open_clicked () {
      var file_chooser = new FileChooserDialog ("Open File", this,
                                    FileChooserAction.OPEN,
                                    "_Cancel", ResponseType.CANCEL,
                                    "_Open", ResponseType.ACCEPT);
      if (file_chooser.run () == ResponseType.ACCEPT) {
          open_file (file_chooser.get_filename ());
      }

      file_chooser.destroy ();
    }

  private void open_file (string filename) {
      try {
          string text;
          FileUtils.get_contents (filename, out text);
          //  this.text_view.buffer.text = text;
          print(filename);

      } catch (Error e) {
          stderr.printf ("Error: %s\n", e.message);
      }
  }
}
