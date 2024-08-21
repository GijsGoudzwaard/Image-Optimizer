using Gtk;

public class MainWindow : Gtk.Window {

  /**
   * Contains the images that are uploaded into the application.
   *
   * @var Image[]
   */
  private Image[] images = {};

  /**
   * An instance of the header bar.
   *
   * @var Gtk.HeaderBar
   */
  private Gtk.HeaderBar toolbar;

  /**
   * An instance of the upload screen.
   *
   * @var UploadScreen
   */
  private UploadScreen upload_screen;

  /**
   * An instance of the list screen.
   *
   * @var List
   */
  private List images_list;

  /**
   * Contains a single type of data than can be supplied for by a widget for a
   * selection or for supplied or received during drag-and-drop.
   *
   * @var Gtk.TargetEntry[]
   */
  private const Gtk.TargetEntry[] TARGETS = {
      {"text/uri-list", 0, 0}
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
      title: _("Image Optimizer"),
      width_request: 980
    );

    var css_provider = new Gtk.CssProvider ();
    try {
      css_provider.load_from_data (Stylesheet.STYLES);

      Gtk.StyleContext.add_provider_for_screen (
        this.get_screen (),
        css_provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
      );
    } catch (Error e) {
      stdout.printf ("Error: %s\n", e.message);
    }
  }

  construct {
    this.window_position = Gtk.WindowPosition.CENTER;

    this.toolbar = new Toolbar ();
    this.set_titlebar (this.toolbar);

    //  for (int a = 0; a < 10; a++) {
    //    this.images += new Image ("", "", "");
    //  }

    Gtk.drag_dest_set (this, Gtk.DestDefaults.ALL, TARGETS, Gdk.DragAction.COPY);
    this.drag_leave.connect (this.on_drag_leave);
    this.drag_motion.connect (this.on_drag_motion);
    this.drag_data_received.connect (this.on_drag_data_received);

    if (images.length == 0) {
      this.upload_screen = new UploadScreen ();
      add (this.upload_screen.window ());

      this.upload_screen.upload_button.clicked.connect (on_open_clicked);
    } else {
      this.set_list_window ();
    }
  }

  /**
   * Set the images and set the appropriate view.
   *
   * @param  Image images
   * @return void
   */
  public void set_images(Image[] images) {
    this.images = images;

    if (images.length == 0) {
      this.upload_screen = new UploadScreen ();
      add (this.upload_screen.window ());

      this.upload_screen.upload_button.clicked.connect (on_open_clicked);
    } else {
      this.set_list_window ();
    }
  }

  /**
   * Set the list window, if it is already set and the method is called again return void.
   *
   * @return void
   */
  private void set_list_window () {
    if (this.images_list != null) {
      return;
    }

    this.get_style_context ().add_class ("list");

    remove (this.upload_screen);

    images_list = new List (this.images);
    add (images_list.window ());

    var add_image = new Gtk.Button.from_icon_name ("list-add-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
    add_image.set_tooltip_markup (_("Add Image"));
    this.toolbar.remove (add_image);

    add_image.get_style_context ().add_class ("titlebutton");
    add_image.get_style_context ().add_class ("add");
    add_image.clicked.connect (on_open_clicked);

    this.toolbar.pack_end (add_image);
    this.toolbar.show_all ();

    show_all ();
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
    Gtk.drag_unhighlight (this);

    if (! this.get_style_context ().has_class ("on_drag_motion") && ! this.get_style_context ().has_class ("list")) {
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
      uri = uri.replace ("%20", " "). replace("file://", "");

      var name = Image.getFileName (uri);
      var type = Image.getFileType (name);

      if (Image.isValid (type.down ())) {
        this.images += new Image (uri, name, type.down ());
      } else {
        // TODO: add an error message here
      }
    }

    if (images.length > 0 && this.images_list == null) {
      this.set_list_window ();
    } else if (this.images_list != null) {
      this.images_list.updateTreeView (this.images);
    }

    this.images = {};

    Gtk.drag_finish (drag_context, true, false, time);
  }

  /**
   * Gets called when the button 'Browse files' or '+' gets clicked.
   *
   * @return void
   */
  public void on_open_clicked () {
    var file_chooser = new Gtk.FileChooserDialog (_("Select image(s)"), this,
                                  Gtk.FileChooserAction.OPEN,
                                  _("_Cancel"), Gtk.ResponseType.CANCEL,
                                  _("_Open"), Gtk.ResponseType.ACCEPT);

    file_chooser.select_multiple = true;

    if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
      foreach (string uri in file_chooser.get_filenames ()) {
        var name = Image.getFileName (uri);
        var type = Image.getFileType (name);

        if (Image.isValid (type.down ())) {
          this.images += new Image (uri, name, type.down ());
        } else {
          // TODO: add an error message here
        }
      }

      if (this.images_list != null) {
        this.images_list.updateTreeView (this.images);
      }

      if (this.images.length > 0) {
        this.set_list_window ();
      }

      this.images = {};
    }

    file_chooser.destroy ();
  }
}
