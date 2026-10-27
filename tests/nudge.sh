#!/usr/bin/env bash
# The browser viewer's nudger (lib/x11-nudge.py) on a private X display; no
# install needed. One per X server, through the selection _VEDABASE_NUDGER:
# a second leaves at once, and one that loses the selection leaves; a request
# whose requestor is gone before the answer does not end it; a nudger held up
# past its display's end leaves a new server under the same number one of its
# own; a nudger ends with its display.
set -u
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
B=$VB_TEST_WORK/nudge
rm -rf -- "$B"; mkdir -p "$B"; chmod 700 "$B"
export PATH=$VB_TEST_TOOLS/usr/bin:$PATH LD_LIBRARY_PATH=$VB_TEST_TOOLS/usr/lib/x86_64-linux-gnu
for t in Xtigervnc xauth python3; do
  command -v "$t" >/dev/null || { echo "SKIP  the nudger: no $t (VB_TEST_TOOLS=$VB_TEST_TOOLS)"; exit 0; }
done
helper=$REPO/lib/x11-nudge.py
asked() { timeout 5 python3 -I "$helper" running >/dev/null 2>&1; } # 0: one runs; 3: none; 1: no display
start_nudger() { # LOG: an 'every 0.2' in the background, as $nudger, once it holds the selection
  setsid python3 -I "$helper" every 0.2 >"$1" 2>&1 </dev/null &
  nudger=$!
  for _ in $(seq 1 25); do asked && return 0; sleep 0.2; done
}
alive() { kill -0 "$1" 2>/dev/null; }
gone() { # PID: ended within 3 s?
  for _ in $(seq 1 15); do kill -0 "$1" 2>/dev/null || return 0; sleep 0.2; done
  return 1
}

start_display "$B/x" || { fail "a private X display starts"; finish; }
asked; check "with none started, 'running' says none (3)" test $? -eq 3
start_nudger "$B/first.log"; first=$nudger
asked; check "'every' takes the selection, and 'running' says so (0)" test $? -eq 0
timeout 5 python3 -I "$helper" every 0.2; check "a second 'every' leaves at once (0)" test $? -eq 0
check "  ... and the first goes on" alive "$first"
python3 -I "$TESTS/x11/rival.py" ask-and-vanish _VEDABASE_NUDGER; sleep 1
check "a request whose requestor is gone before the answer does not end it" alive "$first"
asked; check "  ... it still holds the selection" test $? -eq 0
python3 -I "$TESTS/x11/rival.py" take _VEDABASE_NUDGER 2 &
rival=$!
check "a nudger that loses the selection leaves" gone "$first"
wait "$rival"

# Held up (SIGSTOP) while its display ends: a new server under the same number,
# started here by hand at it, has no owner and gets a nudger of its own.
start_nudger "$B/held.log"; held=$nudger
n=${DISPLAY#:}
hold "$held"
stop_display
for _ in $(seq 1 25); do [[ -e /tmp/.X11-unix/X$n || -e /tmp/.X$n-lock ]] || break; sleep 0.2; done
_vb_sock=$(mktemp -u /tmp/vedabase-test-XXXXXXXX.sock)
setsid Xtigervnc ":$n" -auth "$B/x/xauth" -geometry 1024x768 -depth 24 -rfbport -1 -localhost \
  -rfbunixpath "$_vb_sock" -rfbunixmode 0600 -nolisten tcp -SecurityTypes None >"$B/x/xvnc-again.log" 2>&1 </dev/null &
_vb_xpid=$!
for _ in $(seq 1 50); do asked; [[ $? -eq 1 ]] || break; sleep 0.2; done
asked; check "a new server under the old one's number (:$n) starts with no nudger (3)" test $? -eq 3
start_nudger "$B/second.log"; second=$nudger
asked; check "  ... and gets one of its own while the old one is held up" test $? -eq 0
kill -CONT "$held"
check "  ... the held one ends once it runs again" gone "$held"
asked; check "  ... and the new one goes on" test $? -eq 0
stop_display
check "a nudger ends with its display" gone "$second"
finish
