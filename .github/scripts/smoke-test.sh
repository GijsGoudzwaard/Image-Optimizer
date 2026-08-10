#!/usr/bin/env bash
#
# Headless smoke test: prove the built app actually starts and optimizes images.
#
# A compile is not enough. The GTK4 port of the image list once built with zero
# errors while the list never refreshed at all, and only starting the app
# surfaced that. This runs the real binary on a virtual display against real
# images and checks it does its job.
#
# Usage, against an installed tree:
#
#   meson setup build --prefix=/usr
#   ninja -C build
#   DESTDIR="$PWD/dest" ninja -C build install
#   .github/scripts/smoke-test.sh dest/usr/bin/com.github.gijsgoudzwaard.image-optimizer
#
set -euo pipefail

APP=${1:?usage: smoke-test.sh <path to the installed binary>}
if [ ! -x "$APP" ]; then
  echo "smoke: not an executable: $APP" >&2
  exit 1
fi

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
WORK=$(mktemp -d)
XVFB_PID=""

cleanup() {
  [ -n "$XVFB_PID" ] && kill "$XVFB_PID" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# One fixture per optimizer, so a change to either tool's flags is covered.
# Both are dedicated fixtures rather than screenshots: they have to stay
# baseline, with the JPEG keeping its comment marker so the strip and progressive
# flags have anything to do, which is not something data/screenshots should have
# to guarantee. Those get optimized before they are published, and an already
# optimal file cannot shrink. The assertion below only requires one to shrink.
cp "$REPO_ROOT/.github/fixtures/fixture.png" "$WORK/fixture.png"
cp "$REPO_ROOT/.github/fixtures/fixture.jpg" "$WORK/fixture.jpg"

size () { stat -c%s "$1"; }

png_before=$(size "$WORK/fixture.png")
jpg_before=$(size "$WORK/fixture.jpg")

# Starts Xvfb on the first display it can actually claim. Checking only for the
# socket file is not enough: the file survives the server, so a stale one from a
# previous run reads as "ready" and every test then fails to open a display.
# Whether the Xvfb process is still alive is the real signal.
start_xvfb () {
  local n
  for n in $(seq 90 99); do
    rm -f "/tmp/.X11-unix/X$n" 2>/dev/null
    Xvfb ":$n" -screen 0 1200x900x24 -nolisten tcp >"$WORK/xvfb.log" 2>&1 &
    XVFB_PID=$!
    sleep 1
    if kill -0 "$XVFB_PID" 2>/dev/null && [ -e "/tmp/.X11-unix/X$n" ]; then
      display_num=$n
      return 0
    fi
    kill "$XVFB_PID" 2>/dev/null
    XVFB_PID=""
  done
  return 1
}

display_num=""
if ! start_xvfb; then
  echo "smoke: could not start Xvfb on any display from 90 to 99" >&2
  cat "$WORK/xvfb.log" >&2
  exit 1
fi

# The app has no headless mode and never exits by itself, so it gets a fixed
# window to do the work and is then stopped. Being killed by timeout, exit 124,
# is the expected outcome.
# GTK_A11Y=none because there is no accessibility bus here and GTK asks for
# exactly this rather than warning about it.
set +e
DISPLAY=":$display_num" GDK_BACKEND=x11 GTK_A11Y=none \
  timeout 60 dbus-run-session -- "$APP" "$WORK/fixture.png" "$WORK/fixture.jpg" \
  >"$WORK/app.log" 2>&1
status=$?
set -e

png_after=$(size "$WORK/fixture.png")
jpg_after=$(size "$WORK/fixture.jpg")

echo "smoke: png $png_before -> $png_after"
echo "smoke: jpg $jpg_before -> $jpg_after"
echo "smoke: exit status $status"
echo "--- application output ---"
cat "$WORK/app.log"
echo "--- end of application output ---"

failed=0

if [ "$status" -ne 124 ] && [ "$status" -ne 0 ]; then
  echo "smoke: FAIL the app died with status $status instead of running until stopped" >&2
  failed=1
fi

if [ "$png_after" -ge "$png_before" ] && [ "$jpg_after" -ge "$jpg_before" ]; then
  echo "smoke: FAIL neither fixture got smaller, so the optimizers never ran" >&2
  failed=1
fi

# Headless there is no GPU, so GSK falls back to cairo and libEGL complains
# about DRI3. Without a real session bus GtkApplication says so as well. None
# of those are defects. Anything else logged at warning level or worse is.
if grep -E "CRITICAL|WARNING|\*\* ERROR" "$WORK/app.log" \
    | grep -vE "Gsk-Message|libEGL|DRI3|Unable to acquire session bus" >&2; then
  echo "smoke: FAIL unexpected diagnostics logged, see above" >&2
  failed=1
fi

if [ "$failed" -eq 0 ]; then
  echo "smoke: OK"
fi

exit "$failed"
