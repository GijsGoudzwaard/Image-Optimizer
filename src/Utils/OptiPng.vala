public class OptiPng {

  /**
   * Images in queue for optimizing.
   *
   * @var string[]
   */
  private string[] images;

  /**
   * Optipng arguments.
   *
   * @var string[]
   */
  private string[] args = {
    // -o3 stays. Measured on a mixed set, -o4 and -o5 gain nothing over it and
    // -o6 only pays off on smooth gradients while costing four to ten times the
    // time: 104 seconds for a single 3000x2000 image against 15 for -o3.
    "-o3",
    "-preserve"
  };

  /**
   * What is added for a file that says nothing about its own colours.
   *
   * "-strip all" is what it says: optipng has no way to keep one chunk and drop
   * the rest, so passing it to a file that carries colour information throws
   * that information away and the image is read differently from then on.
   * Measured, keeping it costs 358 bytes on a file with a full profile and 110
   * on one with gAMA, sRGB and cHRM.
   *
   * So the flag is added per file, and only when there is nothing to lose.
   * Screenshots and exports, which is nearly everything this app sees, still get
   * the full saving.
   *
   * @var string[]
   */
  private string[] strip_args = { "-strip", "all" };

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
  public OptiPng (List list) {
    this.list = list;
  }

  /**
   * Add images to the current object.
   *
   * @return void
   */
  public void add_image (string image) {
    this.images += image;
  }

  /**
   * Compress the images using optipng.
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

      new Thread<void*>.try ("optipng", (owned) run);
    }
  }

  /**
   * Compress a single image and hand its new size to the list.
   *
   * @param  string image
   * @return void
   */
  private void compress_one (string image) {
    // The optimizer runs on a copy inside the sandbox, never on the file the
    // user picked. See Rewrite for why.
    var rewrite = new Rewrite (image);

    if (rewrite.working_path == null) {
      this.list.update_result (image, Status.FAILED, 0, rewrite.failure);

      return;
    }

    string[] argv = { "optipng" };

    foreach (var arg in this.args) {
      argv += arg;
    }

    if (! OptiPng.carries_colour_information (rewrite.working_path)) {
      foreach (var arg in this.strip_args) {
        argv += arg;
      }
    }

    argv += rewrite.working_path;

    var new_size = 0;
    var status_result = Status.FAILED;
    string? reason = null;

    try {
      string standard_output;
      string standard_error;
      int status;

      Process.spawn_sync (
        null,
        argv,
        null,
        SpawnFlags.SEARCH_PATH,
        null,
        out standard_output,
        out standard_error,
        out status
      );

      // Same reasoning as in JpegOptim: only the exit status says whether the
      // result reached the disk. optipng fails with "Can't back up the input
      // file" when it cannot write next to the original, and without this check
      // that turned into a reported saving on an untouched file.
      if (status != 0) {
        warning (
          "optipng exited with status %d for \"%s\": %s",
          status,
          image,
          standard_error
        );
        reason = this.failure_reason (standard_error);
      } else if (standard_error.contains ("is already optimized")) {
        status_result = Status.ALREADY_OPTIMAL;
      } else if (this.get_new_size (standard_error) > 0) {
        // optipng reports on stderr, stdout stays empty. Its number describes
        // the copy, so it only decides whether there is anything to write back;
        // the size handed to the list is what was actually written.
        new_size = rewrite.commit ();
        status_result = (new_size > 0) ? Status.OPTIMIZED : Status.FAILED;
        reason = rewrite.failure;
      } else {
        reason = this.failure_reason (standard_error);
      }
    } catch (Error e) {
      warning ("Failed to run optipng on \"%s\": %s", image, e.message);
      reason = _("The optimizer could not be started");
    }

    // Always, so a failure or a quit halfway through does not leave the copy
    // behind.
    rewrite.cleanup ();

    // The status is what the row and the summary bar go by. A size only means
    // anything alongside OPTIMIZED, and the list checks that it really is
    // smaller before it counts as a saving.
    this.list.update_result (image, status_result, new_size, reason);
  }

  /**
   * Whether this PNG says anything about how its colours should be read.
   *
   * Four chunks do that, and optipng counts all four as metadata: iCCP is a full
   * profile, gAMA is the gamma, sRGB is the rendering intent and cHRM names the
   * primaries. Measured, "-strip all" removes every one of them, and a viewer
   * then falls back on its own assumptions.
   *
   * A PNG is a signature followed by chunks of [length][type][data][crc], and
   * the spec puts all four before the first IDAT, so the walk can stop as soon
   * as the image data starts. Nothing is written here, only read, which is why
   * this is a safe way to decide about a flag that would otherwise destroy them.
   *
   * Returns false when the file cannot be read or does not look like a PNG. That
   * is the same answer as "nothing to lose", and it is the right one: optipng is
   * about to refuse the file anyway, and the row will say so.
   *
   * @param  string path
   * @return bool
   */
  private static bool carries_colour_information (string path) {
    try {
      var stream = new DataInputStream (File.new_for_path (path).read ());
      // PNG is big endian, which is also what DataInputStream defaults to.
      var header = new uint8[8];
      size_t read;

      if (! stream.read_all (header, out read) || read != 8) {
        return false;
      }

      // The cap is there so a truncated or hostile file cannot keep this going.
      // Sixty chunks is far more than the handful that precede the image data.
      for (var i = 0; i < 60; i++) {
        var length = stream.read_uint32 ();
        var type = new uint8[4];

        if (! stream.read_all (type, out read) || read != 4) {
          return false;
        }

        char[] letters = { (char) type[0], (char) type[1], (char) type[2], (char) type[3], '\0' };
        var name = (string) letters;

        if (name == "iCCP" || name == "gAMA" || name == "sRGB" || name == "cHRM") {
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
      // Not worth a warning: optipng gets the same file a moment later and its
      // own complaint is the one that reaches the row.
      return false;
    }

    return false;
  }

  /**
   * Put what optipng said into words for the row.
   *
   * The log keeps the tool's own output either way. This only has to answer the
   * question someone looking at a red icon actually has, which is whether the
   * file is the problem or the app is.
   *
   * @param  string standard_error
   * @return string
   */
  private string failure_reason (string standard_error) {
    // What optipng says about anything that is not a PNG, whatever its name is.
    if ("Unrecognized image file format" in standard_error) {
      return _("This is not a PNG file, whatever its name says");
    }

    if ("Can't back up" in standard_error || "Permission denied" in standard_error) {
      return _("Could not write to this file, it may be read only");
    }

    return _("The optimizer could not process this file");
  }

  /**
   * Get the optimized image size from the optipng output.
   *
   * optipng prints "Output file size = 19906 bytes" on stderr. A file it cannot
   * read gets "Error: Unrecognized image file format" and no size at all, which
   * yields 0 here. The already optimized case never reaches this method, the
   * caller checks for it first, so a 0 really is a failure worth reporting.
   *
   * @param  string output
   * @return int
   */
  public int get_new_size (string output) {
    var size = Utils.size_after (output, "Output file size = ");

    if (size == 0) {
      warning ("Could not read a size from the optipng output: %s", output);
    }

    return size;
  }
}
