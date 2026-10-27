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

# Your own install's settings, as they are now: every test must leave them so.
_vb_cfg=${XDG_CONFIG_HOME:-$HOME/.config}/vedabase/home
_vb_apps=${XDG_DATA_HOME:-$HOME/.local/share}/applications
_vb_user_state() {
  cat -- "$_vb_cfg" "$_vb_apps/vedabase.desktop" "$_vb_apps/vanibase.desktop" "$_vb_apps/vedabase-unicode.desktop" \
    /usr/share/applications/vedabase.desktop /usr/share/applications/vanibase.desktop \
    /usr/share/applications/vedabase-unicode.desktop 2>/dev/null | cksum
}
_vb_user_before=$(_vb_user_state)

# Point every per-user location of the installers at H (the test's scratch
# HOME), so nothing reaches yours even where XDG_* are set.
isolate() { # H
  # The cache holds what 'vedabase unicode' converted last.
  export XDG_CONFIG_HOME=$1/.config XDG_DATA_HOME=$1/.local/share XDG_CACHE_HOME=$1/.cache
  # WSL: install.sh would copy its menu entries to /usr/share/applications.
  unset VEDABASE_HOME VEDABASE_SOURCE VEDABASE_INSTALL_DISPLAY WSL_DISTRO_NAME
}

fails=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; fails=$((fails + 1)); }
check() { # DESCRIPTION COMMAND...
  if "${@:2}"; then pass "$1"; else fail "$1"; fi
}
finish() {
  check "your own VedaBase settings and menu entries (yours and the system's) are unchanged" test "$(_vb_user_state)" = "$_vb_user_before"
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

# A private X display (TigerVNC's Xvnc, no network, no password: only this
# account can reach it). Sets DISPLAY and XAUTHORITY; stop_display ends it.
# Needs Xtigervnc and xauth, from VB_TEST_TOOLS or PATH.
start_display() { # DIR
  local d='' cookie
  mkdir -p "$1"; chmod 700 "$1"; : >"$1/xauth"; : >"$1/displayfd"
  cookie=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
  printf 'add :0 . %s\n' "$cookie" | xauth -q -f "$1/xauth" source -
  _vb_sock=$(mktemp -u /tmp/vedabase-test-XXXXXXXX.sock)
  setsid Xtigervnc -displayfd 3 3>"$1/displayfd" -auth "$1/xauth" -geometry 1024x768 -depth 24 \
    -rfbport -1 -localhost -rfbunixpath "$_vb_sock" -rfbunixmode 0600 -nolisten tcp -SecurityTypes None \
    >"$1/xvnc.log" 2>&1 </dev/null &
  _vb_xpid=$!
  for _ in $(seq 1 50); do d=$(tr -dc 0-9 <"$1/displayfd"); [[ -n $d ]] && break; sleep 0.2; done
  [[ -n $d ]] || return 1
  printf 'add :%s . %s\n' "$d" "$cookie" | xauth -q -f "$1/xauth" source -
  export DISPLAY=:$d XAUTHORITY=$1/xauth
}
stop_display() { kill "$_vb_xpid" 2>/dev/null; rm -f -- "$_vb_sock"; }
