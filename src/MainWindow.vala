/**
 * Installs a css provider for a whole display.
 *
 * Declared here rather than called through the binding, because valac marks
 * Gtk.StyleContext deprecated as a class while this one static function is not:
 * it is GDK_AVAILABLE_IN_ALL in gtkstyleprovider.h and is still the documented
 * way to do this. GTK offers nothing to migrate to, so the alternative is a
 * warning on every build that nobody can act on.
 *
 * The generated C call is the same one the binding would have generated. If GTK
 * ever really removes the function, this turns into a compile error instead of a
 * warning, which is the right way round.
 */
[CCode (cname = "gtk_style_context_add_provider_for_display")]
extern void add_provider_for_display (Gdk.Display display, Gtk.StyleProvider provider, uint priority);

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
    // default-width and default-height, not width-request and height-request:
    // a size request is a minimum, so the window opened at the smallest size it
    // was allowed to be and could never be made narrower. The size it opens at
    // is unchanged, the floor is set separately in construct.
    Object (
      application: application,
      default_height: 680,
      default_width: 980,
      icon_name: "com.github.gijsgoudzwaard.image-optimizer",
      resizable: true,
      title: _("Image Optimizer")
    );

    // This is a Gtk.Window and not a Gtk.ApplicationWindow, and the "app" action
    // group is something the latter inserts for you. Without this line every
    // menu item that names an app action is an item GTK cannot resolve, which it
    // shows as an item that is there but greyed out and does nothing.
    this.insert_action_group ("app", application);

    var css_provider = new Gtk.CssProvider ();
    css_provider.load_from_string (Stylesheet.STYLES);

    // See the declaration above this class for why this does not go through
    // Gtk.StyleContext.
    add_provider_for_display (
      this.get_display (),
      css_provider,
      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    );
  }

  construct {
    // The floor, which is not the same thing as the size it opens at. Without one
    // the window can be dragged down to 221x170, where the columns run into each
    // other. The number itself is what the four columns need: 308px of fixed
    // width, plus enough of the file name to still recognise a file by, and
    // everything that could grow past that ellipsizes.
    this.set_size_request (460, 320);

    this.toolbar = new Gtk.HeaderBar ();
    toolbar.add_css_class ("default-decoration");
    toolbar.add_css_class ("flat");
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

    this.add_css_class ("list");

    images_list = new List (this.images);
    set_child (images_list.window ());

    // One button, and what it can add is a choice inside it rather than two
    // buttons asking the same question twice. The file chooser is asked for
    // files or for folders and there is no dialog that offers both, but that is
    // the portal's problem and not something to put on this bar.
    //
    // A menu model and not a box of buttons. GTK builds a real menu out of this,
    // which knows that only one item is highlighted at a time and that keyboard
    // focus is not the same thing as being chosen. Built by hand it was neither:
    // the item that had focus kept the system accent colour around it, red on a
    // red accent, and stayed lit while the pointer highlighted another.
    var choices = new GLib.Menu ();
    choices.append (_("Images…"), "app.open-files");
    choices.append (_("A folder…"), "app.open-folder");

    // "flat" and not "titlebutton": titlebutton is meant for window controls and
    // brought the theme's light button background with it, while the stylesheet
    // forces icons in this header bar white. That put a white plus on a white
    // button.
    //
    // The second class is the app's own and not the generic "add" it used to be:
    // themes colour a button like this with the system accent, which on a red
    // accent put a red button on a purple bar. The stylesheet gives it a flat
    // look with its own hover and pressed states instead.
    var add = new Gtk.MenuButton ();
    add.set_icon_name ("list-add-symbolic");
    add.set_tooltip_markup (_("Add images or a folder"));
    add.set_menu_model (choices);
    add.add_css_class ("flat");
    add.add_css_class ("add_image");
    // Without this the button takes the whole height of the bar and sits against
    // the top of it rather than in the middle of it.
    add.set_valign (Gtk.Align.CENTER);

    // The menu GTK builds from the model is painted by this app like everything
    // else it shows. Left to the theme it comes out as a black rectangle on a
    // plain GTK install, and its labels come out white, because a popover
    // hanging off this bar is a child of it as far as the stylesheet is
    // concerned and this bar paints every label in it white.
    var menu = add.get_popover ();

    if (menu != null) {
      menu.add_css_class ("app_popover");
    }

    this.toolbar.pack_start (add);
  }

  /**
   * Gets called while a file is being dragged out of the application.
   *
   * @return void
   */
  private void on_drag_leave () {
    if (this.has_css_class ("on_drag_enter")) {
      this.remove_css_class ("on_drag_enter");
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
    if (! this.has_css_class ("on_drag_enter") && ! this.has_css_class ("list")) {
      this.add_css_class ("on_drag_enter");
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
    // Nothing here asks for the document portal, and that is deliberate: GDK
    // offers and accepts application/vnd.portal.filetransfer and calls
    // org.freedesktop.portal.FileTransfer itself, so inside a sandbox the paths
    // below already point into this app's document namespace and carry a grant.
    // That is what lets the manifest ship without --filesystem=home.
    //
    // It depends on the app being dragged from doing the same. Anything that
    // offers plain file:// URIs instead hands over a path the sandbox cannot
    // open, which shows up as a row that fails to optimize rather than as a
    // crash. Sources that use GTK, which includes Files, do the portal side.
    unowned var list = (Gdk.FileList) value;
    File[] folders = {};

    list.get_files ().foreach ((file) => {
      string uri = file.get_uri ();
      var path = Image.to_path (uri);
      if (path == null) {
        warning ("Failed to convert URI \"%s\" to path", uri);
        return;
      }

      // A folder is not a file and does not become a row. It is looked through
      // first and what it holds waits for the button in the bar, because this
      // one gesture can reach everything under it.
      if (FileUtils.test (path, FileTest.IS_DIR)) {
        folders += File.new_for_path (path);

        return;
      }

      var name = Image.get_file_name (path);
      var type = Image.get_file_type (name);

      // Unsupported files are added too. They used to be dropped here without a
      // word, so someone who selected a folder of mixed contents saw a shorter
      // list than they picked and had no way to tell which files were left out.
      // The Image knows it cannot be optimized and the list says so.
      this.images += new Image (path, name, type.down ());
    });

    this.take (folders);

    return true;
  }

  /**
   * Put what just arrived where it belongs: files into the list, folders into a
   * walk. Either of them may be the first thing to arrive, so this is also what
   * builds the list window.
   *
   * @param  File[] folders
   * @return void
   */
  private void take (File[] folders) {
    if (this.images_list == null && (this.images.length > 0 || folders.length > 0)) {
      this.set_list_window ();
    } else if (this.images_list != null && this.images.length > 0) {
      this.images_list.update_tree_view (this.images);
    }

    if (folders.length > 0 && this.images_list != null) {
      this.images_list.scan (folders);
    }

    this.images = {};
  }

  /**
   * Folders that arrived from somewhere other than this window: the command
   * line, or Open With on a folder.
   *
   * @param  File[] folders
   * @return void
   */
  public void add_folders (File[] folders) {
    this.take (folders);
  }

  /**
   * Gets called when the folder button gets clicked.
   *
   * A dialog of its own, because the portal is asked either for files or for
   * folders and there is no way to offer both in one.
   *
   * @return void
   */
  public async void on_open_folder_clicked () {
    var folder_dialog = new Gtk.FileDialog ();
    folder_dialog.title = _("Select a folder");

    ListModel folders;

    try {
      folders = yield folder_dialog.select_multiple_folders (this, null);
    } catch (Error err) {
      if (err.domain == Gtk.DialogError.quark () && err.code == Gtk.DialogError.DISMISSED) {
        return;
      }

      warning ("Failed to select folders: %s", err.message);

      return;
    }

    File[] picked = {};

    for (int i = 0; i < folders.get_n_items (); i++) {
      picked += (File) folders.get_object (i);
    }

    this.take (picked);
  }

  /**
   * Gets called when the button 'Browse files' or '+' gets clicked.
   *
   * @return void
   */
  public async void on_open_clicked () {
    var file_dialog = new Gtk.FileDialog ();
    file_dialog.title = _("Select image(s)");

    ListModel files;
    try {
      files = yield file_dialog.open_multiple (this, null);
    } catch (Error err) {
      if (err.domain == Gtk.DialogError.quark () && err.code == Gtk.DialogError.DISMISSED) {
        // Don't show the warning log and do nothing when the dialog is just dismissed by the user
        return;
      }

      warning ("Failed to open multiple files: %s", err.message);
      return;
    }

    for (int i = 0; i < files.get_n_items (); i++) {
      var file = ((File) files.get_object (i));
      string path = file.get_path ();

      var name = Image.get_file_name (path);
      var type = Image.get_file_type (name);

      // Same as in on_drop: nothing is thrown away silently.
      this.images += new Image (path, name, type.down ());
    }

    this.take ({});
  }
}
