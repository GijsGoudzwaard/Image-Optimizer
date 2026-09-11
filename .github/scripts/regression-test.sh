#!/usr/bin/env bash
#
# Regression suite for the optimizer path. Where smoke-test.sh answers "does it
# run at all", this covers the things that have actually broken before:
#
#   R1  awkward filenames. A quote used to abort the whole batch, not just the
#       file that carried it, and a mixed case extension is a file the optimizer
#       refuses to recognise unless the working copy is named carefully.
#   R2  unreadable files. These used to take the process down with SIGSEGV.
#   R3  a larger mixed batch, where every single file has to be dealt with.
#   R4  parallel output has to equal sequential output, byte for byte.
#   R5  a single core machine has to behave like it always did.
#   R6  a single file, so a single worker.
#   R7  no diagnostics for input that is perfectly fine.
#   R8  Ctrl+Q, which the app description promises.
#   R9  a bmp, which the app used to accept and then not optimize.
#   R10 a read-only directory, which the copy-and-write-back path has to survive.
#   R11 a read-only file, which has to fail without inventing a saving.
#   R12 a second pass over the same file, which is the already optimal path.
#   R13 quitting mid batch, which may never leave a file half written.
#   R14 a photo with Exif, whose orientation flag has to survive.
#   R15 a png that says how its colours should be read, which has to survive too.
#   R16 the two passes, and the app keeping the better of them.
#   R17 modification times, which the app promises to leave alone.
#   R18 a missing optimizer, which is now every file rather than half of them.
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
# Deliberately its own fixture and not a file from data/screenshots. Those are
# store listing assets and get optimized before they are published, at
# which point they cannot shrink any further and every assertion here fails.
PNG_SOURCE="$REPO_ROOT/.github/fixtures/fixture.png"
JPG_SOURCE="$REPO_ROOT/.github/fixtures/fixture.jpg"
BMP_SOURCE="$REPO_ROOT/.github/fixtures/fixture.bmp"
# Both of these carry something worth keeping and still have room to shrink, so a
# run that keeps the metadata and a run that does nothing at all look different.
EXIF_SOURCE="$REPO_ROOT/.github/fixtures/fixture-exif.jpg"
ICC_SOURCE="$REPO_ROOT/.github/fixtures/fixture-icc.png"
# A smooth gradient, and the one file in here that the good optimization level
# cannot improve at all while the cheap one takes 4.5% off it. It exists to prove
# that both passes run.
#
#   convert -size 640x400 gradient:'#687ddb-#ffffff' \
#     -define png:exclude-chunk=date fixture-gradient.png
GRADIENT_SOURCE="$REPO_ROOT/.github/fixtures/fixture-gradient.png"

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
# Kept so the summary can name them. This suite is long and both CI and a
# terminal cut the middle out of it, so a run that fails early otherwise ends in
# a count with no clue what it was.
failures=""

check () { # description, actual, expected
  if [ "$2" = "$3" ]; then
    echo "  PASS $1"
    passed=$((passed + 1))

    return 0
  fi

  echo "  FAIL $1 (got '$2', expected '$3')"
  failures="$failures
  $1 (got '$2', expected '$3')"
  failed=$((failed + 1))

  # The log of the run that just failed. The summary at the end prints the last
  # group's log, which is the wrong one whenever the failure was earlier: that
  # cost a full round trip through CI once, with a failure that could not be
  # reproduced locally and no way to see what the app had said.
  if [ -s "$WORK/app.log" ]; then
    echo "    --- what the app logged in this group ---"
    grep -vE "libEGL|DRI3" "$WORK/app.log" | head -20 | sed 's/^/    /'
    echo "    --- end ---"
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
# Mixed case on purpose. The optimizer decides what a file is by its extension
# and only recognises one written all in lower case or all in upper case, so a
# file named like this is answered with "No compatible files found" unless the
# copy it is handed was named with that in mind. It reads as a file that was
# already small enough, which is the quietest way for this to break.
cp "$PNG_SOURCE" "$r1/Holiday.Png"
record "$r1"/*
start_app "" "$r1"/*
wait_shrunk 6 60 "$r1"/*
check "app still running" "$(alive)" "yes"
check "files optimized" "$(shrunk_count "$r1"/*)" "6"
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
# bmp was accepted once. The optimizer of the day could not write one, so it
# produced a new .png beside the file and left the .bmp exactly as it was, while
# the list reported a 99% saving on the file the user had actually selected. The
# fixture is a real bmp so that the file is what it claims to be; the app turns
# it away on its name before any optimizer sees it.
#
# Such a file does get a row now, saying it is not supported, instead of being
# dropped on the way in. What matters here is unchanged: nothing on disk moves,
# and no optimizer is ever handed the file.
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

echo "### R10 a read-only directory no longer stops the optimization ###"
# The optimizers replace a file by writing a temporary one beside it and
# renaming, so they need write access to the directory. The app now hands them a
# copy inside its own runtime directory and writes the result back over the
# original file descriptor, which only needs write access to the file. A
# directory the user cannot write to therefore has to work, and that is the same
# shape as a document portal path, where the grant covers one file and nothing
# around it.
if [ "$(id -u)" = "0" ]; then
  # root is exempt from these permissions, so the case would pass for the wrong
  # reason. CI runs the suite as an ordinary user, where it applies.
  echo "  SKIP running as root, which ignores file and directory permissions"
else
  r10="$WORK/r10"
  mkdir -p "$r10"
  cp "$PNG_SOURCE" "$r10/locked-dir.png"
  cp "$JPG_SOURCE" "$r10/locked-dir.jpg"
  record "$r10"/*
  chmod a-w "$r10"
  start_app "" "$r10/locked-dir.png" "$r10/locked-dir.jpg"
  wait_shrunk 2 60 "$r10"/*
  check "app still running" "$(alive)" "yes"
  check "both files optimized in an unwritable directory" "$(shrunk_count "$r10"/*)" "2"
  stop_app
  chmod u+w "$r10"

  echo "### R11 a read-only file fails without a fake saving ###"
  # The one case that genuinely cannot be written. It has to be reported as a
  # failure in the log and leave the file alone, rather than parsing the
  # optimizer's optimistic output into a saving that never happened.
  r11="$WORK/r11"
  mkdir -p "$r11"
  cp "$PNG_SOURCE" "$r11/readonly.png"
  cp "$JPG_SOURCE" "$r11/readonly.jpg"
  record "$r11"/*
  chmod a-w "$r11"/readonly.*
  start_app "" "$r11/readonly.png" "$r11/readonly.jpg"
  # Nothing can be written, so wait out the time an optimization would have taken.
  sleep 8
  check "app still running" "$(alive)" "yes"
  check "files left untouched" "$(shrunk_count "$r11"/*)" "0"
  check "failure was logged" \
    "$(grep -qE "Could not write the result back" "$WORK/app.log" && echo yes || echo no)" "yes"
  stop_app
  chmod u+w "$r11"/readonly.*
fi

echo "### R12 a file that is already optimal is left alone and not reported as failed ###"
# The app tells three things apart that used to look the same: optimized, already
# optimal, and failed. Only the middle one has no visible trace, so this is the
# one worth testing from the outside: run the app twice over the same files and
# the second pass has to leave them byte for byte as the first pass left them,
# without a single diagnostic. If the already optimal branch ever breaks, the size
# it fails to parse gets logged, which is what the last check catches.
r12="$WORK/r12"
mkdir -p "$r12"
cp "$PNG_SOURCE" "$r12/twice.png"
cp "$JPG_SOURCE" "$r12/twice.jpg"
record "$r12"/*
start_app "" "$r12"/*
wait_shrunk 2 60 "$r12"/*
check "both files optimized on the first pass" "$(shrunk_count "$r12"/*)" "2"
stop_app

cp "$r12/twice.png" "$WORK/r12-png.first"
cp "$r12/twice.jpg" "$WORK/r12-jpg.first"

start_app "" "$r12"/*
# Nothing should change, so there is no event to wait for. Give it the time the
# first pass took and then compare.
sleep 8
check "app still running" "$(alive)" "yes"
check "the png is untouched by the second pass" \
  "$(cmp -s "$WORK/r12-png.first" "$r12/twice.png" && echo yes || echo no)" "yes"
check "the jpg is untouched by the second pass" \
  "$(cmp -s "$WORK/r12-jpg.first" "$r12/twice.jpg" && echo yes || echo no)" "yes"
noise=$(grep -E "CRITICAL|WARNING|\*\* ERROR" "$WORK/app.log" \
  | grep -vcE "Gsk-Message|libEGL|DRI3|Unable to acquire session bus" || true)
if [ "$noise" != "0" ]; then
  grep -E "CRITICAL|WARNING|\*\* ERROR" "$WORK/app.log" >&2
fi
check "diagnostics on the second pass" "$noise" "0"
stop_app

echo "### R13 quitting during a batch leaves no half written file ###"
# Writing a result back is a write followed by a truncate, and between those two
# the original carries the new head on the old length. Quitting in that gap used
# to be possible, because the workers are detached threads and nothing held the
# exit. The app now waits for any write back before it goes.
#
# The check needs no reference file. A finished file is always smaller than what
# it started as, an untouched file is byte for byte the original, and the broken
# state is the one that kept the original length while the bytes changed. So:
# same size means it has to be identical, smaller is fine, larger is wrong.
#
# This is a guard and not a proof. Without help the gap is milliseconds wide, so
# a passing run does not mean the hold works. That was proven separately by
# putting a second of sleep between the write and the truncate, where the same
# quit left a 16286 byte file with the new head and no drain, and a correct 13046
# byte file with it.
if command -v xdotool >/dev/null 2>&1; then
  r13="$WORK/r13"
  mkdir -p "$r13"
  for i in $(seq 1 10); do cp "$PNG_SOURCE" "$r13/q$i.png"; done
  for i in $(seq 1 6); do cp "$JPG_SOURCE" "$r13/q$i.jpg"; done
  mkdir -p "$WORK/r13-orig"
  cp "$r13"/* "$WORK/r13-orig/"
  record "$r13"/*
  start_app "" "$r13"/*
  # Long enough that the first files are being written back, short enough that
  # the batch is nowhere near done.
  sleep 0.6
  window=$(xdotool search --name "Image Optimizer" 2>/dev/null | head -1)
  if [ -n "$window" ]; then
    xdotool key --window "$window" --clearmodifiers ctrl+q 2>/dev/null
    for _ in $(seq 1 100); do
      kill -0 "$APP_PID" 2>/dev/null || break
      sleep 0.1
    done
  fi
  stop_app

  mixed=0
  for f in "$r13"/*; do
    name=$(basename "$f")
    before=$(size "$WORK/r13-orig/$name")
    now=$(size "$f")
    if [ "$now" -gt "$before" ]; then
      mixed=$((mixed + 1))
    elif [ "$now" -eq "$before" ] && ! cmp -s "$f" "$WORK/r13-orig/$name"; then
      mixed=$((mixed + 1))
    fi
  done
  check "files left in a half written state" "$mixed" "0"
else
  echo "  SKIP xdotool is not available"
fi

echo "### R14 a photo keeps its Exif, so it does not come out on its side ###"
# The orientation flag lives in the Exif block. A phone stores a portrait photo
# as a landscape image plus that flag, so stripping Exif changes no pixel at all
# and still turns every such photo sideways. The app shipped a version that did
# exactly that, which is why this check exists.
# grep on the raw bytes is enough here: the marker is the literal string "Exif",
# and after a strip it is gone.
r14="$WORK/r14"
mkdir -p "$r14"
cp "$EXIF_SOURCE" "$r14/photo.jpg"
record "$r14"/*
start_app "" "$r14/photo.jpg"
wait_shrunk 1 60 "$r14/photo.jpg"
check "the photo was optimized" "$(shrunk_count "$r14/photo.jpg")" "1"
check "the Exif block survived" \
  "$(grep -a -q 'Exif' "$r14/photo.jpg" && echo yes || echo no)" "yes"
stop_app

echo "### R15 a png keeps what it says about its own colours ###"
# iCCP, gAMA, sRGB and cHRM tell a viewer how to read the colours in the file,
# and "-strip" removes all four. So the flag is only ever passed to a file that
# carries none of them, which is what the second half of this checks: a file with
# only cHRM has to keep it, even though nothing else in that file is worth
# keeping. That is the half with teeth. Pass the flag unconditionally and this
# is the check that fails.
r15="$WORK/r15"
mkdir -p "$r15"
cp "$ICC_SOURCE" "$r15/profiled.png"
cp "$PNG_SOURCE" "$r15/plain.png"
record "$r15"/*
start_app "" "$r15"/*
wait_shrunk 2 60 "$r15"/*
check "both pngs were optimized" "$(shrunk_count "$r15"/*)" "2"
check "the colour profile survived" \
  "$(grep -a -q 'iCCP' "$r15/profiled.png" && echo yes || echo no)" "yes"
check "the other png kept what it says about its colours" \
  "$(grep -a -q 'cHRM' "$r15/plain.png" && echo yes || echo no)" "yes"
stop_app

echo "### R16 the app keeps the better of its two passes ###"
# The app optimizes every file twice, at a cheap level and a good one, and keeps
# whichever came out smaller. Which of the two wins is not fixed and is not ours
# to predict: on this gradient the cheap pass wins here, and the good one answers
# "encoding error 83: memory allocation failed" and leaves the file alone. On
# another machine the split is different again.
#
# So this asserts no number. It runs both passes itself, works out which is
# better, and requires the app to have produced exactly that. It fails if the app
# ever runs one pass instead of two, and it keeps telling the truth on a machine
# where the optimizer behaves differently from this one.
if command -v ect >/dev/null 2>&1; then
  r16="$WORK/r16"
  mkdir -p "$r16"
  cp "$GRADIENT_SOURCE" "$r16/gradient.png"
  # The same flags the app uses. This file carries cHRM, so nothing is stripped.
  cp "$GRADIENT_SOURCE" "$r16/pass-one.png"
  cp "$GRADIENT_SOURCE" "$r16/pass-five.png"
  ect -1 --strict "$r16/pass-one.png" >/dev/null 2>&1
  ect -5 --strict "$r16/pass-five.png" >/dev/null 2>&1

  original=$(size "$GRADIENT_SOURCE")
  one=$(size "$r16/pass-one.png")
  five=$(size "$r16/pass-five.png")
  best=$one
  [ "$five" -lt "$best" ] && best=$five
  # A pass that comes out no smaller is not written back at all.
  [ "$best" -ge "$original" ] && best=$original
  echo "  pass 1 gives $one, pass 5 gives $five, original is $original, so the app owes us $best"

  record "$r16/gradient.png"
  start_app "" "$r16/gradient.png"

  if [ "$best" -lt "$original" ]; then
    wait_shrunk 1 60 "$r16/gradient.png"
  else
    # Neither pass can improve it here, so there is no event to wait for.
    sleep 6
  fi

  check "the app kept the better of its two passes" "$(size "$r16/gradient.png")" "$best"
  check "the gradient kept what it says about its colours" \
    "$(grep -a -q 'cHRM' "$r16/gradient.png" && echo yes || echo no)" "yes"

  # Only worth asserting when one of the passes actually worked. A pass failing
  # where the other covers it is the design working and belongs in no log, but if
  # both of them fail the app is right to say so.
  if [ "$best" -lt "$original" ]; then
    noise=$(grep -E "CRITICAL|WARNING|\*\* ERROR" "$WORK/app.log" \
      | grep -vcE "Gsk-Message|libEGL|DRI3|Unable to acquire session bus" || true)
    check "nothing logged when one pass covers for the other" "$noise" "0"
  else
    echo "  SKIP neither pass can improve this file here, so there is nothing to be quiet about"
  fi

  stop_app
else
  echo "  SKIP no optimizer on PATH"
fi

echo "### R17 the modification time survives ###"
# The app description promises that a photo library sorted by date stays in
# order, and nothing here ever checked it. It is worth checking now: the tool no
# longer has a flag of its own for this, so what keeps the time is Rewrite, which
# reads it before the copy is made and puts it back after the write. That is our
# code, and this is the only thing watching it.
r17="$WORK/r17"
mkdir -p "$r17"
cp "$PNG_SOURCE" "$r17/dated.png"
cp "$EXIF_SOURCE" "$r17/dated.jpg"
touch -d "2019-03-14 09:26:53" "$r17"/dated.*
record "$r17"/*
start_app "" "$r17"/*
wait_shrunk 2 60 "$r17"/*
check "the png kept its modification time" \
  "$(stat -c%y "$r17/dated.png" | cut -c1-19)" "2019-03-14 09:26:53"
check "the jpg kept its modification time" \
  "$(stat -c%y "$r17/dated.jpg" | cut -c1-19)" "2019-03-14 09:26:53"
stop_app

echo "### R18 a missing optimizer is a row, not a crash ###"
# One tool does both formats now, so a binary that is not there is no longer half
# a failure, it is every file in the batch. What it may not become is a crash or
# a damaged file: the app has to come back, leave everything alone and say what
# happened.
ect_path=$(command -v ect 2>/dev/null)
if [ -n "$ect_path" ]; then
  r18="$WORK/r18"
  mkdir -p "$r18"
  cp "$PNG_SOURCE" "$r18/gone.png"
  intact=$(size "$r18/gone.png")
  record "$r18"/*
  # Everything the app needs except the directory the optimizer lives in, so that
  # dbus-run-session itself can still be found.
  without_ect=$(echo "$PATH" | tr ':' '\n' | grep -v "^$(dirname "$ect_path")$" | paste -sd: -)
  start_app "env PATH=$without_ect" "$r18/gone.png"
  # Nothing can happen, so wait out the time an optimization would have taken.
  sleep 6
  check "app still running without an optimizer" "$(alive)" "yes"
  check "the file was left alone" "$(size "$r18/gone.png")" "$intact"
  check "the app said what went wrong" \
    "$(grep -q "Failed to run ect" "$WORK/app.log" && echo yes || echo no)" "yes"
  stop_app
else
  echo "  SKIP no optimizer on PATH to hide"
fi

echo
if [ "$failed" -ne 0 ]; then
  echo "--- what failed ---$failures"
  # The app's own output from the last group is usually the fastest way to see
  # what happened, so do not make anyone reproduce it to find out. Note that it
  # is the last group's log and not the failing one's, if those differ.
  echo "--- output of the last run of the app ---"
  cat "$WORK/app.log" 2>/dev/null
  echo "--- end ---"
fi
echo "regression: $passed passed, $failed failed"
exit "$failed"
