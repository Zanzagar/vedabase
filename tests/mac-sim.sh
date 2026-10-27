#!/usr/bin/env bash
# macOS installer, simulated on Linux: mac/install.sh runs under a real bash 3.2
# with uname, sw_vers, open, sips, xattr and caffeinate shimmed, Linux Wine
# linked in where the Mac build goes, and a script clicking the wizard in a
# private display. The script never closes the Fonts window: the installer
# must close it itself. This proves the shell logic, not macOS.
set -u
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
: "${VB_TEST_BASH32:?set VB_TEST_BASH32 to a bash 3.2 binary (see tests/README.md)}"
for t in Xtigervnc xdotool xauth; do
  PATH=$VB_TEST_TOOLS/usr/bin:$PATH command -v "$t" >/dev/null || { echo "no $t in VB_TEST_TOOLS=$VB_TEST_TOOLS or on PATH"; exit 2; }
done
[[ -x $VB_TEST_WINE/bin/wine ]] || { echo "no Wine at VB_TEST_WINE=$VB_TEST_WINE"; exit 2; }
B=$VB_TEST_WORK/mac-sim H=$B/home S=$B/shims
rm -rf -- "$B"; mkdir -p "$H" "$S"; chmod 700 "$B"
isolate "$H"
VBH="$H/Library/Application Support/VedaBase"
R="$VBH/wine/Wine Stable.app/Contents/Resources"
mkdir -p "$R" && ln -s "$VB_TEST_WINE" "$R/wine"

# macOS commands the installer calls (single quotes: these are the shims' own text)
# shellcheck disable=SC2016
printf '#!/bin/bash\ncase "${1:-}" in -s) echo Darwin ;; -m) echo x86_64 ;; *) /usr/bin/uname "$@" ;; esac\n' >"$S/uname"
printf '#!/bin/bash\necho 15.1\n' >"$S/sw_vers"
printf '#!/bin/bash\nexit 0\n' >"$S/caffeinate"
for t in open sips xattr osascript; do printf '#!/bin/bash\necho "%s $*" >>"%s/calls.log"\n' "$t" "$B" >"$S/$t"; done
# The pasteboard is a file here.
printf '#!/bin/bash\ncat -- "%s/pasteboard" 2>/dev/null || true\n' "$B" >"$S/pbpaste"
printf '#!/bin/bash\ncat >"%s/pasteboard"\n' "$B" >"$S/pbcopy"
chmod +x "$S"/*

export PATH=$VB_TEST_TOOLS/usr/bin:$PATH LD_LIBRARY_PATH=$VB_TEST_TOOLS/usr/lib/x86_64-linux-gnu
X=$B/x; mkdir -p "$X"; chmod 700 "$X"; : >"$X/xauth"; : >"$X/displayfd"
cookie=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
printf 'add :0 . %s\n' "$cookie" | xauth -q -f "$X/xauth" source -
sock=$(mktemp -u /tmp/vedabase-test-XXXXXXXX.sock)
setsid Xtigervnc -displayfd 3 3>"$X/displayfd" -auth "$X/xauth" -geometry 1600x1000 -depth 24 -dpi 96 \
  -rfbport -1 -localhost -rfbunixpath "$sock" -rfbunixmode 0600 -nolisten tcp -SecurityTypes None \
  >"$X/xvnc.log" 2>&1 </dev/null &
xpid=$!
for _ in $(seq 1 50); do d=$(tr -dc 0-9 <"$X/displayfd"); [[ -n $d ]] && break; sleep 0.2; done
printf 'add :%s . %s\n' "$d" "$cookie" | xauth -q -f "$X/xauth" source -
export DISPLAY=:$d XAUTHORITY=$X/xauth

clicker() { # the user, minus closing the Fonts window
  local wid title
  # shellcheck source=../lib/common.sh
  source "$REPO/lib/common.sh"
  # shellcheck source=../lib/setup.sh
  source "$REPO/lib/setup.sh"
  while :; do
    while IFS=$'\t' read -r wid title; do
      case $title in
        'User Information') vb_click "$wid" "${VB_XY_NAME[@]}"; xdotool type --delay 20 -- 'Mac Tester'; xdotool key Return ;;
        'Select Install Type') vb_click "$wid" "${VB_XY_CUSTOM[@]}"; vb_press "$wid" Return ;;
        'Select Packages') vb_click "$wid" "${VB_XY_PKG1[@]}"; vb_click "$wid" "${VB_XY_PKG2[@]}"; vb_press "$wid" Return ;;
        'Pre-Install' | 'License Agreement' | 'Important Information' | 'Install Folder' | 'Shortcut Folder' | \
          'Ready to Install' | 'VedaBase Icons' | 'WinAmp Install' | 'Finished') vb_press "$wid" Return ;;
        'Notice' | 'Error') vb_press "$wid" Escape ;;
        *) continue ;;
      esac
      echo "clicked: $title"
      vb_wait_change "$wid" "$title" 20 || true
      break
    done < <(vb_windows)
    sleep 1
  done
}
clicker >"$B/clicker.log" 2>&1 &
cpid=$!

cd "$REPO" || exit 1
srcenv=()
[[ -z $VB_TEST_SOURCE ]] || srcenv=(VEDABASE_SOURCE="$VB_TEST_SOURCE")
env HOME="$H" PATH="$S:$PATH" "${srcenv[@]}" "$VB_TEST_BASH32" mac/install.sh >"$B/install.log" 2>&1
check "mac/install.sh succeeds with the Fonts window left open (log: $B/install.log)" test $? -eq 0
kill "$cpid" 2>/dev/null
check "nothing is left running in the prefix" test "$(prefix_procs "$VBH/prefix")" -eq 0
check "the install is stamped" test -f "$VBH/prefix/.vedabase-installed"
check "the prefix is private (0700)" test "$(stat -c %a "$VBH/prefix")" = 700
for app in 'VedaBase 25' 'VaniBase 25'; do
  check "$app.app has its Info.plist and launcher" test -f "$H/Applications/$app.app/Contents/Info.plist" -a -x "$H/Applications/$app.app/Contents/MacOS/launch"
done
check "it opens VedaBase 25 at the end" grep -q 'open .*VedaBase 25.app' "$B/calls.log"

# VedaBase Unicode: copy in VedaBase, click the app, and the pasteboard holds Unicode.
U="$H/Applications/VedaBase Unicode.app/Contents/MacOS/launch"
check "VedaBase Unicode.app has its Info.plist and launcher" test -f "$H/Applications/VedaBase Unicode.app/Contents/Info.plist" -a -x "$U"
check "  ... which runs the converter's copy in the VedaBase home" grep -qF "$(printf '%q' "$VBH/app/bin/vedabase-unicode")" "$U"
printf 'Çré Kåñëa' >"$B/pasteboard"
env HOME="$H" PATH="$S:$PATH" bash "$U" >"$B/unicode-app.log" 2>&1
check "clicking it turns the pasteboard's 'Çré Kåñëa' into 'Śrī Kṛṣṇa'" test "$(cat "$B/pasteboard")" = 'Śrī Kṛṣṇa'
check "  ... and a dialog says so" grep -q 'osascript .*Converted to Unicode' "$B/calls.log"
check "  ... and it remembers what it converted, in ~/Library/Caches" test -s "$H/Library/Caches/VedaBase/unicode-last"
printf 'yajïa' >"$B/pasteboard"
env HOME="$H" PATH="$S:$PATH" "$VB_TEST_BASH32" "$VBH/app/bin/vedabase-unicode" >>"$B/unicode-app.log" 2>&1
check "under bash 3.2 too: 'yajïa' becomes 'yajña'" test "$(cat "$B/pasteboard")" = 'yajña'
env HOME="$H" PATH="$S:$PATH" "$VB_TEST_BASH32" "$VBH/app/bin/vedabase-unicode" >>"$B/unicode-app.log" 2>&1
check "  ... and a second click does not make 'yajṣa' of it (status $?)" test "$(cat "$B/pasteboard")" = 'yajña'
env HOME="$H" PATH="$S:$PATH" "${srcenv[@]}" "$VB_TEST_BASH32" mac/install.sh >"$B/rerun.log" 2>&1
check "a re-run on the finished install succeeds" test $? -eq 0
kill "$xpid" 2>/dev/null
rm -f -- "$sock"
finish
