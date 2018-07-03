class Stylesheet {
    public const string STYLES = """
        @define-color primary_color #687ddb;

        window {
          border-bottom-left-radius: 3px;
          border-bottom-right-radius: 3px;
          transition: background-color .1s ease-in-out;
        }

        window.on_drag_motion, window.on_drag_motion .tree_view {
          background-color: #E8E8E8;
        }

        window.on_drag_motion .toolbar {
          background-color: #E8E8E8;
        }

        .main {
          border: 3px dashed #c2cdda;
          border-radius: 3px;
        }

        .upload_button.add {
          border-radius: 100%;
          padding: 10px 17px;
        }

        .upload_button {
          padding: 6px 10px 8px;
          font-size:11px;
          color: #fff;
          background: @primary_color;
          border: 1px solid darker(@primary_color);
          transition: all 200ms ease-in-out;
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

        .toolbar .titlebutton {
          font-size: 16px;
          color: #fff;
          font-weight: 700;
        }

        .toolbar .titlebutton.add {
          padding: 0;
        }

        .list .toolbar {
          background: @primary_color;
          color: #fff;
        }

        .list .toolbar image, .list .toolbar label, .list .toolbar button {
          color: #fff;
        }

        .tree_view {
          background-color: #fff;
          color: #000;
          border-bottom-left-radius: 3px;
          border-bottom-right-radius: 3px;
        }

        .tree_view row {
          border-bottom: 1px solid #ddd;
        }

        .tree_view button {
          background-color: @primary_color;
          color: #fff;
          border: none;
          border-bottom: 2px solid #E0E0E0;
          padding: 10px;
          outline: none;
          background-image: none;

          border: 1px solid transparent;
          border-color: @primary_color;
          box-shadow: inset 0 0, inset 0 0;
        }

        .tree_view button label {
          color: #fff;
        }
    """;
}
