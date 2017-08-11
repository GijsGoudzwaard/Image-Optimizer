using Gtk;

public class List {

  private Image[] images;

  public List (Image[] images) {
    this.images = images;
  }

  public Gtk.ScrolledWindow window () {
    var main = new Gtk.ScrolledWindow (null, null);
    main.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);

    var listmodel = new Gtk.ListStore (6, typeof (bool), typeof (int), typeof (string), typeof (string), typeof (string), typeof (string));

    Gtk.TreeIter iter;
    var test = this.images;
    foreach (var image in test) {
      listmodel.append (out iter);
      listmodel.set (iter,
                    0, true,
                    1, 1,
                    2, image.name,
                    3, image.size.to_string (),
                    4, image.new_size.to_string (),
                    5, image.savings.to_string () + "%");
    }

    var view = new Gtk.TreeView.with_model (listmodel);
    view.get_style_context ().add_class ("tree_view");
    main.add (view);

    var cell = new Gtk.CellRendererText ();
    var spinner = new Gtk.CellRendererSpinner ();

    Gtk.TreeViewColumn column = new Gtk.TreeViewColumn ();
		column.set_title ("Status");
		column.pack_start (spinner, false);
		column.add_attribute (spinner, "active", 0);
		column.add_attribute (spinner, "pulse", 1);
		view.append_column (column);

    view.insert_column_with_attributes (2, "File", cell, "text", 2);
		view.insert_column_with_attributes (3, "Size", cell, "text", 3);
		view.insert_column_with_attributes (4, "New size", cell, "text", 4);
    view.insert_column_with_attributes (5, "Savings", cell, "text", 5);

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
    optimizer.optimize ();

    return main;
  }
}
