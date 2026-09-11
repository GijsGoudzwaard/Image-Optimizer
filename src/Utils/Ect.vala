/**
 * Runs the Efficient Compression Tool over the images in a batch.
 *
 * This replaces the two classes that used to be here, one per format, because
 * one tool now does both: ECT picks PNG or JPEG by the extension of the file it
 * is handed. What is left per format is one flag each and the decision about
 * metadata, which is why both formats can share a queue and a worker pool.
 *
 * Measured against the pair it replaces, over ten images of which seven were
 * real: PNG went from 10.55% to 17.59% and JPEG from 3.32% to 5.85%, and the
 * PNG side is faster than it was rather than slower. Every one of the 179 runs
 * behind those numbers came back pixel identical to its input, which is the one
 * thing this app promises.
 */
public class Ect {

  /**
   * The levels every file is run through, the smallest result winning.
   *
   * Two passes and not one, because a level is not a promise. On two of the test
   * images ECT answers levels 3 to 8 with "encoding error 83: memory allocation
   * failed" and leaves the file exactly as it found it, measured on a machine
   * with seven gigabytes free, so this is something inside the tool and not the
   * machine it runs on. On the gradient that is every level above 2, which
   * leaves level 1 as the only pass that improves it at all; on the file with a
   * colour profile it is level 3 alone, with 2 and 4 both taking 62% off. The
   * tool's own README shows a milder version of the same on its gzip benchmark,
   * where -6 comes out larger than -5.
   *
   * So the level is not trusted to mean "better". The cheap pass and the good
   * pass both run and the smaller result is kept, which is why compress_one
   * works on candidates rather than on one file. Level 1 is nearly free, 0.19
   * seconds across seven files, so the pair costs almost exactly what the good
   * pass costs alone. Measured over the same seven, the pair beats either level
   * on its own: 17.59% against 17.52% for level 5 and 11.52% for level 1.
   *
   * Anything above 5 is deliberately not here: 9 gains 0.25 of a percentage
   * point over 5 for ten times the time, and the flag that does pay off at the
   * top, --allfilters, costs sixty times as much. Those belong behind a setting,
   * not in the path every file takes.
   *
   * @var int[]
   */
  private const int[] LEVELS = { 1, 5 };

  /**
   * Images in queue for optimizing, whatever their format.
   *
   * @var string[]
   */
  private string[] images;

  /**
   * Used to update the treeview when done compressing.
   *
   * @var List
   */
  private List list;

  /**
   * Index of the next image to pick up. Workers bump it atomically, which is
   * all the coordination they need.
   *
   * @var int
   */
  private int next_image = 0;

  /**
   * Create a new instance.
   *
   * @param List list
   */
  public Ect (List list) {
    this.list = list;
  }

  /**
   * Add an image to the current object.
   *
   * @return void
   */
  public void add_image (string image) {
    this.images += image;
  }

  /**
   * Compress the images, one worker per core.
   *
   * @return void
   */
  public void compress (int max_workers) throws Error {
    var workers = int.min (max_workers, this.images.length);

    for (var i = 0; i < workers; i++) {
      ThreadFunc<void*> run = () => {
        while (true) {
          var index = AtomicInt.add (ref this.next_image, 1);

          if (index >= this.images.length) {
            break;
          }

          this.compress_one (this.images[index]);
        }

        return null;
      };

      new Thread<void*>.try ("ect", (owned) run);
    }
  }

  /**
   * Optimize a single image and hand the result to the list.
   *
   * The tool never touches the file the user picked. It is pointed at copies
   * inside the sandbox, one per level, and only the best of those is written
   * back over the original. See Rewrite for why that write back is a write and
   * not a rename.
   *
   * @param  string image
   * @return void
   */
  private void compress_one (string image) {
    var rewrite = new Rewrite (image);

    if (rewrite.working_path == null) {
      this.list.update_result (image, Status.FAILED, 0, rewrite.failure);

      return;
    }

    // The size to beat. Everything below compares against the copy rather than
    // against the tool's own report: ECT prints "Saved 4.40KB out of 15.90KB",
    // in kilobytes with decimals, which is a number to read and not a number to
    // compute with.
    var before = Ect.size_of (rewrite.working_path);
    var winner = "";
    var winning_size = before;
    string? trouble = null;
    // What the tool said, kept back for the log. A level that fails while the
    // other one succeeds is not something the user needs to hear about, so the
    // warning waits until it is known whether the file failed.
    string? trouble_output = null;
    // How many levels ran to the end without complaining, whatever they found.
    // A level that finishes and reports nothing gained has answered the question:
    // this file cannot be made smaller that way. Another level falling over does
    // not turn that answer into a broken file, and the row should not say it did.
    var clean = 0;

    foreach (var level in Ect.LEVELS) {
      var candidate = Ect.candidate_for (rewrite.working_path, level);

      if (! Ect.copy (rewrite.working_path, candidate)) {
        // Without this the row would say the file was already as small as it
        // gets, which is what a batch on a full disk would have reported for
        // every file in it.
        if (trouble == null) {
          trouble = _("There was nowhere to put a working copy of this file");
          trouble_output = "could not make a candidate copy";
        }

        continue;
      }

      string output;
      int status;

      try {
        status = this.run (candidate, level, out output);
      } catch (Error e) {
        if (trouble == null) {
          trouble = _("The optimizer could not be started");
          trouble_output = "Failed to run ect: %s".printf (e.message);
        }

        FileUtils.unlink (candidate);

        continue;
      }

      // Both halves matter. A truncated JPEG comes back with status 0 and
      // "Premature end of JPEG file", and an extension ECT does not know gets
      // status 0 and "No compatible files found", so the status on its own would
      // report those two as files that were simply already small enough.
      if (status != 0 || Ect.reports_trouble (output)) {
        if (trouble == null) {
          trouble = this.failure_reason (output);
          trouble_output = output;
        }

        FileUtils.unlink (candidate);

        continue;
      }

      clean++;

      var size = Ect.size_of (candidate);

      if (size > 0 && size < winning_size) {
        if (winner != "") {
          FileUtils.unlink (winner);
        }

        winner = candidate;
        winning_size = size;

        continue;
      }

      FileUtils.unlink (candidate);
    }

    var new_size = 0;
    var status_result = Status.ALREADY_OPTIMAL;
    string? reason = null;

    if (winner != "") {
      // Inside the sandbox directory, so this rename crosses nothing that could
      // refuse it. It is the write back in Rewrite that may not rename.
      if (FileUtils.rename (winner, rewrite.working_path) == 0) {
        new_size = rewrite.commit ();
        status_result = (new_size > 0) ? Status.OPTIMIZED : Status.FAILED;
        reason = rewrite.failure;
      } else {
        warning ("Could not put the best result in place for \"%s\"", image);
        status_result = Status.FAILED;
        reason = _("The optimizer could not process this file");
        FileUtils.unlink (winner);
      }
    } else if (trouble != null && clean == 0) {
      // Nothing was written and no level got far enough to tell us anything, so
      // this really is a failure. Only now is it worth a line in the log: a level
      // falling over while another one answers is the design working.
      warning ("ect could not deal with \"%s\": %s", image, trouble_output);
      status_result = Status.FAILED;
      reason = trouble;
    }

    // Always, so a failure or a quit halfway through does not leave copies
    // behind.
    rewrite.cleanup ();

    // The status is what the row and the summary bar go by. A size only means
    // anything alongside OPTIMIZED, and the list checks that it really is
    // smaller before it counts as a saving.
    this.list.update_result (image, status_result, new_size, reason);
  }

  /**
   * The name of the copy one level gets to work on.
   *
   * The level goes in front of the extension and not behind it. ECT decides what
   * a file is by its name, so a candidate called "photo.png-1" has an extension
   * of "png-1" and is answered with "No compatible files found", which reads as
   * a file that was already small enough. Measured the hard way.
   *
   * @param  string path
   * @param  int level
   * @return string
   */
  private static string candidate_for (string path, int level) {
    var dot = path.last_index_of_char ('.');

    if (dot > 0) {
      return "%s-%d%s".printf (path.substring (0, dot), level, path.substring (dot));
    }

    // Rewrite always keeps the extension, so this is only here so that a path
    // without one cannot silently produce a candidate that overwrites another.
    return "%s-%d".printf (path, level);
  }

  /**
   * Run the tool over one candidate and hand back everything it said.
   *
   * @param  string path
   * @param  int level
   * @param  string output  stdout and stderr together, which is where ECT mixes
   *                        its progress and its complaints
   * @return int            the exit status
   */
  private int run (string path, int level, out string output) throws Error {
    string standard_output;
    string standard_error;
    int status;

    Process.spawn_sync (
      null,
      this.arguments (path, level),
      null,
      SpawnFlags.SEARCH_PATH,
      null,
      out standard_output,
      out standard_error,
      out status
    );

    output = standard_output + standard_error;

    return status;
  }

  /**
   * The command line for one candidate at one level.
   *
   * @param  string path
   * @param  int level
   * @return string[]
   */
  private string[] arguments (string path, int level) {
    string[] argv = {
      "ect",
      "-%d".printf (level),
      // Measured to cost nothing at all, on either format, so there is no
      // reason for the app to ever run without it.
      "--strict"
    };

    if (Ect.is_png (path)) {
      // "-strip" is all or nothing: there is no way to keep one chunk and drop
      // the rest. So it is only added to a file that says nothing about how it
      // should be displayed. Handed to a file that does, it throws the colour
      // profile away and the image is read differently from then on. Measured,
      // that flag is worth 340 bytes on a file with a full profile, which is not
      // a trade this app is willing to make.
      if (! Ect.carries_display_information (path)) {
        argv += "-strip";
      }
    } else {
      // Not optional: without it ECT leaves a JPEG exactly as it found it.
      // Measured, all three test photos came back byte for byte identical
      // without this flag and 5.85% smaller with it.
      //
      // Reordering the scans touches no coefficient, so this is lossless. It
      // does mean the result is a progressive JPEG, which a handful of older
      // programs cannot read. That belongs in a setting, and until there is one
      // the app keeps the saving, which is what it did before as well.
      argv += "-progressive";
    }

    // No "-strip" on this side and no "-keep" anywhere. The Exif block holds the
    // orientation flag, and a phone stores a portrait photo as a landscape image
    // plus that flag, so dropping it turns the photo on its side without
    // changing a pixel. Measured: the block survives untouched here, orientation
    // included. The modification time is Rewrite's job, which reads it before
    // the copy is made and puts it back after the write.
    argv += path;

    return argv;
  }

  /**
   * Whether anything in the output says this did not go well.
   *
   * ECT does not always use its exit status for that. A truncated JPEG and an
   * extension it does not recognise both leave it at 0.
   *
   * @param  string output
   * @return bool
   */
  private static bool reports_trouble (string output) {
    return "error" in output.down ()
      || "Premature end" in output
      || "No compatible files found" in output;
  }

  /**
   * Put what the tool said into words for the row.
   *
   * The log keeps its output either way. This only has to answer the question
   * someone looking at a red icon actually has, which is whether the file is the
   * problem or the app is.
   *
   * @param  string output
   * @return string
   */
  private string failure_reason (string output) {
    if ("Not a PNG file" in output) {
      return _("This is not a PNG file, whatever its name says");
    }

    if ("Not a JPEG" in output) {
      return _("This is not a JPEG file, whatever its name says");
    }

    // What ECT says about a file that stops halfway through, in either format.
    if ("unexpected end of file" in output || "Premature end" in output) {
      return _("This file stops halfway through, so it may be damaged");
    }

    if ("Permission denied" in output) {
      return _("Could not write to this file, it may be read only");
    }

    return _("The optimizer could not process this file");
  }

  /**
   * Whether this path names a PNG, which is the only question the flags depend
   * on. Answered from the name and not from the contents on purpose: that is how
   * ECT itself decides, so this stays in step with what the tool will do.
   *
   * @param  string path
   * @return bool
   */
  private static bool is_png (string path) {
    return Image.get_file_type (Path.get_basename (path)).down () == "png";
  }

  /**
   * Size of a file, or 0 when it cannot be read.
   *
   * @param  string path
   * @return int
   */
  private static int size_of (string path) {
    try {
      var info = File.new_for_path (path).query_info (
        FileAttribute.STANDARD_SIZE,
        FileQueryInfoFlags.NONE
      );

      return (int) info.get_size ();
    } catch (Error e) {
      warning ("Could not read the size of \"%s\": %s", path, e.message);

      return 0;
    }
  }

  /**
   * Copy one file over another inside the sandbox directory.
   *
   * TARGET_DEFAULT_PERMS matters more than it looks. Without it the copy carries
   * the mode of the file the user picked, and the optimizer rewrites the file it
   * is given rather than writing a new one beside it, so a read-only image gave
   * a read-only candidate and "can't open ... for writing". The tools that came
   * before wrote and renamed, which needs no permission on the file itself,
   * which is why this never came up until now.
   *
   * These candidates are throwaway files in the app's own runtime directory, so
   * default permissions are the right ones for them. What the user's file ends
   * up with is decided by Rewrite, which writes into the file that is already
   * there and never creates one.
   *
   * @param  string from
   * @param  string to
   * @return bool
   */
  private static bool copy (string from, string to) {
    try {
      File.new_for_path (from).copy (
        File.new_for_path (to),
        FileCopyFlags.OVERWRITE | FileCopyFlags.TARGET_DEFAULT_PERMS,
        null,
        null
      );

      return true;
    } catch (Error e) {
      warning ("Could not make a candidate copy of \"%s\": %s", from, e.message);

      return false;
    }
  }

  /**
   * Whether this PNG says anything about how it should be displayed.
   *
   * Five chunks do, and "-strip" removes every one of them. Four are about
   * colour: iCCP is a full profile, gAMA the gamma, sRGB the rendering intent
   * and cHRM the primaries, and without them a viewer falls back on its own
   * assumptions. The fifth is eXIf, which PNG has carried since 1.5 and which
   * holds the same orientation flag as a JPEG: measured, a png with eXIf saying
   * Rotate 90 came out of a strip without it, so a png could be turned on its
   * side the same way a photo was.
   *
   * A PNG is a signature followed by chunks of [length][type][data][crc], and
   * the spec puts all of these before the first IDAT, so the walk can stop as
   * soon as the image data starts. Nothing is written here, only read, which is
   * why this is a safe way to decide about a flag that would otherwise destroy
   * them.
   *
   * Returns false when the file cannot be read or does not look like a PNG. That
   * is the same answer as "nothing to lose", and it is the right one: the tool
   * is about to refuse the file anyway, and the row will say so.
   *
   * @param  string path
   * @return bool
   */
  private static bool carries_display_information (string path) {
    try {
      var stream = new DataInputStream (File.new_for_path (path).read ());
      // PNG is big endian, which is also what DataInputStream defaults to.
      var header = new uint8[8];
      size_t read;

      if (! stream.read_all (header, out read) || read != 8) {
        return false;
      }

      // What ends this loop is the end of the file: every turn takes at least the
      // eight bytes of a length and a type, and a read that comes up short
      // returns below. The count is only a backstop, and it is high because the
      // spec lets any number of chunks sit in front of the profile. Measured with
      // a file carrying two hundred tEXt chunks before its iCCP, a cap of sixty
      // threw the profile away, which is the very bug this method exists to stop.
      for (var i = 0; i < 10000; i++) {
        var length = stream.read_uint32 ();
        var type = new uint8[4];

        if (! stream.read_all (type, out read) || read != 4) {
          return false;
        }

        char[] letters = { (char) type[0], (char) type[1], (char) type[2], (char) type[3], '\0' };
        var name = (string) letters;

        if (
          name == "iCCP" ||   // the whole colour profile
          name == "gAMA" ||   // the gamma
          name == "sRGB" ||   // the rendering intent
          name == "cHRM" ||   // the primaries
          name == "eXIf"      // the same orientation flag a photo carries
        ) {
          return true;
        }

        // Once the image data starts there is nothing of the sort coming.
        if (name == "IDAT") {
          return false;
        }

        // The data plus its four byte checksum. Cast first: a corrupt length of
        // 0xFFFFFFFF would wrap round if the four were added as a uint32.
        var skip = (int64) length + 4;

        if (stream.skip ((size_t) skip) != skip) {
          return false;
        }
      }
    } catch (Error e) {
      // Not worth a warning: the tool gets the same file a moment later and its
      // own complaint is the one that reaches the row.
      return false;
    }

    return false;
  }
}
