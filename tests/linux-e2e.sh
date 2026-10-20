#!/usr/bin/env bash
# Linux end to end: a clean unattended install, doctor, permissions, the
# browser viewer (with CHROME_EXE set: it connects, survives six wrong
# passwords, takes typing), stop, and a backup -> --reinstall --restore round trip.
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

VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web.out" 2>&1
check "vedabase web starts" test $? -eq 0
url=$(grep -o "http://localhost:$PORT/vnc.html[^ ]*" "$B/web.out" | head -n1)
check "it prints the browser link" test -n "$url"
check "the web display has no failed-login lockout" grep -q -- '-UseBlacklist=0' "/proc/$(cat "$VH/run/web/xvnc.pid")/cmdline"
if [[ -n ${CHROME_EXE:-} ]]; then
  sleep 8
  python3 "$TESTS/novnc/lockout.py" "$url" "$B/web-after-wrong.png" >"$B/lockout.log" 2>&1
  check "six wrong passwords, then the right one connects (log: $B/lockout.log)" test $? -eq 0
  python3 "$TESTS/novnc/typing.py" "$url" "$B/web-typed.png" >"$B/typing.log" 2>&1
  check "typing through the browser reaches Folio (look at $B/web-typed.png)" test $? -eq 0
else
  echo "SKIP  browser checks (set CHROME_EXE to a Chromium for Playwright)"
fi
VEDABASE_WEB_PORT=$PORT run "$H/.local/bin/vedabase" web >"$B/web2.out" 2>&1
check "a second vedabase web gives the link again" grep -q 'already running' "$B/web2.out"
run "$H/.local/bin/vedabase" stop >/dev/null 2>&1
check "stop leaves no display running" test "$(home_xvncs "$VH")" -eq 0
check "stop leaves no Wine running" test "$(prefix_procs "$VH/prefix")" -eq 0

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
for bad in truncated no-prefix unfinished stamped unwritable; do
  run ./install.sh --home "$VH" --reinstall --restore "$B/$bad.tar.gz" >"$B/restore-$bad.log" 2>&1
  check "a $bad backup is refused" test $? -ne 0
  check "after the $bad backup the existing prefix is still there" test -f "$VH/prefix/drive_c/notes-marker.txt"
done
check "no staging or set-aside folder is left" test -z "$(compgen -G "$VH/restore.*")$(compgen -G "$VH/prefix.before-restore-*")$(compgen -G "$VH/prefix.rejected-*")"
run "$H/.local/bin/vedabase" doctor >/dev/null 2>&1
check "doctor still passes" test $? -eq 0
finish
