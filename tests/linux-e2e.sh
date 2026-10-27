#!/usr/bin/env bash
# Linux end to end: a clean unattended install, doctor, permissions, the
# browser viewer (a word copied in Folio reaches its clipboard and converts;
# with CHROME_EXE set: it connects, survives six wrong passwords, takes typing,
# shows a copy made in the browser in noVNC's clipboard panel), stop, and a
# backup -> --reinstall --restore round trip.
set -u
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
B=$VB_TEST_WORK/linux-e2e H=$B/home VH=$B/vb PORT=${VB_TEST_PORT:-6091}
rm -rf -- "$B"; mkdir -p "$H"; chmod 700 "$B"
isolate "$H"
# An interrupted run stops its viewer and its Wine too.
# shellcheck disable=SC2016 # expanded when the test ends
at_exit '[[ ! -x $H/.local/bin/vedabase ]] || HOME=$H "$H/.local/bin/vedabase" stop >/dev/null 2>&1'
run() { HOME=$H "$@"; }
mapfile -t src < <(source_args)
cd "$REPO" || exit 1

run ./install.sh --home "$VH" "${src[@]}" >"$B/install.log" 2>&1
check "fresh install succeeds (log: $B/install.log)" test $? -eq 0
run "$H/.local/bin/vedabase" doctor >"$B/doctor.log" 2>&1
check "doctor passes" test $? -eq 0
check "the home is private (0700)" test "$(stat -c %a "$VH")" = 700
check "the prefix is private (0700)" test "$(stat -c %a "$VH/prefix")" = 700
check "the install is stamped" test -f "$VH/prefix/.vedabase-installed"
check "the installer's staging links are gone" test ! -L "$VH/prefix/drive_c/Install.exe"
check "no hidden display is left running" test "$(home_xvncs "$VH")" -eq 0
check "the menu has VedaBase Unicode" grep -qxF "Exec=$H/.local/bin/vedabase unicode" "$H/.local/share/applications/vedabase-unicode.desktop"
check "the install has xclip for it" test -x "$VH/tools/root/usr/bin/xclip" -o -n "$(command -v xclip)"
out=$(printf 'Kåñëa' | run "$H/.local/bin/vedabase" unicode -)
check "'vedabase unicode -' converts, from the installed copy" test "$out" = 'Kṛṣṇa'

VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web.out" 2>&1
check "vedabase web starts" test $? -eq 0
url=$(grep -o "http://localhost:$PORT/vnc.html[^ ]*" "$B/web.out" | head -n1)
check "it prints the browser link" test -n "$url"
check "the web display has no failed-login lockout" grep -q -- '-UseBlacklist=0' "/proc/$(cat "$VH/run/web/xvnc.pid")/cmdline"
# With no desktop, 'vedabase unicode' converts the browser viewer's clipboard.
web_clip() { # xclip ARGS... on the browser viewer's display
  DISPLAY=$(<"$VH/run/web/display") XAUTHORITY=$VH/run/web/xauth PATH=$VH/tools/root/usr/bin:$PATH \
    LD_LIBRARY_PATH=$VH/tools/root/usr/lib/x86_64-linux-gnu xclip -selection clipboard -t UTF8_STRING "$@"
}
web_unicode() { # TEXT: put it on that clipboard, then convert it as a web user would
  printf '%s' "$1" | web_clip -i >/dev/null 2>&1
  env -u DISPLAY -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR="$B" \
    HOME="$H" "$H/.local/bin/vedabase" unicode >>"$B/unicode-web.log" 2>&1
}
web_unicode 'Çré Kåñëa'
check "with no desktop, 'vedabase unicode' converts the browser viewer's clipboard" test "$(web_clip -o 2>/dev/null)" = 'Śrī Kṛṣṇa'
# A copy made in Folio itself. Wine 11.0 puts it on the X clipboard only when
# something wakes it (lib/x11-nudge.py), and on this display only the viewer's
# nudger does: without it, the clipboard would keep 'Śrī Kṛṣṇa'.
web_x() { # COMMAND...: on the browser viewer's display
  DISPLAY=$(<"$VH/run/web/display") XAUTHORITY=$VH/run/web/xauth PATH=$VH/tools/root/usr/bin:$PATH \
    LD_LIBRARY_PATH=$VH/tools/root/usr/lib/x86_64-linux-gnu "$@"
}
nudger_up() { web_x python3 -I "$VH/app/lib/x11-nudge.py" running >/dev/null 2>&1; }
nudgers() { # DISPLAY: this home's nudgers on it, found as prefix_procs finds Wine
  local p
  for p in $(pgrep -u "$(id -u)" -f 'x11-nudge[.]py every'); do
    grep -qzxF "DISPLAY=$1" "/proc/$p/environ" 2>/dev/null &&
      grep -qzxF "XAUTHORITY=$VH/run/web/xauth" "/proc/$p/environ" 2>/dev/null && echo "$p"
  done
}
check "the browser viewer runs a nudger for Wine's copies" nudger_up
for _ in $(seq 1 60); do [[ -n $(web_x xdotool search --name '^Folio Views' 2>/dev/null) ]] && break; sleep 0.5; done
sleep 4 # the infobase opening
web_x xdotool mousemove 430 66 click --repeat 3 --delay 80 1; sleep 0.5
web_x xdotool type --delay 40 -- "dehino 'smin yatha dehe"; web_x xdotool key Return; sleep 8
web_x xdotool mousemove 912 323 click --repeat 2 --delay 100 1; sleep 1
web_x xdotool key --clearmodifiers ctrl+c; sleep 2.5
# Folio's copy goes on past a NUL with leftovers from its buffer: up to it.
copied=''
IFS= read -r -d '' copied < <(web_clip -o 2>/dev/null) || :
check "a word copied in Folio reaches the viewer's clipboard by itself, as 'kaumäraà'" test "$copied" = 'kaumäraà'
env -u DISPLAY -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR="$B" \
  HOME="$H" "$H/.local/bin/vedabase" unicode >>"$B/unicode-web.log" 2>&1
check "'vedabase unicode' turns that copy into 'kaumāraṁ'" test "$(web_clip -o 2>/dev/null)" = 'kaumāraṁ'
if [[ -n ${CHROME_EXE:-} ]]; then
  sleep 8
  python3 "$TESTS/novnc/lockout.py" "$url" "$B/web-after-wrong.png" >"$B/lockout.log" 2>&1
  check "six wrong passwords, then the right one connects (log: $B/lockout.log)" test $? -eq 0
  python3 "$TESTS/novnc/search.py" "$url" "$B/web-typed.png" >"$B/search.log" 2>&1
  check "a search typed through the browser runs (look at $B/web-typed.png)" test $? -eq 0
  export -f web_clip web_unicode
  export VH H B
  python3 "$TESTS/novnc/clipboard.py" "$url" 'Gaṅgā jñāna' -- bash -c "web_unicode 'Gaìgä jïäna'" >"$B/clipboard.log" 2>&1
  check "noVNC's clipboard panel receives the converted text, Unicode intact (log: $B/clipboard.log)" test $? -eq 0
  python3 "$TESTS/novnc/copy.py" "$url" 'kaumäraà' "$B/web-copied.png" >"$B/copy.log" 2>&1
  check "a word copied in Folio through the browser shows in noVNC's clipboard panel (log: $B/copy.log)" test $? -eq 0
else
  echo "SKIP  browser checks (set CHROME_EXE to a Chromium for Playwright)"
fi
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web2.out" 2>&1
check "a second vedabase web gives the link again" grep -q 'already running' "$B/web2.out"
# Stopping must pick no process by name or by a recorded PID: one that only
# names the nudger (another install's, an editor on it) must survive, even
# behind a stale nudge.pid, as an earlier draft of the viewer kept.
bash -c "exec -a 'python3 -I $VH/app/lib/x11-nudge.py every 1' sleep 120" &
decoy=$!
printf '%s\n' "$decoy" >"$VH/run/web/nudge.pid"
display=$(<"$VH/run/web/display")
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1
check "stop leaves no display running" test "$(home_xvncs "$VH")" -eq 0
check "stop leaves no Wine running" test "$(prefix_procs "$VH/prefix")" -eq 0
check "stop ends the nudger" test -z "$(nudgers "$display")"
check "  ... and leaves a process that only names it alone" kill -0 "$decoy"
kill "$decoy"; wait "$decoy" 2>/dev/null
rm -f -- "$VH/run/web/nudge.pid"
# websockify.pid, which earlier versions kept, outlives websockify (a reboot
# with the viewer running leaves it), and its PID may then belong to anything:
# 'vedabase web' must serve the page all the same, and 'vedabase stop' must
# take the page down and leave that process alone.
sleep 300 &
reused=$!
printf '%s\n' "$reused" >"$VH/run/web/websockify.pid"
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web-stale-pid.out" 2>&1
page=$(curl -s --noproxy '*' -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/vnc.html")
check "behind a stale websockify.pid, 'vedabase web' still serves the page (HTTP $page)" test "$page" = 200
printf '%s\n' "$reused" >"$VH/run/web/websockify.pid"
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1
check "  ... 'vedabase stop' takes the page down all the same" test -z "$(ss -Htln "sport = :$PORT")"
check "  ... and leaves the process that file names alone" kill -0 "$reused"
kill "$reused"; wait "$reused" 2>/dev/null
rm -f -- "$VH/run/web/websockify.pid"
# A nudger that fails after starting (here: after 2 s) is reported, and the
# next 'vedabase web' starts one in its place.
mkdir -p "$B/late-python"
printf '#!/bin/sh\ncase " $* " in *" every "*) sleep 2; exit 1 ;; esac\nexec %s "$@"\n' "$(command -v python3)" \
  >"$B/late-python/python3"
chmod +x "$B/late-python/python3"
PATH=$B/late-python:$PATH VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web-late-python.out" 2>&1
check "a viewer whose nudger fails as it starts says so" grep -q "clipboard panel" "$B/web-late-python.out"
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web-again.out" 2>&1
check "  ... and 'vedabase web' run again starts one" nudger_up
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1
# A PID record that names another process (a stale one, after a reboot) must
# neither keep the display from stopping nor cost that process its life, even
# one that runs a program called Xtigervnc.
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web3.out" 2>&1
check "  (a display to stop is running)" test "$(home_xvncs "$VH")" -eq 1
mkdir -p "$B/namesake" && cp -- "$(command -v sleep)" "$B/namesake/Xtigervnc"
"$B/namesake/Xtigervnc" 300 &
namesake=$!
echo "$namesake" >"$VH/run/web/xvnc.pid"
run "$H/.local/bin/vedabase" stop >"$B/stop-wrong-record.out" 2>&1
check "behind a wrong PID record, 'vedabase stop' still ends the display" test "$(home_xvncs "$VH")" -eq 0
check "  ... and leaves the process the record names alone, though it is called Xtigervnc" kill -0 "$namesake"
kill "$namesake"; wait "$namesake" 2>/dev/null
# A display that outlives 'vedabase stop' is reported, even one that does not
# answer (here its Xvnc held up with SIGSTOP, so that it cannot act on the
# signal), and the next viewer gets a nudger all the same.
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web-survivor.out" 2>&1
survivor=$(cat "$VH/run/web/xvnc.pid") old_display=$(<"$VH/run/web/display")
hold "$survivor"
started=$SECONDS
run "$H/.local/bin/vedabase" stop >"$B/stop-survivor.out" 2>&1
echo "      (stop took $((SECONDS - started)) s)"
check "a display that outlives stop is reported, though it does not answer" grep -q 'did not stop' "$B/stop-survivor.out"
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web4.out" 2>&1
check "  ... and the next viewer gets a nudger of its own" nudger_up
kill -CONT "$survivor"; sleep 1
check "  ... while the survivor's ends with the survivor" test -z "$(nudgers "$old_display")"
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1
# The home spelled another way (here with a trailing slash) is the same home:
# 'vedabase status' sees its Wine, and 'vedabase stop' closes Wine first, as
# under the usual spelling, then ends the viewer.
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web-spelling.out" 2>&1
check "  (a display to stop is running)" test "$(home_xvncs "$VH")" -eq 1
sleep 5 # Folio opening
VEDABASE_HOME=$VH/ run "$H/.local/bin/vedabase" status >"$B/status-spelling.out" 2>&1
check "'vedabase status' with the home spelled another way sees Wine running" grep -q '^wine: *running' "$B/status-spelling.out"
VEDABASE_HOME=$VH/ run "$H/.local/bin/vedabase" stop >"$B/stop-spelling.out" 2>&1
check "  ... and 'vedabase stop' under that spelling has closed Wine when it returns" test "$(prefix_procs "$VH/prefix")" -eq 0
check "  ... ends the display" test "$(home_xvncs "$VH")" -eq 0
check "  ... and takes the page down" test -z "$(ss -Htln "sport = :$PORT")"
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1
# A record that names an earlier display's socket (here copied into another
# home, as a home since moved would keep one) must not reach the displays
# that come after it: each has a socket of its own.
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web-earlier.out" 2>&1
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1
mkdir -p "$B/moved/run/web" && cp -- "$VH/run/web/sock" "$B/moved/run/web/sock"
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web-later.out" 2>&1
VEDABASE_HOME=$B/moved run "$H/.local/bin/vedabase" stop >"$B/stop-moved.out" 2>&1
check "'vedabase stop' for another home holding an earlier display's record leaves this display running" \
  test "$(home_xvncs "$VH")" -eq 1
check "  ... and this page" test -n "$(ss -Htln "sport = :$PORT")"
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1
# A display that dies while its websockify lives on: the next 'vedabase web'
# (here under another spelling of the home) ends that websockify before the
# new display's record replaces the old one, and starts the viewer again.
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web-lost.out" 2>&1
kill -KILL "$(cat "$VH/run/web/xvnc.pid")"
for _ in $(seq 1 20); do [[ $(prefix_procs "$VH/prefix") -eq 0 ]] && break; sleep 0.5; done
VEDABASE_HOME=$VH/ VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web-lost-again.out" 2>&1
rc=$?
page=$(curl -s --noproxy '*' --max-time 5 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/vnc.html")
check "after its display died, 'vedabase web' starts the viewer again (exit $rc, HTTP $page)" test "$rc" -eq 0 -a "$page" = 200
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1
check "  ... and 'vedabase stop' then leaves no page and no display" \
  test -z "$(ss -Htln "sport = :$PORT")" -a "$(home_xvncs "$VH")" -eq 0
# websockify forks a copy of itself for each connection, and a copy can
# outlive its server (here killed outright while a connection is open),
# keeping the port where nothing answers any more: 'vedabase web' must not
# take it for the page's server.
ws_server() { # the websockify on $PORT that leads its session: its server
  local p
  for p in $(pgrep -u "$(id -u)" -x python3); do
    grep -qzxF -- "127.0.0.1:$PORT" "/proc/$p/cmdline" 2>/dev/null || continue
    [[ $(ps -o sid= -p "$p" | tr -d ' ') == "$p" ]] && echo "$p"
  done
}
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web-copy.out" 2>&1
sleep 5 # Folio opening, so that the viewer counts as running
# A WebSocket, as a browser opens one: its copy stays while the connection
# does (one that sends nothing is dropped after 3 s).
exec 7<>"/dev/tcp/127.0.0.1/$PORT"
printf 'GET /websockify HTTP/1.1\r\nHost: 127.0.0.1:%s\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Protocol: binary\r\n\r\n' \
  "$PORT" >&7
upgraded=''
IFS= read -r -t 3 upgraded <&7
server=$(ws_server)
check "  (a WebSocket is open, and websockify's server is found with a copy for it)" \
  test "${upgraded%$'\r'}" = 'HTTP/1.1 101 Switching Protocols' -a -n "$server" \
  -a "$(pgrep -u "$(id -u)" -x -P "${server:-0}" python3 | wc -l)" -ge 1
# shellcheck disable=SC2086 # one PID a word
kill -KILL $server
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web-copy-left.out" 2>&1
rc=$?
check "with only a connection's copy of websockify left, 'vedabase web' does not say the viewer runs" \
  test "$(grep -c 'already running' "$B/web-copy-left.out")" -eq 0
check "  ... but fails, saying to stop it first (exit $rc)" \
  test "$rc" -ne 0 -a "$(grep -c "vedabase stop" "$B/web-copy-left.out")" -ge 1
for ws in "$VH"/wine/*/bin/wineserver; do WINEPREFIX=$VH/prefix "$ws" -k 2>/dev/null; done
for _ in $(seq 1 20); do [[ $(prefix_procs "$VH/prefix") -eq 0 ]] && break; sleep 0.5; done
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web-copy-again.out" 2>&1
page=$(curl -s --noproxy '*' --max-time 5 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/vnc.html")
check "  ... and with Folio closed there, 'vedabase web' serves the page again (HTTP $page)" test "$page" = 200
exec 7>&-
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1
# One command at a time changes the viewer: one that finds another holding the
# lock (here the test, for 3 s) waits for it, and what 'vedabase web' leaves
# running (Xvnc, websockify, Wine) does not hold it.
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web-lock.out" 2>&1
check "what 'vedabase web' leaves running does not hold the lock" flock -n "$VH/run/lock" true
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1
# Timed with nothing left to stop, which takes no time of its own.
started=$SECONDS
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1
free=$((SECONDS - started))
flock "$VH/run/lock" sleep 6 &
holder=$!
sleep 0.5
started=$SECONDS
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1
took=$((SECONDS - started))
check "'vedabase stop' waits while another command holds the lock (${took} s; ${free} s when it is free)" \
  test "$took" -ge 4 -a "$free" -le 2
wait "$holder"
# A nudger held up past the end of its display must not cost the next display
# its own, even when the new display takes the old one's number.
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web5.out" 2>&1
first=$(<"$VH/run/web/display")
held=$(nudgers "$first")
check "  (a nudger to hold up is found)" test -n "$held"
# shellcheck disable=SC2086 # one PID a word
hold $held
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web6.out" 2>&1
echo "      display $first, then $(<"$VH/run/web/display")"
check "a nudger held up past its display's end leaves the next display one of its own" nudger_up
for p in $held; do kill -CONT "$p"; done
sleep 1
check "  ... which goes on once the held one ends" nudger_up
check "  ... and the held one does end" test -z "$(for p in $held; do kill -0 "$p" 2>/dev/null && echo "$p"; done)"
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1
# A display that stops answering (here its Xvnc held up with SIGSTOP) must not
# hang 'vedabase web' run again: it says so, and still gives the link.
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web7.out" 2>&1
xvnc=$(cat "$VH/run/web/xvnc.pid")
sleep 5 # Folio opening, so that the viewer counts as running
hold "$xvnc"
started=$SECONDS
VEDABASE_WEB_PORT=$PORT timeout 60 env HOME="$H" "$H/.local/bin/vedabase" web >"$B/web-stalled.out" 2>&1
took=$((SECONDS - started))
kill -CONT "$xvnc"
check "'vedabase web' facing a display that does not answer returns in time (${took} s)" test "$took" -le 15
check "  ... says copies will not reach the clipboard panel" grep -q "clipboard panel" "$B/web-stalled.out"
check "  ... and gives the link all the same" grep -q "localhost:$PORT/vnc.html" "$B/web-stalled.out"
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1

run "$H/.local/bin/vedabase" backup "$B/backup.tar.gz" >"$B/backup.log" 2>&1
check "backup succeeds" test $? -eq 0
check "the backup is private (0600)" test "$(stat -c %a "$B/backup.tar.gz")" = 600
run ./install.sh --home "$VH" --reinstall --restore "$B/backup.tar.gz" >"$B/restore.log" 2>&1
check "--reinstall --restore succeeds (log: $B/restore.log)" test $? -eq 0
check "no staging folder is left" test -z "$(compgen -G "$VH/restore.*")"
run "$H/.local/bin/vedabase" doctor >/dev/null 2>&1
check "doctor passes after the restore" test $? -eq 0

# A bad backup must cost nothing: the prefix it was meant to replace stays.
echo 'stands for your notes' >"$VH/prefix/drive_c/notes-marker.txt"
head -c 50000000 "$B/backup.tar.gz" >"$B/truncated.tar.gz"
tar -C "$B" -czf "$B/no-prefix.tar.gz" --files-from /dev/null
mkdir -p "$B/fake/prefix/drive_c" && tar -C "$B/fake" -czf "$B/unfinished.tar.gz" prefix
# Stamped as finished, yet missing the program and the infobase.
mkdir -p "$B/stamped/prefix/drive_c" && : >"$B/stamped/prefix/.vedabase-installed" &&
  tar -C "$B/stamped" -czf "$B/stamped.tar.gz" prefix
# Incomplete, with a folder it leaves unwritable once unpacked.
mkdir -p "$B/locked/prefix/drive_c/locked" && : >"$B/locked/prefix/drive_c/locked/f" &&
  chmod 555 "$B/locked/prefix/drive_c/locked" && tar -C "$B/locked" -czf "$B/unwritable.tar.gz" prefix &&
  chmod 755 "$B/locked/prefix/drive_c/locked"
# Every file a working install needs (a full-size infobase, sparse), but
# neither the stamp nor the VedaBase_25.nfo name of a finished install.
A="$B/unstamped/prefix/drive_c/Bhaktivedanta VedaBase 2003"
mkdir -p "$A/Nfo" && : >"$B/unstamped/prefix/system.reg" && : >"$B/unstamped/prefix/user.reg" && : >"$A/Views.exe" &&
  : >"$A/Nfo/Bhaktivedanta Vedabase 2003.sdw" && truncate -s 649011200 "$A/Nfo/Bhaktivedanta Vedabase 2003.nfo" &&
  tar -C "$B/unstamped" -czf "$B/unstamped.tar.gz" prefix && rm -rf -- "$B/unstamped"
for bad in truncated no-prefix unfinished stamped unwritable unstamped; do
  run ./install.sh --home "$VH" --reinstall --restore "$B/$bad.tar.gz" >"$B/restore-$bad.log" 2>&1
  check "a $bad backup is refused" test $? -ne 0
  check "after the $bad backup the existing prefix is still there" test -f "$VH/prefix/drive_c/notes-marker.txt"
done
check "no staging or set-aside folder is left" test -z "$(compgen -G "$VH/restore.*")$(compgen -G "$VH/prefix.before-restore-*")$(compgen -G "$VH/prefix.rejected-*")"
run "$H/.local/bin/vedabase" doctor >/dev/null 2>&1
check "doctor still passes" test $? -eq 0
finish
