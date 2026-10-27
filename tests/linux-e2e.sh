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
nudging() { # does the viewer's nudger run? It holds its lock while it does.
  flock -n -E 3 "$VH/run/web/nudge.lock" true 2>/dev/null
  test $? -eq 3
}
check "the browser viewer runs a nudger for Wine's copies" nudging
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
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1
check "stop leaves no display running" test "$(home_xvncs "$VH")" -eq 0
check "stop leaves no Wine running" test "$(prefix_procs "$VH/prefix")" -eq 0
nudging
check "stop ends the nudger" test $? -ne 0
check "  ... and leaves a process that only names it alone" kill -0 "$decoy"
kill "$decoy"; wait "$decoy" 2>/dev/null

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
