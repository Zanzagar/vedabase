#!/usr/bin/env bash
# The Linux installer's wizard driver (vb_run_installer in lib/setup.sh) with
# Wine and X faked; no install needed. A scripted wizard shows its windows, and
# a key moves it on unless the window is stuck. Through to the end; a restart
# notice that will not close after 'Finished' (as on WSLg) ends the wizard, but
# not before 'Finished', not while an Error shows too, whichever window comes
# first, and not when the windows cannot all be read.
set -u
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
B=$VB_TEST_WORK/wizard
rm -rf -- "$B"; mkdir -p "$B"; chmod 700 "$B"

PAGES='Pre-Install;License Agreement;User Information;Important Information;Select Install Type;Select Packages;Install Folder;Shortcut Folder;Ready to Install;VedaBase Icons;WinAmp Install;Finished'

# [FAULT=search|title] wizard NAME STEPS...: run vb_run_installer against
# STEPS, in a subshell. A step lists the windows showing, ';' between them; '!'
# before a step means a key does not move it on. Prints the outcome to
# $B/NAME.out, returns its status.
wizard() {
  local name=$1
  shift
  (
    set -u
    VB_HOME=$B/$name VB_PREFIX=$B/$name/prefix VB_LOGS=$B/$name/logs
    mkdir -p "$VB_PREFIX/drive_c" "$VB_LOGS"
    # shellcheck source=../lib/common.sh
    source "$REPO/lib/common.sh"
    # shellcheck source=../lib/setup.sh
    source "$REPO/lib/setup.sh"
    steps=("$@") i=0
    vb_windows() { # the current step's windows, numbered from 100
      local w n=100 s=${steps[i]:-}
      s=${s#!}
      [[ -n $s ]] || return 0
      while IFS= read -r w; do printf '%s\t%s\n' "$n" "$w"; n=$((n + 1)); done <<<"${s//;/$'\n'}"
    }
    vb_press() { [[ ${steps[i]:-} == '!'* ]] || i=$((i + 1)); }
    vb_installer_running() { ((i < ${#steps[@]})); }
    vb_click() { :; }
    vb_wait_change() { :; }
    vb_say() { :; }
    vb_die() { printf 'died: %s\n' "$*"; exit 1; }
    vb_space_filler_add() { :; }
    sleep() { :; }
    setsid() { :; }
    # The real vb_window_titles asks xdotool; it answers from the step, or
    # fails as FAULT says (search, or title).
    fault=${FAULT:-}
    xdotool() {
      case $1 in
        search) [[ $fault != search ]] || return 1; vb_windows | cut -f1 ;;
        getwindowname) [[ $fault != title ]] || return 1; vb_windows | awk -F'\t' -v w="$2" '$1 == w { print $2 }' ;;
      esac
    }
    wineserver() { :; }
    wineboot() { :; }
    vb_run_installer 'A Tester'
    printf 'finished: %s\n' "$(tail -n1 "$VB_LOGS/installer.log")"
  ) >"$B/$name.out" 2>&1
}
pages() { local IFS=';'; read -ra p <<<"$PAGES"; printf '%s\n' "${p[@]}"; }
mapfile -t page_steps < <(pages)

wizard plain "${page_steps[@]}" 'Notice' 'Notice'
check "every page answered, then both restart notices: the wizard ends" test $? -eq 0

wizard stuck-notice "${page_steps[@]}" '!Notice;Fonts'
check "a restart notice that will not close after 'Finished' ends the wizard (as on WSLg)" test $? -eq 0
check "  and the log says it was left open" grep -qx 'Notice left open: the install had finished' "$B/stuck-notice/logs/installer.log"

wizard early-notice 'Pre-Install' '!Notice'
check "a notice that will not close before 'Finished' stops the install" test $? -ne 0
check "  naming it" grep -q "stalled at screen 'Notice'" "$B/early-notice.out"

wizard notice-error "${page_steps[@]}" '!Notice;Error'
check "a stuck notice with an Error showing too stops the install" test $? -ne 0
check "  naming the Error" grep -q "stalled at screen 'Error'" "$B/notice-error.out"

wizard error-notice "${page_steps[@]}" '!Error;Notice'
check "so it does with the Error listed first" test $? -ne 0
check "  naming the Error" grep -q "stalled at screen 'Error'" "$B/error-notice.out"

FAULT=search wizard scan-fails "${page_steps[@]}" '!Notice;Fonts'
check "a stuck notice whose windows cannot be listed stops the install" test $? -ne 0
FAULT=title wizard title-fails "${page_steps[@]}" '!Notice;Error'
check "so does one whose windows' titles cannot be read" test $? -ne 0
check "  naming the notice" grep -q "stalled at screen 'Notice'" "$B/title-fails.out"

wizard stuck-page 'Pre-Install' '!License Agreement'
check "any other page that will not move on stops the install" test $? -ne 0
finish
