using Gtk;

public class MainWindow : Gtk.Window {

  /**
   * Contains the images that are uploaded into the application.
   *
   * @var Image[]
   */
  private Image[] images = {};

  /**
   * An instance of the upload screen.
   *
   * @var UploadScreen
   */
  private UploadScreen upload_screen;

  /**
   * Contains a single type of data than can be supplied for by a widget for a
   * selection or for supplied or received during drag-and-drop.
   *
   * @var Gtk.TargetEntry[]
   */
  private const Gtk.TargetEntry[] targets = {
      {"text/uri-list",0,0}
  };

  /**
   * Create a new window.
   *
   * @param Gtk.Application application
   */
  public MainWindow (Gtk.Application application) {
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

    this.set_titlebar (new Toolbar ());

    //  for (var i = 0; i < 50; i++) {
    //    this.images += new Image("test", "test", "tesdt", 2);
    //  }

    if (images.length == 0) {
      this.upload_screen = new UploadScreen ();
      add (this.upload_screen.window ());

      this.upload_screen.upload_button.clicked.connect (on_open_clicked);

      //connect drag drop handlers
      Gtk.drag_dest_set (this, Gtk.DestDefaults.ALL, targets, Gdk.DragAction.COPY);
      this.drag_leave.connect (this.on_drag_leave);
      this.drag_motion.connect (this.on_drag_motion);
      this.drag_data_received.connect (this.on_drag_data_received);
    } else {
      var images_list = new List (this.images);
      var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

      box.pack_start(images_list.window (), true, true, 0);

      add (box);
    }
  }

  /**
   * Gets called while a file is being dragged out of the application.
   *
   * @param  Gdk.DragContext context
   * @param  uint time
   * @return void
   */
  private void on_drag_leave (Gdk.DragContext context, uint time) {
    if (this.get_style_context ().has_class ("on_drag_motion")) {
      this.get_style_context ().remove_class ("on_drag_motion");
    }
  }

  /**
   * Gets called when a file is being dragged into the application while still holding the file.
   *
   * @param  Gdk.DragContext context
   * @param  int x
   * @param  int y
   * @param  uint time
   * @return bool
   */
  private bool on_drag_motion (Gdk.DragContext context, int x, int y, uint time) {
    if (! this.get_style_context ().has_class ("on_drag_motion")) {
      this.get_style_context ().add_class ("on_drag_motion");
    }

    return true;
  }

  /**
   * Gets called when a file gets dropped into the application.
   *
   * @param  Gdk.DragContext drag_context
   * @param  int x
   * @param  int y
   * @param  Gtk.SelectionData data
   * @param  uint info
   * @param  uint time
   * @return void
   */
  private void on_drag_data_received (Gdk.DragContext drag_context, int x, int y, Gtk.SelectionData data, uint info, uint time)
  {
    foreach (string uri in data.get_uris ()) {
      var name = Image.getFileName (uri);
      var type = Image.getFileType (name);

      if (Image.isValid(type)) {
        this.images += new Image (uri, name, type, 0);
      }
    }

    if (images.length > 0) {
      remove (this.upload_screen);

      var images_list = new List (this.images);
      add (images_list.window ());

      show_all ();
    }

    Gtk.drag_finish (drag_context, true, false, time);
  }

  /**
   * Gets called when the button 'Browse files' gets clicked.
   *
   * @return void
   */
  public void on_open_clicked () {
    var file_chooser = new Gtk.FileChooserDialog ("Select image(s)", this,
                                  Gtk.FileChooserAction.OPEN,
                                  "_Cancel", Gtk.ResponseType.CANCEL,
                                  "_Open", Gtk.ResponseType.ACCEPT);

    file_chooser.select_multiple = true;

    if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
      foreach (string uri in file_chooser.get_filenames ()) {
        var name = Image.getFileName (uri);
        var type = Image.getFileType (name);

        if (Image.isValid (type)) {
          this.images += new Image (uri, name, type, 0);
        }
      }

      if (images.length > 0) {
        remove (this.upload_screen);

        var images_list = new List (this.images);
        add (images_list.window ());

        show_all ();
      }
    }

    file_chooser.destroy ();
  }
}
