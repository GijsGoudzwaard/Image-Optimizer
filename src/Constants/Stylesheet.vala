class Stylesheet {
  public const string STYLES = """
    @define-color primary_color #687ddb;

    window {
      border-bottom-left-radius: 3px;
      border-bottom-right-radius: 3px;
      transition: background-color .1s ease-in-out;
    }

    window.on_drag_enter, window.on_drag_enter .tree_view {
      background-color: #E8E8E8;
    }

    window.on_drag_enter .default-decoration {
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

    .default-decoration {
      transition: background-color .1s ease-in-out;
    }

    .list .default-decoration {
      background: @primary_color;
      color: #fff;
    }

    .list .default-decoration image,
    .list .default-decoration label,
    .list .default-decoration button {
      color: #fff;
      text-shadow: none;
      -gtk-icon-shadow: none;
    }

    .list .default-decoration image:backdrop,
    .list .default-decoration label:backdrop,
    .list .default-decoration button:backdrop {
      /* Disable default style for seamless style with headerbar */
      background-image: none;
    }

    .tree_view {
      background-color: #fff;
      color: #000;
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

    .tree_view button:backdrop {
      /* Disable default style for seamless style with headerbar */
      filter: none;
    }

    .tree_view button label {
      color: #fff;
    }

    /* The rounded bottom corners used to sit on .tree_view. The bar is the
       bottom of the window now, so they belong here. */
    .summary_bar {
      background-color: mix(@primary_color, #ffffff, 0.955);
      border-top: 1px solid mix(@primary_color, #ffffff, 0.86);
      border-bottom-left-radius: 3px;
      border-bottom-right-radius: 3px;
    }

    /* The padding sits here and not on .summary_bar, so the progress bar below
       can run from edge to edge. */
    .summary_content {
      padding: 13px 14px;
    }

    .summary_bar spinner {
      color: @primary_color;
    }

    .summary_bar .headline {
      font-size: 13px;
      font-weight: 600;
      color: #2b2b30;
    }

    .summary_bar .sub,
    .summary_bar .caption {
      font-size: 11px;
      color: #74747e;
    }

    .summary_bar .figure {
      font-size: 20px;
      font-weight: 600;
      color: @primary_color;
    }

    /* Green once there is a result, the app's own colour while it is still
       working. Same green as the check mark in the rows. */
    .summary_bar.done .figure {
      color: #2ea45c;
    }

    .summary_progress,
    .summary_progress trough,
    .summary_progress progress {
      min-height: 4px;
      border-radius: 0;
      border: none;
      margin: 0;
      padding: 0;
    }

    .summary_progress trough {
      background-color: mix(@primary_color, #ffffff, 0.8);
    }

    .summary_progress progress {
      background-color: @primary_color;
      background-image: none;
    }
  """;
}
