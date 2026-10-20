# shellcheck shell=bash
# Shared by the test scripts. They install into scratch folders under
# VB_TEST_WORK, with HOME pointed there too, so your own install, launcher and
# ~/.config/vedabase are never touched. See tests/README.md.

TESTS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO=$(dirname -- "$TESTS")
: "${VB_TEST_WORK:?set VB_TEST_WORK to a scratch folder with about 4 GB free per install}"
# A copy of the Drive files, laid out like the folders (Install.exe, Fonts/,
# Nfo/, Spec/, VaniBase/), spares Google Drive; unset, the tests download.
VB_TEST_SOURCE=${VB_TEST_SOURCE:-}
# An existing install lends its unpacked tools (Xvnc, xdotool) and its Wine.
_vb_home=$(cat "${XDG_CONFIG_HOME:-$HOME/.config}/vedabase/home" 2>/dev/null) || _vb_home=''
VB_TEST_TOOLS=${VB_TEST_TOOLS:-$_vb_home/tools/root}
VB_TEST_WINE=${VB_TEST_WINE:-$_vb_home/wine/wine-11.0-amd64-wow64}

fails=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; fails=$((fails + 1)); }
check() { # DESCRIPTION COMMAND...
  if "${@:2}"; then pass "$1"; else fail "$1"; fi
}
finish() {
  if ((fails)); then printf '\n%s check(s) failed\n' "$fails"; exit 1; fi
  printf '\nall checks passed\n'
}

source_args() { [[ -z $VB_TEST_SOURCE ]] || printf '%s\n' --source "$VB_TEST_SOURCE"; }

# Processes of this user running in PREFIX (Wine sets WINEPREFIX in each).
prefix_procs() { # PREFIX
  local p n=0
  for p in $(pgrep -u "$(id -u)" -f '\.exe|wineserver'); do
    grep -qzxF "WINEPREFIX=$1" "/proc/$p/environ" 2>/dev/null && n=$((n + 1))
  done
  echo "$n"
}
# Xvnc servers started for the VEDABASE_HOME given (their -auth file is in it).
home_xvncs() { pgrep -u "$(id -u)" -f "Xtigervnc.*-auth $1/" | wc -l; }
