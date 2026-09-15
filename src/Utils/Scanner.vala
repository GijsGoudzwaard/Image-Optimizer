/**
 * Walks the folders someone handed the app and collects the images in them.
 *
 * This exists because a folder is not a file. Picking twelve files is a list the
 * app already has; picking a folder is a question it has to go and answer, and
 * on a folder of any size that is not something to do on the main loop. So the
 * walk runs on a thread of its own and the answers come back as signals emitted
 * from Idle, which is the same way the optimizers report.
 *
 * Three rules decide what comes back, and each of them is a decision rather than
 * an implementation detail:
 *
 *   Subfolders are included. A folder of photos usually has more folders in it,
 *   and the document portal hands over the whole subtree: measured inside the
 *   sandbox, a file in a subfolder of a chosen folder opens for writing.
 *
 *   Anything whose name starts with a dot is skipped, folders included. A home
 *   directory is full of caches and version control that are full of PNGs that
 *   nobody meant to optimize.
 *
 *   Symbolic links are not followed. A link that points at its own parent turns
 *   the walk into a loop, and one that points outside the chosen folder is
 *   access the app was never granted.
 */
public class Scanner : GLib.Object {

  /**
   * How many images the walk has found so far, while it is still going.
   */
  public signal void progress (uint images);

  /**
   * What the walk came back with. The others are the files that were passed
   * over, and the folders are how many were looked in.
   */
  public signal void finished (Image[] images, uint others, uint folders);

  /**
   * Everything found so far. Only the walking thread touches it until it is
   * handed over, and the signal that hands it over runs on the main loop.
   *
   * @var Image[]
   */
  private Image[] images = {};

  /**
   * Files that are not images, counted rather than listed.
   *
   * @var uint
   */
  private uint others = 0;

  /**
   * How many folders were looked in, the chosen ones included.
   *
   * @var uint
   */
  private uint folders = 0;

  /**
   * Walk these folders and report what is in them.
   *
   * @param  File[] roots
   * @return void
   */
  public void scan (File[] roots) {
    // Owned copy, because the thread outlives this call.
    var to_walk = roots;

    ThreadFunc<void*> run = () => {
      foreach (var root in to_walk) {
        this.folders++;
        this.walk (root, root);
      }

      Idle.add (() => {
        this.finished (this.images, this.others, this.folders);

        return Source.REMOVE;
      });

      return null;
    };

    try {
      new Thread<void*>.try ("scan", (owned) run);
    } catch (Error e) {
      warning ("Could not start the folder scan: %s", e.message);
      this.finished ({}, 0, 0);
    }
  }

  /**
   * One folder, and then the folders under it.
   *
   * @param  File root    the folder that was picked, which names are relative to
   * @param  File folder  the folder being walked right now
   * @return void
   */
  private void walk (File root, File folder) {
    FileEnumerator children;

    try {
      children = folder.enumerate_children (
        FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE,
        // This flag is what keeps a link to a parent folder from turning the
        // walk into a loop: a symlink is reported as a link and skipped below,
        // rather than as the thing it points at.
        FileQueryInfoFlags.NOFOLLOW_SYMLINKS
      );
    } catch (Error e) {
      // A folder that cannot be opened is not worth stopping the whole walk
      // for. It is usually a permission that was never granted in the first
      // place, and the count at the end will be short by what was in it.
      warning ("Could not look inside \"%s\": %s", folder.get_path (), e.message);

      return;
    }

    File[] deeper = {};
    var found_before = this.images.length;

    while (true) {
      FileInfo child;

      try {
        child = children.next_file ();
      } catch (Error e) {
        warning ("Stopped reading \"%s\": %s", folder.get_path (), e.message);

        break;
      }

      if (child == null) {
        break;
      }

      var name = child.get_name ();

      // Hidden files and hidden folders alike.
      if (name.has_prefix (".")) {
        continue;
      }

      var type = child.get_file_type ();

      if (type == FileType.SYMBOLIC_LINK) {
        continue;
      }

      var child_file = folder.get_child (name);

      if (type == FileType.DIRECTORY) {
        deeper += child_file;

        continue;
      }

      if (type != FileType.REGULAR) {
        continue;
      }

      var path = child_file.get_path ();

      if (path == null) {
        continue;
      }

      // Built rather than guessed at, so that what counts as an image here is
      // the same answer the rest of the app gives. The name it is built with is
      // its path under the folder that was picked, so that two files called
      // photo.jpg in different subfolders read as two different rows.
      var image = new Image (
        path,
        this.display_name (root, child_file),
        Image.get_file_type (name).down ()
      );

      if (! image.supported) {
        // Counted, not listed. A file the app was handed by name gets a row
        // saying why nothing happened to it, because that is what was asked
        // about. A file the app found by looking inside a folder was not asked
        // about, and a folder of five hundred documents would otherwise bury
        // twenty images under four hundred and eighty rows.
        this.others++;

        continue;
      }

      this.images += image;
    }

    if (this.images.length != found_before) {
      var so_far = this.images.length;

      Idle.add (() => {
        this.progress (so_far);

        return Source.REMOVE;
      });
    }

    foreach (var child_folder in deeper) {
      this.folders++;
      this.walk (root, child_folder);
    }
  }

  /**
   * What to call a file that was found rather than picked: its path under the
   * folder that was chosen, or its plain name when it sits directly in it.
   *
   * @param  File root
   * @param  File file
   * @return string
   */
  private string display_name (File root, File file) {
    var relative = root.get_relative_path (file);

    return (relative != null) ? relative : file.get_basename ();
  }
}
