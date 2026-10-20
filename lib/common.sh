# shellcheck shell=bash
# Settings, paths and small helpers shared by install.sh and bin/vedabase.
# Callers set VB_REPO to the directory holding bin/ and lib/ before sourcing.

# --- pinned inputs ------------------------------------------------------------
# Kron4ek's portable Wine, WoW64 build: it runs 32-bit Windows programs without
# any i386 host libraries and needs no root. Stable branch, checksum from the
# GitHub release.
VB_WINE_NAME=wine-11.0-amd64-wow64
VB_WINE_URL=https://github.com/Kron4ek/Wine-Builds/releases/download/11.0/$VB_WINE_NAME.tar.xz
VB_WINE_SHA256=39574efa1132c3ca0d5c77dd2eddbe4a49cca0d6cc2c290ff4924493a1c40314

# Install.exe's default target; the shortcuts it writes point here.
VB_APP_WIN='C:\Bhaktivedanta VedaBase 2003'
VB_APP_REL='drive_c/Bhaktivedanta VedaBase 2003'

VB_CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/vedabase
VB_BIN_LINK=$HOME/.local/bin/vedabase
VB_APPS_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/applications

# --- messages -----------------------------------------------------------------
if [[ -t 2 ]]; then
  _vb_b=$'\e[1m' _vb_0=$'\e[0m' _vb_blue=$'\e[34m' _vb_yel=$'\e[33m' _vb_red=$'\e[31m'
else
  _vb_b='' _vb_0='' _vb_blue='' _vb_yel='' _vb_red=''
fi
vb_say()  { printf '%s==>%s %s\n' "$_vb_b$_vb_blue" "$_vb_0" "$*" >&2; }
vb_warn() { printf '%swarning:%s %s\n' "$_vb_b$_vb_yel" "$_vb_0" "$*" >&2; }
vb_die()  { printf '%serror:%s %s\n' "$_vb_b$_vb_red" "$_vb_0" "$*" >&2; exit 1; }

# --- locations ----------------------------------------------------------------
# VEDABASE_HOME holds everything large: Wine, the prefix, the downloads and the
# helper tools. On journel it defaults to the local NVMe disk, because $HOME
# there is a 40 GiB NFS quota and Wine handles file locking on NFS badly.
vb_default_home() {
  if [[ -d /journel/s0/$USER && -w /journel/s0/$USER ]]; then
    printf '%s\n' "/journel/s0/$USER/vedabase"
  else
    printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/vedabase"
  fi
}

# An explicit VEDABASE_HOME wins; otherwise the one install.sh recorded.
vb_init_paths() {
  if [[ -z ${VEDABASE_HOME:-} && -s $VB_CONFIG_DIR/home ]]; then
    VEDABASE_HOME=$(<"$VB_CONFIG_DIR/home")
  fi
  VB_HOME=${VEDABASE_HOME:-$(vb_default_home)}
  VB_PREFIX=$VB_HOME/prefix
  VB_DOWNLOADS=$VB_HOME/downloads
  VB_TOOLS=$VB_HOME/tools/root
  VB_RUN=$VB_HOME/run
  VB_LOGS=$VB_HOME/logs
  VB_WINE_DIR=$VB_HOME/wine/$VB_WINE_NAME
  VB_APP_DIR=$VB_PREFIX/$VB_APP_REL
}

# Environment for Wine and for the helper tools unpacked under $VB_TOOLS.
vb_env() {
  export WINEPREFIX=$VB_PREFIX
  export WINEDEBUG=${WINEDEBUG:--all}
  # No Mono/Gecko prompts, and no Wine-made host menu entries (we write our own).
  export WINEDLLOVERRIDES='mscoree,mshtml=;winemenubuilder.exe=d'
  export PATH=$VB_WINE_DIR/bin:$VB_TOOLS/usr/bin:$PATH
  # Set even before anything is unpacked there: packages fetched later in the
  # same run (xdotool's libxdo, say) must be found too.
  export LD_LIBRARY_PATH=$VB_TOOLS/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
}

vb_installed() { [[ -f $VB_APP_DIR/Views.exe ]]; }

# Wine processes that belong to this prefix (wineserver -k would also do, but
# this lets callers ask without starting a wineserver).
vb_prefix_pids() {
  local pid
  for pid in $(pgrep -u "$(id -u)" -f '\.exe|wineserver' 2>/dev/null); do
    grep -qzxF "WINEPREFIX=$VB_PREFIX" "/proc/$pid/environ" 2>/dev/null && printf '%s\n' "$pid"
  done
  return 0
}

# Ask the programs in the prefix to close, then make sure they are gone.
vb_wine_stop() {
  [[ -d $VB_PREFIX ]] || return 0
  [[ -n $(vb_prefix_pids) ]] || return 0
  timeout 20 wineboot --end-session --force >/dev/null 2>&1 || true
  timeout 20 wineserver -w >/dev/null 2>&1 || wineserver -k >/dev/null 2>&1 || true
}
