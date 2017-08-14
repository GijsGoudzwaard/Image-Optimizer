class Stylesheet {
    public const string STYLES = """
        GtkWindow {
          border-bottom-left-radius: 3px;
          border-bottom-right-radius: 3px;
          transition: background-color .1s ease-in-out;
        }

        GtkWindow.on_drag_motion {
          background-color: #E8E8E8;
        }

        GtkWindow.on_drag_motion .toolbar {
          background-color: #E8E8E8;
        }

        .main {
          border: 3px dashed #c2cdda;
          border-radius: 3px;
        }

        .upload_button {
          background-color: #687ddb;
          border-radius: 3px;
          padding: 8px 13px 10px;
          border: none;
          color: #fff;
          font-weight: bold;
          font-size: 12px;
          box-shadow: 0px 0px 1px 1px rgba (0, 0, 0, 0);
          transition: background-color .1s ease-in-out;
        }

        .upload_button:hover {
          background-color: #898AE4;
        }

        .h1 {
          color: #555a6b;
          font-size: 18px;
          font-weight: 700;
        }

        .h4 {
          font-size: 11px;
          font-weight: 400;
        }

        .toolbar {
          background: #F5F5F5;
          border-bottom-color: #F5F5F5;
          box-shadow: inset 0px 1px 1px -2px white;
          transition: background-color .1s ease-in-out;
          border: none;
          outline: none;
        }

        .list .toolbar {
          background: #687ddb;
          color: #fff;
        }

        .list .toolbar GtkImage, .list .toolbar GtkLabel {
          color: #fff;
        }

        .tree_view {
          background-color: #fff;
          color: #000;
          border-bottom-left-radius: 3px;
          border-bottom-right-radius: 3px;
        }

        .tree_view GtkButton {
          background-color: #687ddb;
          color: #fff;
          border: none;
          border-bottom: 2px solid #E0E0E0;
          padding: 10px;
          outline: none;
          background-image: none;

          border: 1px solid transparent;
          border-color: #687ddb;
          box-shadow: inset 0 0, inset 0 0;
        }

        .tree_view GtkButton GtkLabel {
          color: #fff;
        }
    """;
}