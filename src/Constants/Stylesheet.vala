class Stylesheet {
  public const string STYLES = """
    @define-color primary_color #687ddb;

    window {
      border-bottom-left-radius: 6px;
      border-bottom-right-radius: 6px;
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

    /* 13px at medium weight, so the title carries the same weight as the rest of
       the window instead of the theme's heavier default. */
    .default-decoration .title {
      font-size: 13px;
      font-weight: 500;
    }

    /* 10px above and below a 16px line, and the same 14 on the sides that the
       columns and the summary bar keep free. Themes have their own idea of how
       tall a compact header bar is, which is what this replaces. */
    .list .default-decoration {
      min-height: 36px;
      padding: 0 14px;
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

    /* The row and cell nodes carry the theme's own padding, which adds to the
       margins the columns set: measured, it pushed every column 6px inward and
       made each row 5px taller than it should be. */
    .tree_view row,
    .tree_view cell {
      padding: 0;
      margin: 0;
      min-height: 0;
    }

    .tree_view .cell_text {
      font-size: 12.5px;
    }

    /* A word in a column of numbers is not a number, so it steps back a shade. */
    .tree_view .cell_text.muted {
      color: #5F5E5A;
    }

    /* The hairline under the headings. Written out rather than as 20% white over
       the header colour, because the mix has to survive whatever the theme
       decides to do with the node underneath. */
    .tree_view header {
      border-bottom: 1px solid #8697e2;
    }

    /* The column headings. This is a button node, which is why the rule is
       written for one: Gtk.ColumnView builds its headings out of buttons. */
    .tree_view button {
      background-color: @primary_color;
      background-image: none;
      color: #fff;
      border: none;
      border-bottom: 1px solid alpha(#ffffff, 0.2);
      border-radius: 0;
      padding: 8px 0;
      font-size: 12px;
      font-weight: 400;
      outline: none;
      box-shadow: none;
    }

    .tree_view button:backdrop {
      /* Disable default style for seamless style with headerbar */
      filter: none;
    }

    /* The weight and size belong on the label as well as the button: the theme
       sets them on the label, and there the label wins. */
    .tree_view button label {
      color: #fff;
      font-size: 12px;
      font-weight: 400;
    }

    /* The rounded bottom corners used to sit on .tree_view. The bar is the
       bottom of the window now, so they belong here. */
    .summary_bar {
      background-color: #f4f5fb;
      border-top: 1px solid #d5d9ef;
      border-bottom-left-radius: 6px;
      border-bottom-right-radius: 6px;
    }

    /* The padding sits here and not on .summary_bar, so the progress bar below
       can run from edge to edge. */
    .summary_content {
      padding: 14px;
    }

    .summary_bar spinner {
      color: #534AB7;
    }

    .summary_bar .headline {
      font-size: 13.5px;
      font-weight: 500;
      color: #2C2C2A;
    }

    .summary_bar .sub,
    .summary_bar .caption {
      font-size: 11.5px;
      color: #5F5E5A;
    }

    /* Deeper than the header bar's purple while it is working, and green once
       there is a result. Both are darker than the icon they sit next to, because
       they carry more weight at this size. */
    .summary_bar .figure {
      font-size: 20px;
      font-weight: 500;
      color: #534AB7;
    }

    .summary_bar.done .figure {
      color: #0F6E56;
    }

    .summary_progress,
    .summary_progress trough,
    .summary_progress progress {
      min-height: 3px;
      border: none;
      margin: 0;
      padding: 0;
      border-radius: 0;
    }

    .summary_progress trough {
      background-color: #e4e7f5;
      border-bottom-left-radius: 6px;
      border-bottom-right-radius: 6px;
    }

    .summary_progress progress {
      background-color: @primary_color;
      background-image: none;
      border-bottom-left-radius: 6px;
    }
  """;
}
