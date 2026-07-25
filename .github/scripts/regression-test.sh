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
#   R6  no diagnostics for input that is perfectly fine.
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

# A display of its own, so this can run next to smoke-test.sh.
display_num=98
Xvfb ":$display_num" -screen 0 1200x900x24 -nolisten tcp >"$WORK/xvfb.log" 2>&1 &
XVFB_PID=$!

for _ in $(seq 1 40); do
  [ -e "/tmp/.X11-unix/X$display_num" ] && break
  sleep 0.25
done
if [ ! -e "/tmp/.X11-unix/X$display_num" ]; then
  echo "regression: Xvfb never came up" >&2
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
    timeout 90 $wrapper dbus-run-session -- "$APP" "$@" >"$WORK/app.log" 2>&1 &
  else
    timeout 90 dbus-run-session -- "$APP" "$@" >"$WORK/app.log" 2>&1 &
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
wait_shrunk 5 45 "$r1"/*
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
wait_shrunk 1 45 "$r2/good.png"
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
  wait_shrunk 8 75 "$WORK/seq"/*
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
  wait_shrunk 4 75 "$r5"/*
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
wait_shrunk 1 45 "$r6/solo.png"
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

echo
echo "regression: $passed passed, $failed failed"
exit "$failed"
