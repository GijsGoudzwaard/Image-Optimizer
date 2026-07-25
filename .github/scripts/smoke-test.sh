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

# Fixtures come from the repository so the test needs no binary blobs of its
# own. Both currently shrink by 9% or more. The assertion below only requires
# one of them to shrink, so optimizing the screenshots one day weakens this
# test but does not break it.
cp "$REPO_ROOT/data/screenshots/welcome-screen.png" "$WORK/fixture.png"
cp "$REPO_ROOT/data/screenshots/treeview.jpg" "$WORK/fixture.jpg"

size () { stat -c%s "$1"; }

png_before=$(size "$WORK/fixture.png")
jpg_before=$(size "$WORK/fixture.jpg")

display_num=99
Xvfb ":$display_num" -screen 0 1200x900x24 -nolisten tcp >"$WORK/xvfb.log" 2>&1 &
XVFB_PID=$!

for _ in $(seq 1 40); do
  [ -e "/tmp/.X11-unix/X$display_num" ] && break
  sleep 0.25
done
if [ ! -e "/tmp/.X11-unix/X$display_num" ]; then
  echo "smoke: Xvfb never came up" >&2
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
