using Gtk;

public class List {

  private Image[] images;

  public List(Image[] images) {
    this.images = images;
  }

  public Gtk.ScrolledWindow window() {
    //  this.border_width = 10;

    var main = new Gtk.ScrolledWindow(null, null);
    main.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
    //  main.set_spacing(15);
    //  main.set_valign(Gtk.Align.CENTER);
    //  main.set_halign(Gtk.Align.CENTER);

    var view = new Gtk.TreeView ();
    view.get_selection().set_mode(SelectionMode.NONE);

    var listmodel = new Gtk.ListStore (3, typeof (string), typeof (string),  typeof (string));
		view.set_model (listmodel);

		var cell = new Gtk.CellRendererText ();

		cell.set ("weight_set", true);
		cell.set ("weight", 700);

    view.insert_column_with_attributes (-1, "Name", cell, "text", 0);
		view.insert_column_with_attributes (-1, "Path", cell, "text", 1);
		view.insert_column_with_attributes (-1, "Type", cell, "text", 2);

		Gtk.TreeIter iter;
    foreach (Image image in this.images) {
      listmodel.append(out iter);
      listmodel.set(iter,
                    0, image.name,
                    1, image.path,
                    2, image.type);
    }

    main.add(view);

    //  pack_start(main);

    return main;
  }
}
