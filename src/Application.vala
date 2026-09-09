class Application : Gtk.Application {

  private Image[] images = {};
  private MainWindow app_window;

  public Application () {
    Object (application_id: "com.github.gijsgoudzwaard.image-optimizer",
        flags: GLib.ApplicationFlags.HANDLES_OPEN);
  }

  protected override void startup () {
    base.startup ();

    var quit_action = new SimpleAction ("quit", null);

    add_action (quit_action);
    set_accels_for_action ("app.quit", {"<Control>q"});

    quit_action.activate.connect (() => {
      if (this.app_window != null) {
        this.app_window.destroy ();
      }
    });
  }

  protected override void activate () {
    if (this.app_window == null) {
      this.app_window = new MainWindow (this);
      this.app_window.present ();
    }
  }

  public override void open (File[] files, string hint) {
    if (files [0].query_exists ()) {
      foreach (File file in files) {
        var path = file.get_path ();

        var name = Image.get_file_name (path);
        var type = Image.get_file_type (file.get_basename ());

        // Kept in step with MainWindow: a file that arrives through Open With or
        // the command line gets a row saying it is not supported, rather than
        // disappearing on the way in.
        this.images += new Image (path, name, type.down ());
      }

      if (this.app_window == null) {
        this.app_window = new MainWindow (this);
        this.app_window.present ();
      }

      this.app_window.set_images (this.images);
    }
  }

  /**
   * Runs on the way out, whatever asked for it: Ctrl+Q, the close button or the
   * last window going away.
   *
   * The workers are detached threads, so nothing here waits for the batch as a
   * whole, and it should not: someone who quits wants to quit. What it does wait
   * for is the write back, because that is a write followed by a truncate and a
   * file caught between the two is neither the old image nor the new one. Those
   * writes are one buffer each, so this is milliseconds in practice.
   *
   * The cap means a wedged write costs two seconds and then the app leaves
   * anyway. Nothing can be done about a kill -9, which is fine: the optimizers
   * work on a copy and the original is only ever touched here.
   *
   * @return void
   */
  protected override void shutdown () {
    for (var waited = 0; waited < 200 && Rewrite.is_committing (); waited++) {
      Thread.usleep (10000);
    }

    base.shutdown ();
  }

  public static int main (string[] args) {
    var app = new Application ();
    return app.run (args);
  }
}
