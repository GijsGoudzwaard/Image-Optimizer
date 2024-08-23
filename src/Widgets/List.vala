using Gtk;

public class List {

  private Image[] images;

  private Gtk.ListStore listmodel;

  public Gtk.Button upload_button;

  public List (Image[] images) {
    this.images = images;
  }

  public Gtk.ScrolledWindow window () {
    var main = new Gtk.ScrolledWindow (null, null);
    main.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);

    listmodel = new Gtk.ListStore (6, typeof (bool), typeof (int), typeof (string), typeof (string), typeof (string), typeof (string));

    this.upload_button = new Gtk.Button.with_label ("+");
    this.upload_button.get_style_context ().add_class ("upload_button");
    this.upload_button.get_style_context ().add_class ("add");
    this.upload_button.set_valign (Gtk.Align.START);
    this.upload_button.set_halign (Gtk.Align.END);
    ((Gtk.Widget) this.upload_button).set_focus_on_click (false);

    Gtk.TreeIter iter;
    foreach (var image in this.images) {
      listmodel.append (out iter);
      listmodel.set (iter,
                    0, true,
                    1, 1,
                    2, image.name,
                    3, Image.getUnit (image.size),
                    4, "",
                    5, "");
    }

    var view = new Gtk.TreeView.with_model (listmodel);
    view.get_style_context ().add_class ("tree_view");
    main.add (view);

    var cell = new Gtk.CellRendererText ();
    cell.height = 50;
    cell.width = 150;
    cell.wrap_width = 10;
    var spinner = new Gtk.CellRendererSpinner ();

    Gtk.TreeViewColumn column = new Gtk.TreeViewColumn ();
		column.set_title ("");
		column.pack_start (spinner, false);
		column.add_attribute (spinner, "active", 0);
		column.add_attribute (spinner, "pulse", 1);
		view.append_column (column);

    view.insert_column_with_attributes (2, _("File"), cell, "text", 2);
		view.insert_column_with_attributes (3, _("Size"), cell, "text", 3);
		view.insert_column_with_attributes (4, _("New size"), cell, "text", 4);
    view.insert_column_with_attributes (5, _("Savings"), cell, "text", 5);

    // Rotate the spinner:
		Timeout.add (50, () => {
			listmodel.foreach ((model, path, iter) => {
				Value val;
				listmodel.get_value (iter, 1, out val);
				val.set_int (val.get_int () + 1);
        listmodel.set_value (iter, 1, val);

				return false;
      });

			return true;
    });

    var optimizer = new Optimizer (this.images);
    optimizer.optimize (this);

    return main;
  }

  public void updateSize (string path, int size) {
    // Update image with new attributes
    for (var i = 0; i < this.images.length; i++) {
      if (this.images[i].path == path) {
        this.images[i].new_size = (size == 0 || this.images[i].size < size) ? this.images[i].size : size;
      }
    }

    Gtk.TreeIter iter;
    Image image = new Image("", "", "");
    var key = 0;
    for (var i = 0; i < this.images.length; i++) {
      if (this.images[i].path == path) {
        image = this.images[i];
        key = i;
        break;
      }
    }

    Gtk.TreePath tree_path = new Gtk.TreePath.from_string (key.to_string ());
    bool tmp = this.listmodel.get_iter (out iter, tree_path);
    assert (tmp == true);

    this.listmodel.set (iter,
              0, false,
              1, 1,
              2, image.name,
              3, Image.getUnit (image.size),
              4, Image.getUnit (image.new_size),
              5, Image.calcSavings ((float) image.size, (float) image.new_size));
  }

  public void updateTreeView (Image[] images) {
    Gtk.TreeIter iter;

    foreach (var image in images) {
      var duplicate = false;
      for (int i = 0; i < this.images.length; i++) {
        if (this.images[i].path == image.path) {
          duplicate = true;
        }
      }

      if (! duplicate) {
        listmodel.append (out iter);
        listmodel.set (iter,
                      0, true,
                      1, 1,
                      2, image.name,
                      3, Image.getUnit (image.size),
                      4, "",
                      5, "");
      }

      this.images += image;
    }

    var optimizer = new Optimizer (images);
    optimizer.optimize (this);
  }
}
