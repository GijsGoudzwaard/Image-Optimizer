using Gtk;

public class MainWindow : Gtk.Window {

  private Image[] images;

  private UploadScreen upload_screen;

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

    //  for (var i = 0; i < 50; i++) {
    //    this.images += new Image("test", "test", "tesdt");
    //  }

    if (images.length == 0) {
      this.upload_screen = new UploadScreen();
      add(this.upload_screen.window());

      this.upload_screen.upload_button.clicked.connect(on_open_clicked);
    } else {
      var images_list = new List(this.images);
      add(images_list.window());
    }
  }

  public void on_open_clicked () {
    var file_chooser = new Gtk.FileChooserDialog ("Select image(s)", this,
                                  Gtk.FileChooserAction.OPEN,
                                  "_Cancel", Gtk.ResponseType.CANCEL,
                                  "_Open", Gtk.ResponseType.ACCEPT);

    file_chooser.select_multiple = true;

    if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
      foreach (string uri in file_chooser.get_filenames()) {
        var name = Image.getFileName(uri);
        var type = Image.getFileType(name);

        if (Image.isValid(type)) {
          images += new Image(uri, name, type);
        }
      }

      if (images.length > 0) {
        remove(this.upload_screen);

        var images_list = new List(this.images);
        add(images_list.window());

        show_all();
      }

    }

    file_chooser.destroy ();
  }
}
