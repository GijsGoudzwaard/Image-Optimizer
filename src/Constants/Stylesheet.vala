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

    /* The button on the welcome screen. It used to lean on the theme's
       suggested-action, which paints with the system accent colour and drew a red
       outline around it on a red accent. The border here is written out because
       darker() is a GTK3 function: GTK4 drops the whole declaration, which is what
       let the theme's outline through in the first place.

       The padding is even on both sides now. It was 6 above and 8 below, which
       left the label sitting off centre. */
    .upload_button {
      padding: 8px 18px;
      font-size: 13px;
      font-weight: 700;
      color: #fff;
      background-color: @primary_color;
      background-image: none;
      border: 1px solid #5a6fd0;
      border-radius: 4px;
      box-shadow: none;
      outline: none;
      text-shadow: none;
      transition: background-color 150ms ease-in-out;
    }

    .upload_button:hover {
      background-color: #7d8fe2;
    }

    .upload_button:active {
      background-color: #5a6fd0;
    }

    /* The two halves of the button on the welcome screen. The rounded corners
       are split between them so the pair reads as one control: the label keeps
       the left ones, the arrow keeps the right ones, and the seam between them
       is a single line rather than two borders meeting. */
    .linked .upload_button {
      border-top-right-radius: 0;
      border-bottom-right-radius: 0;
      border-right: none;
    }

    .upload_more > button {
      padding: 8px 8px;
      color: #fff;
      background-color: @primary_color;
      background-image: none;
      border: 1px solid #5a6fd0;
      border-left: 1px solid #7d8fe2;
      border-top-left-radius: 0;
      border-bottom-left-radius: 0;
      border-top-right-radius: 4px;
      border-bottom-right-radius: 4px;
      box-shadow: none;
      outline: none;
      transition: background-color 150ms ease-in-out;
    }

    .upload_more > button:hover {
      background-color: #7d8fe2;
    }

    .upload_more > button:active,
    .upload_more > button:checked {
      background-color: #5a6fd0;
    }

    /* What drops out of the arrow. Painted here rather than left to the theme,
       for the same reason everything else in this app is: a popover that is not
       painted comes out as a black rectangle on a plain GTK install. A popover
       is a background node with an arrow and a contents node inside it, and both
       of the latter have to carry the colour or the little triangle stays dark.
    */
    .app_popover > contents,
    .app_popover > arrow {
      background-color: #ffffff;
      border: 1px solid #c9c9d4;
      box-shadow: none;
    }

    .app_popover > contents {
      border-radius: 6px;
      padding: 4px;
    }

    /* A popover hanging off the header bar is a child of it as far as the
       stylesheet is concerned, so the rule that paints every label in that bar
       white paints these too, and a menu of white text on a white sheet is a
       menu with nothing in it. Measured the hard way, on a screenshot of an
       empty popover.

       Three classes deep, and every one of them a class that is already on the
       tree. The rule it has to beat has two, and element names count for less
       than classes do however many of them are written: the first attempt at
       this said ".app_popover > contents modelbutton label", which is one class
       and three names, and lost. Leaning on which rule comes last in the file
       would have worked until someone moved one. */
    .list .default-decoration .add_image popover modelbutton,
    .list .default-decoration .add_image popover modelbutton label {
      color: #2C2C2A;
      text-shadow: none;
    }

    /* Having focus is not the same as being chosen, and this is where that is
       said. GTK hands focus to the first item the moment a menu opens, and a
       theme that paints that with the system accent leaves an item looking
       picked before anything has been pressed: on a red accent, a red ring
       around a menu the pointer had not even reached.

       This one comes first on purpose. GTK also moves focus to whatever the
       pointer is over, so an item under the mouse has both states at once, and
       these rules are worth exactly as much as each other. Written the other way
       round, which is how it was, the focus rule won and there was no hover
       effect at all. */
    .app_popover modelbutton:focus,
    .list .default-decoration .add_image popover modelbutton:focus {
      background-color: transparent;
      background-image: none;
      outline: none;
    }

    /* And these two come after it, because they are the ones that should win.
       The pointer being over something, and focus that arrived from the keyboard
       rather than from the mouse, which is the whole point of :focus-visible. */
    .app_popover modelbutton:hover,
    .app_popover modelbutton:focus-visible,
    .list .default-decoration .add_image popover modelbutton:hover,
    .list .default-decoration .add_image popover modelbutton:focus-visible {
      background-color: #eef0fb;
      background-image: none;
      outline: none;
    }

    .upload_button label {
      color: #fff;
      font-weight: 700;
      text-shadow: none;
    }

    .h1 {
      color: #555a6b;
      font-size: 18px;
      font-weight: 700;
    }

    .h4 {
      font-size: 12px;
      font-weight: 400;
    }

    .default-decoration {
      transition: background-color .1s ease-in-out;
    }

    .list .default-decoration {
      background: @primary_color;
      color: #fff;
    }

    /* 13px, bold, so the window's name reads as the heading of everything under
       it rather than as another line of interface text. */
    .default-decoration .title {
      font-size: 13px;
      font-weight: 700;
    }

    /* 10px above and below a 16px line. 14 on the right, which is what the
       columns and the summary bar keep free, and 6 on the left, where there is a
       button: 14 there left it sitting away from the corner rather than in it,
       and a button carries its own padding on top of whatever the bar has. */
    .list .default-decoration {
      min-height: 36px;
      padding: 0 14px 0 6px;
    }

    /* The plus in the header bar. Styled here rather than left to the theme,
       which paints it with the system accent colour: on a red accent that put a
       red button on a purple bar. Flat with a lighter purple on hover keeps it
       part of the bar it sits in.

       A menu button is a button inside a menubutton node, and only the inner one
       is painted. The outer one carries nothing: no padding, because its padding
       was pushing the whole thing away from the corner on top of what the bar
       already keeps free, and no colour, because it had kept the colours from
       when this was a plain button and was drawing a second, larger rectangle
       behind the real one. With the menu open and the pointer over it, that was
       a light purple box around a dark purple box.

       :checked as well as :active below, because it stays pressed for as long as
       its menu is open. */
    .list .default-decoration .add_image {
      background-color: transparent;
      background-image: none;
      border: none;
      box-shadow: none;
      padding: 0;
      margin: 0;
      color: #fff;
    }
    .list .default-decoration .add_image > button {
      background-color: transparent;
      background-image: none;
      border: none;
      box-shadow: none;
      color: #fff;
      border-radius: 4px;
      padding: 4px 6px;
    }

    .list .default-decoration .add_image > button:hover {
      background-color: #7d8fe2;
    }

    .list .default-decoration .add_image > button:active,
    .list .default-decoration .add_image > button:checked {
      background-color: #5a6fd0;
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

    /* Nothing in this list can be picked or opened, so it should not light up
       under the pointer either. The model is a NoSelection already, but a theme
       still paints hover and pressed states on the row. */
    .tree_view row:hover,
    .tree_view row:active,
    .tree_view row:selected,
    .tree_view row:focus,
    .tree_view row:focus-visible,
    .tree_view cell:hover,
    .tree_view cell:active,
    .tree_view cell:selected {
      background-color: transparent;
      background-image: none;
      box-shadow: none;
      outline: none;
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

    /* Whole pixels, not the mockup's 12.5. A fractional size lands the glyphs
       between the pixel grid, and every line of text in the window came out
       softer for it.

       The scale is one step up from the mockup's, which put everything a point
       smaller than a desktop normally uses and made the smaller lines hard to
       read. Weights in here are 400 or 700 and nothing between. A UI font that ships
       only those two has its 500 and 600 synthesised by smearing the regular cut,
       which is exactly the soft, muddy look this is meant to avoid. */
    .tree_view .cell_text {
      font-size: 14px;
      text-shadow: none;
    }

    .tree_view .cell_note {
      font-size: 12px;
      color: #74747e;
    }

    /* A word in a column of numbers is not a number, so it steps back a shade. */
    .tree_view .cell_text.muted {
      color: #5F5E5A;
    }

    /* The hairline under the headings, and the background that puts it right on
       the edge between the headings and the first row. Without the background the
       header node showed a white sliver under the buttons and the line landed
       below that, which read as an extra rule above the first row.

       Written out rather than as 20% white over the header colour, because
       alpha() in this position is dropped without a word. */
    .tree_view header {
      background-color: @primary_color;
      border-bottom: 1px solid #8697e2;
    }

    /* The column headings. This is a button node, which is why the rule is
       written for one: Gtk.ColumnView builds its headings out of buttons. */
    .tree_view button {
      background-color: @primary_color;
      background-image: none;
      color: #fff;
      border: none;
      border-radius: 0;
      padding: 8px 0;
      font-size: 13px;
      font-weight: 700;
      outline: none;
      box-shadow: none;
    }

    .tree_view button:backdrop {
      /* Disable default style for seamless style with headerbar */
      filter: none;
    }

    /* The size and weight belong on the label as well as on the button, because
       that is where the theme sets them and the more specific rule wins. Pure
       white and heavier than the mockup asks for: at 12px on this purple the
       lighter weight never reached full coverage on any pixel, which is what made
       the headings hard to read. */
    .tree_view header button label {
      color: #ffffff;
      font-size: 13px;
      font-weight: 700;
      opacity: 1;
      text-shadow: none;
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

    /* No text shadow anywhere in here. The elementary stylesheet puts one on
       several kinds of label, and at these sizes it reads as smudged text rather
       than as depth. */
    .summary_bar label {
      text-shadow: none;
    }

    .summary_bar .headline {
      font-size: 15px;
      font-weight: 700;
      color: #2C2C2A;
    }

    /* Darker than the mockup's grey. On this background the lighter one was hard
       to read, and these two lines carry the numbers that explain the
       ones above them. */
    .summary_bar .sub,
    .summary_bar .caption {
      font-size: 13px;
      font-weight: 400;
      color: #4a4a52;
    }

    /* Deeper than the header bar's purple while it is working, and green once
       there is a result. Both are darker than the icon they sit next to, because
       they carry more weight at this size. */
    .summary_bar .figure {
      font-size: 22px;
      font-weight: 700;
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
