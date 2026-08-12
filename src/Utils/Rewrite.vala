/**
 * Rewrites one image in place without ever renaming another file over it.
 *
 * Both jpegoptim and optipng replace a file by writing a temporary one next to
 * it and renaming. Under the XDG document portal the app is handed a path inside
 * a per-document FUSE directory, and the grant is bound to that one file: a
 * rename across it fails, and with it the whole optimization. Measured outside
 * the sandbox, the same thing happens whenever the directory is not writable,
 * which is why this class exists rather than a portal specific workaround.
 *
 * So the file the optimizers see is a copy inside the sandbox, and the bytes
 * they produce are written back over the original file descriptor. Nothing here
 * renames anything, which is what the portal path needs.
 *
 * That is not the same as promising the inode survives. Measured on a real
 * sandboxed run, a file picked through the portal came back with a new inode
 * (3932178 became 3933511) while its modification time and contents were exactly
 * as intended. The document portal is a FUSE layer that commits a write by
 * putting the bytes in a temporary file and renaming that over the real one, so
 * the inode changes a level below this code. A file the app can reach without
 * the portal keeps its inode.
 *
 * The practical consequence is that optimizing a file with more than one hard
 * link splits it, and the other links keep the old contents. That was already
 * true before this class existed, because the optimizers renamed as well.
 *
 * The copy also means the optimizers' own --preserve no longer decides what the
 * modification time ends up being, because it is the copy they preserve. This
 * class reads the original time before touching anything and puts it back after,
 * which is how PNG and JPEG both keep their timestamp now.
 */
public class Rewrite {

  /**
   * Path of the image the caller wants rewritten.
   *
   * @var string
   */
  public string original_path { get; private set; }

  /**
   * Path of the copy the optimizer should be pointed at, or null when the copy
   * could not be made.
   *
   * @var string?
   */
  public string? working_path { get; private set; default = null; }

  /**
   * Modification time of the original, so it can be restored afterwards.
   *
   * @var DateTime?
   */
  private DateTime? modified = null;

  /**
   * Take a copy of the image inside the sandbox. Check working_path afterwards:
   * it stays null when there was nothing to copy or nowhere to copy it to, and
   * the caller should then report a failure rather than run the optimizer.
   *
   * @param string path
   */
  public Rewrite (string path) {
    this.original_path = path;

    var original = File.new_for_path (path);

    try {
      // The time has to be read before the copy, because writing the result
      // back later stamps the original with the current time.
      var info = original.query_info (
        FileAttribute.TIME_MODIFIED + "," + FileAttribute.TIME_MODIFIED_USEC,
        FileQueryInfoFlags.NONE
      );
      this.modified = info.get_modification_date_time ();
    } catch (Error e) {
      warning ("Could not read the modification time of \"%s\": %s", path, e.message);
    }

    try {
      // The runtime directory is preferred over /tmp: inside a flatpak it is
      // private to this app and the system clears it, so a copy left behind by
      // a hard kill does not outlive the session.
      var parent = Environment.get_user_runtime_dir () ?? Environment.get_tmp_dir ();
      var directory = Path.build_filename (parent, "image-optimizer");

      if (DirUtils.create_with_parents (directory, 0700) != 0) {
        warning ("Could not create \"%s\"", directory);
        return;
      }

      // The extension is kept because both optimizers decide what to do by
      // looking at the contents, but a recognisable name helps when a copy does
      // survive a crash.
      var name = Path.get_basename (path);
      var candidate = Path.build_filename (directory, "%d-%s".printf (Random.int_range (0, int.MAX), name));

      original.copy (
        File.new_for_path (candidate),
        FileCopyFlags.OVERWRITE | FileCopyFlags.ALL_METADATA,
        null,
        null
      );

      this.working_path = candidate;
    } catch (Error e) {
      warning ("Could not copy \"%s\" for optimizing: %s", path, e.message);
    }
  }

  /**
   * Write the optimized bytes back over the original and restore its
   * modification time. Returns the new size, or 0 when nothing was written.
   *
   * @return int
   */
  public int commit () {
    if (this.working_path == null) {
      return 0;
    }

    uint8[] contents;

    try {
      FileUtils.get_data (this.working_path, out contents);
    } catch (Error e) {
      warning ("Could not read the optimized copy of \"%s\": %s", this.original_path, e.message);
      return 0;
    }

    if (contents.length == 0) {
      warning ("The optimized copy of \"%s\" was empty, leaving the original alone", this.original_path);
      return 0;
    }

    try {
      // open_readwrite, not replace: File.replace writes a new file and renames
      // it over this one, which is exactly what has to be avoided here.
      var stream = File.new_for_path (this.original_path).open_readwrite ();

      stream.seek (0, SeekType.SET);

      size_t written;
      stream.output_stream.write_all (contents, out written);
      stream.output_stream.flush ();

      // The result is smaller than what was there, so the tail of the old file
      // has to go. Without this the file keeps its original length and the
      // leftover bytes corrupt it.
      if (stream.can_truncate ()) {
        stream.truncate (contents.length);
      } else {
        warning ("Cannot truncate \"%s\", leaving it alone", this.original_path);
        stream.close ();

        return 0;
      }

      stream.close ();
    } catch (Error e) {
      warning ("Could not write the result back to \"%s\": %s", this.original_path, e.message);
      return 0;
    }

    this.restore_modification_time ();

    return contents.length;
  }

  /**
   * Remove the copy. Safe to call more than once, and safe to call when there
   * never was a copy.
   *
   * @return void
   */
  public void cleanup () {
    if (this.working_path == null) {
      return;
    }

    if (FileUtils.unlink (this.working_path) != 0 && FileUtils.test (this.working_path, FileTest.EXISTS)) {
      warning ("Could not remove the temporary copy \"%s\"", this.working_path);
    }

    this.working_path = null;
  }

  /**
   * Put the original modification time back, so optimizing a folder does not
   * reorder a photo library sorted by date.
   *
   * @return void
   */
  private void restore_modification_time () {
    if (this.modified == null) {
      return;
    }

    try {
      var info = new FileInfo ();
      info.set_modification_date_time (this.modified);

      File.new_for_path (this.original_path).set_attributes_from_info (info, FileQueryInfoFlags.NONE);
    } catch (Error e) {
      warning ("Could not restore the modification time of \"%s\": %s", this.original_path, e.message);
    }
  }
}
