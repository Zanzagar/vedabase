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

Running it accepts the Bhaktivedanta Archives license that Install.exe shows
(see "License" in README.md); it clicks Accept for you.

  --home DIR       where Wine, the prefix and the downloads go, about 3.5 GB
                   (default: $(vb_default_home))
  --source SRC     take the VedaBase files from SRC instead of Google Drive:
                   a directory, or host:dir over ssh, laid out like the Drive
                   folders (Install.exe, Fonts/, Nfo/, Spec/, VaniBase/)
  --restore FILE   unpack a prefix saved by 'vedabase backup' instead of
                   running Install.exe
  --name NAME      name to register in the installer (default: your full name)
  --no-vanibase    leave out VaniBase 25 (393 MB)
  --reinstall      delete the existing prefix first (your Folio notes and
                   highlights in it go too; 'vedabase backup' saves them)
EOF
}

need_value() { (($# >= 2)) || vb_die "$1 needs a value (see --help)"; }

name='' restore='' vanibase=1 reinstall=0 remote_re='^[^/:]+:'
while (($#)); do
  case $1 in
    --home)
      need_value "$@"
      VEDABASE_HOME=$(realpath -m -- "$2")
      export VEDABASE_HOME
      shift 2 ;;
    --source)
      need_value "$@"
      if [[ $2 =~ $remote_re ]]; then
        export VEDABASE_SOURCE=$2
      else
        [[ -d $2 ]] || vb_die "--source: no such directory: $2"
        VEDABASE_SOURCE=$(realpath -- "$2")
        export VEDABASE_SOURCE
      fi
      shift 2 ;;
    --restore)
      need_value "$@"
      [[ -f $2 ]] || vb_die "--restore: no such file: $2"
      restore=$(realpath -- "$2")
      shift 2 ;;
    --name) need_value "$@"; name=$2; shift 2 ;;
    --no-vanibase) vanibase=0; shift ;;
    --reinstall) reinstall=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ $EUID -ne 0 ]] || vb_die "run install.sh as yourself, without sudo; it asks for sudo itself only if it has to"
[[ $(uname -m) == x86_64 ]] || vb_die "needs an x86_64 Linux (this is $(uname -m))"
missing_tools=()
for t in curl:curl sha256sum:coreutils tar:tar xz:xz-utils python3:python3 pgrep:procps ps:procps ss:iproute2; do
  command -v "${t%%:*}" >/dev/null || missing_tools+=("${t#*:}")
done
((${#missing_tools[@]} == 0)) ||
  vb_die "some tools are missing; install them once with:  sudo apt-get install $(printf '%s\n' "${missing_tools[@]}" | sort -u | paste -sd' ')"

vb_init_paths
[[ -e $VB_HOME ]] || { mkdir -p "$VB_HOME" && chmod 700 "$VB_HOME"; } # notes and licensed files: yours only
[[ ! -e $VB_HOME/app || -e $VB_HOME/app/bin/vedabase ]] ||
  vb_die "$VB_HOME/app exists and is not VedaBase's; choose another --home"
mkdir -p "$VB_LOGS" "$VB_CONFIG_DIR"
printf '%s\n' "$VB_HOME" >"$VB_CONFIG_DIR/home"
trap 'rc=$?; ((rc == 0)) || vb_warn "install.sh did not finish; logs are in ${VB_LOGS:-}. Running it again continues where it stopped."' EXIT
vb_say "Installing into $VB_HOME"

skip_vani=''
((vanibase)) || skip_vani=VaniBase/
if [[ -z $restore ]] && ! vb_installed; then
  # Decide these before downloading 1.1 GB.
  [[ -n ${VEDABASE_INSTALL_DISPLAY:-} || -n ${DISPLAY:-} ]] || vb_can_run_xvnc ||
    vb_die "Install.exe needs a display. Run once:  sudo apt-get install x11-xkb-utils xkb-data  (or run this from a desktop session)"
  avail_kb=$(df -Pk "$VB_HOME" 2>/dev/null | awk 'NR == 2 {print $4}') || avail_kb=''
  [[ -z $avail_kb ]] || ((avail_kb >= 4 * 1024 * 1024)) ||
    vb_die "$VB_HOME needs about 4 GB free (it has $((avail_kb / 1024)) MB); choose another place with --home"
fi

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
  # Only the prefix: a backup must not be able to replace Wine or these scripts.
  tar -C "$VB_HOME" -xzf "$restore" prefix || vb_die "$restore is not a backup made by 'vedabase backup'"
  vb_installed || vb_die "$restore did not contain a finished install"
fi

if ! vb_installed; then
  vb_fetch_files '' "$skip_vani"
  vb_recover_prefix # finishes an interrupted install, or moves it aside
fi
if ! vb_installed; then
  saved_display=${DISPLAY-} saved_xauth=${XAUTHORITY-}
  # A private display keeps the wizard off your screen and the click offsets exact.
  if [[ -n ${VEDABASE_INSTALL_DISPLAY:-} ]]; then
    export DISPLAY=$VEDABASE_INSTALL_DISPLAY
    vb_ensure_pkgs deps xdotool
  elif vb_can_run_xvnc; then
    vb_display_start install 1600x1000 None
  else
    vb_warn "x11-xkb-utils is not installed, so the installer runs on your screen ($DISPLAY). Leave the mouse alone until it finishes."
    vb_ensure_pkgs deps xdotool
  fi
  [[ -n $name ]] || name=$(getent passwd "${USER:-$(id -un)}" | cut -d: -f5 | cut -d, -f1) || true
  vb_make_prefix
  vb_stage_installer
  vb_run_installer "${name:-${USER:-VedaBase reader}}"
  vb_check_install
  vb_postinstall
  vb_display_stop install
  if [[ -n $saved_display ]]; then export DISPLAY=$saved_display; else unset DISPLAY; fi
  if [[ -n $saved_xauth ]]; then export XAUTHORITY=$saved_xauth; else unset XAUTHORITY; fi
else
  vb_say "Folio Views is installed"
fi

if ((vanibase)); then
  vani=$VB_APP_DIR/Nfo/VaniBase_25.nfo
  if [[ ! -f $vani || ! -f $VB_APP_DIR/Nfo/VaniBase_25.sdw || $(vb_size "$vani") != "$(vb_manifest_size VaniBase/VaniBase_25.nfo)" ]]; then
    vb_fetch_files VaniBase/
    vb_add_vanibase
  fi
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
if ! command -v vedabase >/dev/null; then
  vb_warn "the 'vedabase' command works in new terminals after you log out and back in; until then use $VB_BIN_LINK"
fi
