#!/usr/bin/env bash
#
# Regression suite for the optimizer path. Where smoke-test.sh answers "does it
# run at all", this covers the things that have actually broken before:
#
#   R1  awkward filenames. A quote used to abort the whole batch, not just the
#       file that carried it.
#   R2  unreadable files. These used to take the process down with SIGSEGV.
#   R3  a larger mixed batch, where every single file has to be dealt with.
#   R4  parallel output has to equal sequential output, byte for byte.
#   R5  a single core machine has to behave like it always did.
#   R6  a single file, so a single worker.
#   R7  no diagnostics for input that is perfectly fine.
#   R8  Ctrl+Q, which the app description promises.
#   R9  a bmp, which the app used to accept and then not optimize.
#
# Usage, against an installed tree:
#
#   DESTDIR="$PWD/dest" ninja -C build install
#   .github/scripts/regression-test.sh dest/usr/bin/com.github.gijsgoudzwaard.image-optimizer
#
set -uo pipefail

APP=${1:?usage: regression-test.sh <path to the installed binary>}
if [ ! -x "$APP" ]; then
  echo "regression: not an executable: $APP" >&2
  exit 1
fi
APP=$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
PNG_SOURCE="$REPO_ROOT/data/screenshots/welcome-screen.png"
JPG_SOURCE="$REPO_ROOT/.github/fixtures/fixture.jpg"
BMP_SOURCE="$REPO_ROOT/.github/fixtures/fixture.bmp"

WORK=$(mktemp -d)
XVFB_PID=""
APP_PID=""

cleanup () {
  [ -n "$APP_PID" ] && kill "$APP_PID" 2>/dev/null
  [ -n "$XVFB_PID" ] && kill "$XVFB_PID" 2>/dev/null
  rm -rf "$WORK"
  return 0
}
trap cleanup EXIT

passed=0
failed=0

check () { # description, actual, expected
  if [ "$2" = "$3" ]; then
    echo "  PASS $1"
    passed=$((passed + 1))
  else
    echo "  FAIL $1 (got '$2', expected '$3')"
    failed=$((failed + 1))
  fi
}

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
  echo "regression: could not start Xvfb on any display from 90 to 99" >&2
  cat "$WORK/xvfb.log" >&2
  exit 1
fi

export DISPLAY=":$display_num"
export GDK_BACKEND=x11
# GTK asks for exactly this when there is no accessibility bus.
export GTK_A11Y=none

size () { stat -c%s "$1" 2>/dev/null || echo 0; }

# The app never exits by itself, so it is started in the background, polled
# until the files it was given are done, and then stopped.
start_app () { # prefix..., files
  local wrapper=$1
  shift
  if [ -n "$wrapper" ]; then
    timeout 180 $wrapper dbus-run-session -- "$APP" "$@" >"$WORK/app.log" 2>&1 &
  else
    timeout 180 dbus-run-session -- "$APP" "$@" >"$WORK/app.log" 2>&1 &
  fi
  APP_PID=$!
}

alive () { kill -0 "$APP_PID" 2>/dev/null && echo yes || echo no; }

stop_app () {
  kill "$APP_PID" 2>/dev/null
  wait "$APP_PID" 2>/dev/null
  APP_PID=""
  return 0
}

# Waits until at least $1 of the listed files are smaller than the size recorded
# in $WORK/before, giving up after $2 seconds.
wait_shrunk () {
  local want=$1 deadline=$2
  shift 2
  local end=$(( $(date +%s) + deadline ))

  while [ "$(date +%s)" -lt "$end" ]; do
    # A dead app is never going to finish the work, so do not sit out the
    # deadline for it. This is what keeps the generous deadlines below cheap:
    # a broken binary fails at once, only a slow but living one gets the wait.
    if ! kill -0 "$APP_PID" 2>/dev/null; then
      return 1
    fi

    local n=0
    for f in "$@"; do
      local before
      before=$(grep -F -- "$(basename "$f")|" "$WORK/before" | cut -d'|' -f2)
      local now
      now=$(size "$f")
      if [ "$now" -gt 0 ] && [ "$now" -lt "$before" ]; then
        n=$((n + 1))
      fi
    done
    [ "$n" -ge "$want" ] && return 0
    sleep 0.2
  done

  return 1
}

record () { # files
  : >"$WORK/before"
  for f in "$@"; do
    printf '%s|%s\n' "$(basename "$f")" "$(size "$f")" >>"$WORK/before"
  done
}

shrunk_count () { # files
  local n=0
  for f in "$@"; do
    local before
    before=$(grep -F -- "$(basename "$f")|" "$WORK/before" | cut -d'|' -f2)
    local now
    now=$(size "$f")
    if [ "$now" -gt 0 ] && [ "$now" -lt "$before" ]; then
      n=$((n + 1))
    fi
  done
  echo "$n"
}

echo "### R1 awkward filenames, together with an ordinary one ###"
r1="$WORK/r1"
mkdir -p "$r1"
cp "$PNG_SOURCE" "$r1/Don't panic.png"
cp "$PNG_SOURCE" "$r1/quote\"double.png"
cp "$PNG_SOURCE" "$r1/space and (brackets) & dollar\$.png"
cp "$PNG_SOURCE" "$r1/ordinary.png"
cp "$JPG_SOURCE" "$r1/Mom's photo.jpg"
record "$r1"/*
start_app "" "$r1"/*
wait_shrunk 5 60 "$r1"/*
check "app still running" "$(alive)" "yes"
check "files optimized" "$(shrunk_count "$r1"/*)" "5"
stop_app

echo "### R2 unreadable files do not take the app down ###"
r2="$WORK/r2"
mkdir -p "$r2"
printf 'not an image' >"$r2/broken.png"
printf 'not an image' >"$r2/broken.jpg"
cp "$PNG_SOURCE" "$r2/good.png"
record "$r2"/*
start_app "" "$r2/broken.png" "$r2/broken.jpg" "$r2/good.png"
wait_shrunk 1 60 "$r2/good.png"
check "app still running" "$(alive)" "yes"
check "valid file in the same batch still done" "$(shrunk_count "$r2/good.png")" "1"
stop_app

echo "### R3 larger mixed batch, nothing may be skipped ###"
r3="$WORK/r3"
mkdir -p "$r3"
for i in $(seq 1 12); do cp "$PNG_SOURCE" "$r3/p$i.png"; done
for i in $(seq 1 6); do cp "$JPG_SOURCE" "$r3/j$i.jpg"; done
record "$r3"/*
started=$(date +%s%N)
start_app "" "$r3"/*
wait_shrunk 18 60 "$r3"/*
finished=$(date +%s%N)
check "app still running" "$(alive)" "yes"
check "files optimized out of 18" "$(shrunk_count "$r3"/*)" "18"
echo "  (18 files in $(( (finished - started) / 1000000 )) ms, informational only)"
stop_app

echo "### R4 parallel output equals sequential output ###"
if command -v taskset >/dev/null 2>&1; then
  mkdir -p "$WORK/par" "$WORK/seq"
  for i in $(seq 1 4); do
    cp "$PNG_SOURCE" "$WORK/par/p$i.png"
    cp "$PNG_SOURCE" "$WORK/seq/p$i.png"
    cp "$JPG_SOURCE" "$WORK/par/j$i.jpg"
    cp "$JPG_SOURCE" "$WORK/seq/j$i.jpg"
  done
  # Pinned to one core the app falls back to a single worker per tool, which is
  # the sequential path. No flags are repeated here on purpose: the reference is
  # the app itself, so this keeps holding when the flags change.
  record "$WORK/seq"/*
  start_app "taskset -c 0" "$WORK/seq"/*
  wait_shrunk 8 60 "$WORK/seq"/*
  stop_app
  record "$WORK/par"/*
  start_app "" "$WORK/par"/*
  wait_shrunk 8 60 "$WORK/par"/*
  stop_app

  differing=0
  for f in "$WORK/par"/*; do
    cmp -s "$f" "$WORK/seq/$(basename "$f")" || differing=$((differing + 1))
  done
  check "files differing from the sequential run" "$differing" "0"
else
  echo "  SKIP taskset is not available, cannot pin to one core"
fi

echo "### R5 one core still works ###"
if command -v taskset >/dev/null 2>&1; then
  r5="$WORK/r5"
  mkdir -p "$r5"
  for i in $(seq 1 4); do cp "$PNG_SOURCE" "$r5/p$i.png"; done
  record "$r5"/*
  start_app "taskset -c 0" "$r5"/*
  wait_shrunk 4 60 "$r5"/*
  check "app still running on one core" "$(alive)" "yes"
  check "files optimized on one core" "$(shrunk_count "$r5"/*)" "4"
  stop_app
else
  echo "  SKIP taskset is not available"
fi

echo "### R6 a single file, so one worker ###"
r6="$WORK/r6"
mkdir -p "$r6"
cp "$PNG_SOURCE" "$r6/solo.png"
record "$r6"/*
start_app "" "$r6/solo.png"
wait_shrunk 1 60 "$r6/solo.png"
check "single file optimized" "$(shrunk_count "$r6/solo.png")" "1"
check "app still running" "$(alive)" "yes"
stop_app

echo "### R7 nothing logged for input that is fine ###"
# R6 was the last run and used only a valid file, so its log is the one to read.
noise=$(grep -E "CRITICAL|WARNING|\*\* ERROR" "$WORK/app.log" \
  | grep -vcE "Gsk-Message|libEGL|DRI3|Unable to acquire session bus" || true)
if [ "$noise" != "0" ]; then
  grep -E "CRITICAL|WARNING|\*\* ERROR" "$WORK/app.log" >&2
fi
check "diagnostics for valid input" "$noise" "0"

echo "### R8 Ctrl+Q quits the app ###"
# Listed as a feature in the app description and never covered by anything.
if command -v xdotool >/dev/null 2>&1; then
  r8="$WORK/r8"
  mkdir -p "$r8"
  cp "$PNG_SOURCE" "$r8/quit.png"
  record "$r8"/*
  start_app "" "$r8/quit.png"
  wait_shrunk 1 60 "$r8/quit.png"
  window=$(xdotool search --name "Image Optimizer" 2>/dev/null | head -1)
  if [ -n "$window" ]; then
    xdotool key --window "$window" --clearmodifiers ctrl+q 2>/dev/null
    gone=no
    for _ in $(seq 1 100); do
      kill -0 "$APP_PID" 2>/dev/null || { gone=yes; break; }
      sleep 0.1
    done
    check "Ctrl+Q closed the app" "$gone" "yes"
  else
    echo "  FAIL no window named 'Image Optimizer' to send Ctrl+Q to"
    failed=$((failed + 1))
  fi
  stop_app
else
  echo "  SKIP xdotool is not available"
fi

echo "### R9 an unsupported type is left alone ###"
# bmp was accepted once. optipng cannot write one, so it produced a new .png
# beside the file and left the .bmp exactly as it was, while the list reported a
# 99% saving on the file the user had actually selected. The fixture has to be a
# real bmp for that: optipng goes by content, so a png carrying a .bmp name gets
# rewritten in place instead and the second file never appears.
r9="$WORK/r9"
mkdir -p "$r9"
cp "$BMP_SOURCE" "$r9/photo.bmp"
record "$r9"/*
start_app "" "$r9/photo.bmp"
# Nothing should happen, so there is no event to wait for. Give it the time a
# single file would have taken and then look at the directory.
sleep 5
check "app still running" "$(alive)" "yes"
check "the file is unchanged" "$(cmp -s "$BMP_SOURCE" "$r9/photo.bmp" && echo yes || echo no)" "yes"
# The one that catches the old behaviour: it left a second file behind.
check "files in the directory" "$(find "$r9" -type f | wc -l | tr -d ' ')" "1"
stop_app

echo
if [ "$failed" -ne 0 ]; then
  # Whatever went wrong, the app's own output from the last group is usually
  # the fastest way to see it, so do not make anyone reproduce it to find out.
  echo "--- output of the last run of the app ---"
  cat "$WORK/app.log" 2>/dev/null
  echo "--- end ---"
fi
echo "regression: $passed passed, $failed failed"
exit "$failed"
