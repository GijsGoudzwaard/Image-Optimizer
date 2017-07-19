using Gtk;

public class MainWindow : Gtk.Window {

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

    this.set_titlebar(new Toolbar());

    if (images.length == 0) {
      var upload_screen = new UploadScreen();
      add(upload_screen.window());

      upload_screen.upload_button.clicked.connect(on_open_clicked);
    } else {
      this.imageList();
    }
  }

  private void imageList() {
    //
  }

  public void on_open_clicked () {
    var file_chooser = new FileChooserDialog ("Open File", this,
                                  FileChooserAction.OPEN,
                                  "_Cancel", ResponseType.CANCEL,
                                  "_Open", ResponseType.ACCEPT);

    if (file_chooser.run () == ResponseType.ACCEPT) {
      open_file (file_chooser.get_filename ());
    }

    file_chooser.destroy ();
  }

  public void open_file (string filename) {
    try {
      string text;
      FileUtils.get_contents (filename, out text);

      print(filename);
    } catch (Error e) {
      stderr.printf ("Error: %s\n", e.message);
    }
  }
}
