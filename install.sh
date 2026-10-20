#!/usr/bin/env bash
# Install the Bhaktivedanta VedaBase desktop client (Folio Views 4.3, VedaBase 25
# and VaniBase 25) on Linux or WSL, under a pinned portable Wine. No root needed.
# Safe to re-run: finished steps are skipped, so it doubles as "update/repair".
set -euo pipefail

VB_REPO=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)
for f in common deps fetch display setup; do
  # shellcheck source=/dev/null
  source "$VB_REPO/lib/$f.sh"
done

usage() {
  cat <<EOF
Usage: ./install.sh [OPTIONS]

  --home DIR       where Wine, the prefix and the downloads go
                   (default: $(vb_default_home))
  --source SRC     take the VedaBase files from SRC instead of Google Drive:
                   a directory or host:dir laid out like the Drive folders,
                   e.g. you@server:/path/to/vedabase/downloads
  --restore FILE   unpack a prefix saved by 'vedabase backup' instead of
                   running Install.exe
  --name NAME      name to register in the installer (default: your full name)
  --no-vanibase    leave out VaniBase 25 (393 MB)
  --reinstall      delete the existing prefix first (your Folio notes and
                   highlights in it go too; 'vedabase backup' saves them)
EOF
}

name='' restore='' vanibase=1 reinstall=0
while (($#)); do
  case $1 in
    --home) export VEDABASE_HOME=$2; shift 2 ;;
    --source) export VEDABASE_SOURCE=$2; shift 2 ;;
    --restore) restore=$(readlink -f -- "$2"); shift 2 ;;
    --name) name=$2; shift 2 ;;
    --no-vanibase) vanibase=0; shift ;;
    --reinstall) reinstall=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ $(uname -m) == x86_64 ]] || vb_die "needs an x86_64 Linux (this is $(uname -m))"
for tool in curl sha256sum tar xz python3; do
  command -v "$tool" >/dev/null || vb_die "missing '$tool' (sudo apt-get install $tool)"
done

vb_init_paths
mkdir -p "$VB_HOME" "$VB_LOGS" "$VB_CONFIG_DIR"
printf '%s\n' "$VB_HOME" >"$VB_CONFIG_DIR/home"
vb_say "Installing into $VB_HOME"

vb_ensure_pkgs deps "${VB_PKGS_WINE[@]}"
# Private displays: for running Install.exe unseen, and for 'vedabase web'.
if vb_can_run_xvnc; then
  vb_ensure_pkgs deps "${VB_PKGS_DISPLAY[@]}"
  vb_ensure_pkgs nodeps "${VB_PKGS_WEB[@]}"
fi
vb_ensure_wine
vb_env

if ((reinstall)) && [[ -d $VB_PREFIX ]]; then
  vb_wine_stop
  vb_say "Removing the old prefix"
  rm -rf -- "$VB_PREFIX"
fi

if [[ -n $restore ]]; then
  [[ ! -e $VB_PREFIX ]] || vb_die "$VB_PREFIX already exists; add --reinstall to replace it"
  vb_say "Restoring the prefix from $restore"
  tar -C "$VB_HOME" -xzf "$restore"
  vb_installed || vb_die "$restore did not contain an installed prefix"
fi

if ! vb_installed; then
  [[ ! -e $VB_PREFIX ]] || vb_die "$VB_PREFIX exists but holds no finished install; re-run with --reinstall"
  vb_fetch_files
  saved_display=${DISPLAY-} saved_xauth=${XAUTHORITY-}
  # A private display keeps the wizard off your screen and the click offsets exact.
  if [[ -n ${VEDABASE_INSTALL_DISPLAY:-} ]]; then
    export DISPLAY=$VEDABASE_INSTALL_DISPLAY
    vb_ensure_pkgs deps xdotool
  elif vb_can_run_xvnc; then
    vb_display_start install 1600x1000 None
  elif [[ -n ${DISPLAY:-} ]]; then
    vb_warn "x11-xkb-utils is not installed, so the installer runs on your screen ($DISPLAY). Leave the mouse alone until it finishes."
    vb_ensure_pkgs deps xdotool
  else
    vb_die "no display to run Install.exe on: sudo apt-get install x11-xkb-utils, or run this from a desktop session"
  fi
  [[ -n $name ]] || name=$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)
  vb_make_prefix
  vb_stage_installer
  vb_run_installer "${name:-$USER}"
  vb_check_install
  vb_postinstall
  vb_display_stop install
  if [[ -n $saved_display ]]; then export DISPLAY=$saved_display; else unset DISPLAY; fi
  if [[ -n $saved_xauth ]]; then export XAUTHORITY=$saved_xauth; else unset XAUTHORITY; fi
elif [[ -z $restore ]]; then
  vb_say "Folio Views is already installed; checking the rest"
  vb_fetch_files
fi

# A restored prefix may already carry VaniBase with no download beside it.
if ((vanibase)) && ! [[ -f $VB_APP_DIR/Nfo/VaniBase_25.nfo && ! -f $VB_DOWNLOADS/VaniBase/VaniBase_25.nfo ]]; then
  vb_fetch_files VaniBase/
  vb_add_vanibase
fi

# The launcher runs from a copy under VEDABASE_HOME, so moving or deleting this
# checkout does not break it; re-running install.sh refreshes the copy.
rm -rf -- "$VB_HOME/app"
mkdir -p "$VB_HOME/app" "$(dirname -- "$VB_BIN_LINK")"
cp -r -- "$VB_REPO/bin" "$VB_REPO/lib" "$VB_HOME/app/"
ln -sfn -- "$VB_HOME/app/bin/vedabase" "$VB_BIN_LINK"

# Menu entries for Linux desktops.
mkdir -p "$VB_APPS_DIR" "$VB_HOME/icons"
python3 -I "$VB_REPO/lib/ico2png.py" "$VB_APP_DIR/vedabase.ico" "$VB_HOME/icons/vedabase.png" ||
  vb_warn "could not convert the VedaBase icon; the menu entries will have none"
desktop_entry() { # FILE NAME INFOBASE COMMENT
  cat >"$VB_APPS_DIR/$1" <<EOF
[Desktop Entry]
Type=Application
Name=$2
Comment=$4
Exec=$VB_BIN_LINK open $3
Icon=$VB_HOME/icons/vedabase.png
Terminal=false
Categories=Education;Literature;
StartupWMClass=views.exe
EOF
}
desktop_entry vedabase.desktop 'VedaBase 25' vedabase "Bhaktivedanta VedaBase: Śrīla Prabhupāda's complete teachings"
if ((vanibase)); then
  desktop_entry vanibase.desktop 'VaniBase 25' vanibase 'VaniBase: works by other devotees'
else
  rm -f -- "$VB_APPS_DIR/vanibase.desktop"
fi
if command -v update-desktop-database >/dev/null; then
  update-desktop-database -q "$VB_APPS_DIR" 2>/dev/null || true
fi
# WSLg mirrors menu entries into the Windows Start menu, but only from system
# folders such as /usr/share/applications, never from ~/.local/share.
if [[ -n ${WSL_DISTRO_NAME:-} ]]; then
  wsl_entries=("$VB_APPS_DIR/vedabase.desktop")
  ((vanibase)) && wsl_entries+=("$VB_APPS_DIR/vanibase.desktop")
  if sudo -n true 2>/dev/null; then
    sudo install -m 0644 "${wsl_entries[@]}" /usr/share/applications/
    vb_say "Added Start-menu entries (Start > $WSL_DISTRO_NAME)"
  else
    vb_say "For Windows Start-menu entries, run once:  sudo install -m 0644 ${wsl_entries[*]} /usr/share/applications/"
  fi
fi

"$VB_BIN_LINK" doctor || vb_die "the installation check failed (see above)"
cat <<EOF

Done. Open it with:
  vedabase              (a window here if you have a display, else the browser viewer)
  vedabase vanibase     (VaniBase 25)
  vedabase web          (headless: prints the SSH tunnel and browser link)
EOF
command -v vedabase >/dev/null || vb_warn "$(dirname -- "$VB_BIN_LINK") is not on PATH yet; open a new terminal or run $VB_BIN_LINK"
