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
      css_provider.load_from_string (Stylesheet.STYLES);

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
    this.toolbar = new Toolbar ();
    this.set_titlebar (this.toolbar);

    //  for (int a = 0; a < 10; a++) {
    //    this.images += new Image ("", "", "");
    //  }

    var drop_target = new Gtk.DropTarget (typeof (Gdk.FileList), Gdk.DragAction.COPY);
    drop_target.leave.connect (this.on_drag_leave);
    drop_target.enter.connect (this.on_drag_enter);
    drop_target.drop.connect (this.on_drop);
    ((Gtk.Widget) this).add_controller (drop_target);

    if (images.length == 0) {
      this.upload_screen = new UploadScreen ();
      set_child (this.upload_screen.window ());

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
  public void set_images (Image[] images) {
    this.images = images;

    if (images.length == 0) {
      this.upload_screen = new UploadScreen ();
      set_child (this.upload_screen.window ());

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

    set_child (null);

    images_list = new List (this.images);
    set_child (images_list.window ());

    var add_image = new Gtk.Button.from_icon_name ("list-add-symbolic");
    add_image.set_tooltip_markup (_("Add Image"));
    this.toolbar.remove (add_image);

    add_image.get_style_context ().add_class ("titlebutton");
    add_image.get_style_context ().add_class ("add");
    add_image.clicked.connect (on_open_clicked);

    this.toolbar.pack_end (add_image);
  }

  /**
   * Gets called while a file is being dragged out of the application.
   *
   * @return void
   */
  private void on_drag_leave () {
    if (this.get_style_context ().has_class ("on_drag_enter")) {
      this.get_style_context ().remove_class ("on_drag_enter");
    }
  }

  /**
   * Gets called when a file is being dragged into the application while still holding the file.
   *
   * @param  double x
   * @param  double y
   * @return Gdk.DragAction
   */
  private Gdk.DragAction on_drag_enter (double x, double y) {
    if (! this.get_style_context ().has_class ("on_drag_enter") && ! this.get_style_context ().has_class ("list")) {
      this.get_style_context ().add_class ("on_drag_enter");
    }

    return Gdk.DragAction.COPY;
  }

  /**
   * Gets called when a file gets dropped into the application.
   *
   * @param  Value value
   * @param  double x
   * @param  double y
   * @return bool
   */
  private bool on_drop (Value value, double x, double y) {
    unowned var list = (Gdk.FileList) value;

    list.get_files ().foreach ((file) => {
      string uri = file.get_uri ();
      var path = Image.to_path (uri);
      if (path == null) {
        warning ("Failed to convert URI \"%s\" to path", uri);
        continue;
      }

      var name = Image.get_file_name (path);
      var type = Image.get_file_type (name);

      if (Image.is_valid (type.down ())) {
        this.images += new Image (path, name, type.down ());
      } else {
        // TODO: add an error message here
      }
    });

    if (images.length > 0 && this.images_list == null) {
      this.set_list_window ();
    } else if (this.images_list != null) {
      this.images_list.update_tree_view (this.images);
    }

    this.images = {};

    return true;
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

    file_chooser.response.connect ((response_id) => {
      if (response_id != Gtk.ResponseType.ACCEPT) {
        return;
      }

      ListModel files = file_chooser.get_files ();
      for (int i = 0; i < files.get_n_items (); i++) {
        var file = ((File) files.get_object (i));
        string path = file.get_path ();

        var name = Image.get_file_name (path);
        var type = Image.get_file_type (name);

        if (Image.is_valid (type.down ())) {
          this.images += new Image (path, name, type.down ());
        } else {
          // TODO: add an error message here
        }
      }

      if (this.images_list != null) {
        this.images_list.update_tree_view (this.images);
      }

      if (this.images.length > 0) {
        this.set_list_window ();
      }

      this.images = {};
    });

    file_chooser.present ();
  }
}
