/**
 * What happened to one image.
 *
 * The app used to know only "still busy" and "done", and a size of 0 stood in
 * for every way a file could go wrong. That is enough for a single row, which
 * then reports no saving, but not for a total: a failure counted as a processed
 * file, and a file that was already as small as it gets counted as one the app
 * had improved. The summary bar needs those apart, so they are named here.
 */
public enum Status {

  /**
   * Queued or being worked on.
   */
  PENDING,

  /**
   * Bytes were written back and the file really is smaller.
   */
  OPTIMIZED,

  /**
   * The optimizer ran without trouble, there was simply nothing left to win.
   */
  ALREADY_OPTIMAL,

  /**
   * The copy could not be made, the optimizer exited with an error, or the
   * result could not be written back.
   */
  FAILED,

  /**
   * Never offered to an optimizer, because it is not a PNG or a JPEG.
   */
  UNSUPPORTED
}
