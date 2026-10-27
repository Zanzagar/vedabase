#!/usr/bin/env bash
# Interrupted installs. install.sh runs in its own session with SIGINT and
# SIGHUP at their defaults, as from a terminal, and is signalled once the
# wizard reaches "Install Folder": Ctrl-C (SIGINT) and a closed terminal
# (SIGHUP) must leave nothing running; after SIGKILL, which nothing can catch,
# the re-run must clean up. Every re-run must finish the install.
set -u
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
B=$VB_TEST_WORK/interrupt H=$B/home VH=$B/vb
rm -rf -- "$B"; mkdir -p "$H"; chmod 700 "$B"
isolate "$H"
mapfile -t src < <(source_args)
cd "$REPO" || exit 1

interrupt() { # SIGNAL INSTALL-ARGS...: start install.sh, signal its process group mid-wizard
  local sig=$1 pg i
  shift
  rm -f -- "$VH/logs/installer.log"
  HOME=$H python3 -I -c 'import os, signal, sys
signal.signal(signal.SIGINT, signal.SIG_DFL); signal.signal(signal.SIGHUP, signal.SIG_DFL)
os.setsid(); os.execvp(sys.argv[1], sys.argv[1:])' ./install.sh --home "$VH" "${src[@]}" "$@" >>"$B/install.log" 2>&1 &
  pg=$!
  for i in $(seq 1 900); do
    grep -qx 'Install Folder' "$VH/logs/installer.log" 2>/dev/null && break
    kill -0 "$pg" 2>/dev/null || break
    sleep 1
  done
  kill -"$sig" -- -"$pg" 2>/dev/null
  wait "$pg"
  rc=$?
}
# Nothing of the install running: no Wine in its prefix, no hidden display.
idle() { test "$(prefix_procs "$VH/prefix")" -eq 0 -a "$(home_xvncs "$VH")" -eq 0; }
# Idle within 20 s: the clean-up after a signal takes a moment (once in six
# runs, more than the 3 s this test used to allow).
settles() { for _ in $(seq 1 40); do idle && return 0; sleep 0.5; done; return 1; }
rerun() { # DESCRIPTION
  HOME=$H ./install.sh --home "$VH" "${src[@]}" >>"$B/install.log" 2>&1
  check "$1: the re-run finishes the install" test $? -eq 0
  check "$1: the re-run leaves nothing running" idle
}

interrupt INT
check "Ctrl-C stops install.sh (exit $rc)" test "$rc" -ne 0
check "Ctrl-C leaves no wizard or display running" settles
rerun "after Ctrl-C"

interrupt HUP --reinstall
check "a closed terminal stops install.sh (exit $rc)" test "$rc" -ne 0
check "a closed terminal leaves no wizard or display running" settles
rerun "after SIGHUP"

interrupt KILL --reinstall
check "SIGKILL leaves the wizard behind (as it must; the re-run cleans up)" test "$(prefix_procs "$VH/prefix")" -gt 0
rerun "after SIGKILL"

HOME=$H "$H/.local/bin/vedabase" doctor >/dev/null 2>&1
check "doctor passes at the end" test $? -eq 0
echo "(prefixes moved aside along the way: $(compgen -G "$VH/prefix.unfinished-*" | wc -l); log: $B/install.log)"
finish
