using Granite.Widgets;

class Application : Granite.Application {

  private Image[] images = {};
  private MainWindow app_window;

  public Application() {
    Object (application_id: "com.github.gijsgoudzwaard.image-optimizer",
        flags: GLib.ApplicationFlags.HANDLES_OPEN);
  }

  protected override void activate() {
    if (this.app_window == null) {
      this.app_window = new MainWindow (this);
      this.app_window.show_all();
    }

    var quit_action = new SimpleAction ("quit", null);

    add_action (quit_action);
    set_accels_for_action ("app.quit", {"<Control>q"});

    quit_action.activate.connect (() => {
      if (this.app_window != null) {
        this.app_window.destroy ();
      }
    });
  }

  public override void open(File[] files, string hint) {
    if (files [0].query_exists ()) {
      foreach (File file in files) {
        var uri = file.get_path().replace("%20", " ").replace("file://", "");

        var name = Image.getFileName (uri);
        var type = Image.getFileType (file.get_basename());

        if (Image.isValid (type.down())) {
          this.images += new Image (uri, name, type.down());
        } else {
          // TODO: add an error message here
        }
      }

      if (this.app_window == null) {
        this.app_window = new MainWindow (this);
        this.app_window.show_all();
      }

      this.app_window.set_images(this.images);
    }
  }

  public static int main (string[] args) {
    Gtk.init (ref args);
    var app = new Application ();
    return app.run (args);
  }
}
