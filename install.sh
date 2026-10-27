#!/usr/bin/env bash
# Install the Bhaktivedanta VedaBase desktop client (Folio Views 4.3, VedaBase 25
# and VaniBase 25) on Linux or WSL, under a pinned portable Wine. It runs as you;
# root is needed only for the one-time apt-get of the tools the README lists.
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
                   running Install.exe (only a backup you made yourself: it
                   holds programs that will run as you)
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
for t in curl:curl sha256sum:coreutils tar:tar xz:xz-utils python3:python3 pgrep:procps ps:procps ss:iproute2 \
  flock:util-linux; do
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
# Removes a folder this script made, even one a backup left unwritable.
force_remove() { chmod -R u+w -- "$1" 2>/dev/null; rm -rf -- "$1" 2>/dev/null; }
in_wizard=0 # set while the hidden display and the wizard run
on_exit() { # each step on its own: one that fails must not stop the next
  local rc=$?
  ((rc == 0)) && return
  if ((in_wizard)); then # leave nothing running in the background
    wineserver -k >/dev/null 2>&1 || true
    vb_display_stop install >/dev/null 2>&1 || true
  fi
  # A restore cut short puts back the prefix it was replacing, by renaming
  # only; deleting comes after, and may fail without harm.
  if [[ -n ${old_prefix:-} && -d $old_prefix ]]; then
    if [[ -e $VB_PREFIX ]]; then mv -T -- "$VB_PREFIX" "$VB_PREFIX.rejected-$$" 2>/dev/null || true; fi
    if mv -T -- "$old_prefix" "$VB_PREFIX" 2>/dev/null; then
      force_remove "$VB_PREFIX.rejected-$$" || true
    else
      vb_warn "your previous prefix is in $old_prefix; move it back to $VB_PREFIX" || true
    fi
  fi
  if [[ -n ${stage:-} && -d $stage ]]; then force_remove "$stage" || true; fi
  vb_warn "install.sh did not finish; logs are in ${VB_LOGS:-}. Running it again continues where it stopped."
}
trap on_exit EXIT
# Without these, Ctrl-C or a closed terminal ends the script without the EXIT trap.
trap 'exit 130' INT
trap 'exit 129' HUP
trap 'exit 143' TERM
vb_say "Installing into $VB_HOME"

skip_vani=''
((vanibase)) || skip_vani=VaniBase/
if [[ -z $restore ]] && { ((reinstall)) || ! vb_installed; }; then
  # Decide these before downloading 1.1 GB, or deleting the prefix. The space
  # an old prefix frees for --reinstall is counted as what is already there.
  [[ -n ${VEDABASE_INSTALL_DISPLAY:-} || -n ${DISPLAY:-} ]] || vb_can_run_xvnc ||
    vb_die "Install.exe needs a display. Run once:  sudo apt-get install x11-xkb-utils xkb-data  (or run this from a desktop session)"
  # About 4 GB in all, less whatever an earlier run already put here.
  have_kb=$(du -sk "$VB_HOME/wine" "$VB_DOWNLOADS" "$VB_PREFIX" 2>/dev/null | awk '{s += $1} END {print s + 0}') ||
    true # du fails on the folders a fresh install has not made yet; awk still sums the rest
  need_kb=$((4 * 1024 * 1024 - have_kb))
  avail_kb=$(df -Pk "$VB_HOME" 2>/dev/null | awk 'NR == 2 {print $4}') || avail_kb=''
  [[ -z $avail_kb ]] || ((avail_kb >= need_kb)) ||
    vb_die "$VB_HOME needs about $((need_kb / 1024)) MB more free space (it has $((avail_kb / 1024)) MB); choose another place with --home"
fi

vb_ensure_pkgs deps "${VB_PKGS_WINE[@]}"
vb_ensure_pkgs deps "${VB_PKGS_CLIP[@]}"
# Private displays: for running Install.exe unseen, and for 'vedabase web'.
if vb_can_run_xvnc; then
  vb_ensure_pkgs deps "${VB_PKGS_DISPLAY[@]}"
  vb_ensure_pkgs nodeps "${VB_PKGS_WEB[@]}"
fi
vb_ensure_wine
vb_env

if ((reinstall)) && [[ -d $VB_PREFIX ]]; then
  [[ -f $VB_PREFIX/system.reg || -d $VB_PREFIX/drive_c || -z $(ls -A -- "$VB_PREFIX") ]] ||
    vb_die "$VB_PREFIX is not a Wine prefix, so it is not deleted; move it away and run again"
fi

# A prefix fit to restore: a finished install (as vb_installed sees one) that
# also holds the program, the whole infobase, its shadow file and Wine's
# registry, since a stamp alone proves nothing about a backup.
prefix_complete() { # DIR
  local app=$1/$VB_APP_REL
  [[ -f $1/.vedabase-installed || (-e $app/Nfo/VedaBase_25.nfo && ! -L $1/drive_c/Install.exe) ]] &&
    [[ -f $1/system.reg && -f $1/user.reg && -f $app/Views.exe &&
      -f "$app/Nfo/Bhaktivedanta Vedabase 2003.sdw" && -f "$app/Nfo/$VB_MASTER_NFO" &&
      $(vb_size "$app/Nfo/$VB_MASTER_NFO") == "$VB_MASTER_SIZE" ]]
}

stage='' old_prefix=''
if [[ -n $restore ]]; then
  [[ ! -e $VB_PREFIX ]] || ((reinstall)) || vb_die "$VB_PREFIX already exists; add --reinstall to replace it"
  # Unpacked aside and only its prefix/ kept: a backup must not be able to
  # replace Wine, the helper tools or these scripts. It is checked before
  # anything is replaced, so a wrong or damaged file costs nothing.
  vb_say "Unpacking $restore"
  stage=$(mktemp -d "$VB_HOME/restore.XXXXXX")
  if ! tar -C "$stage" -xzf "$restore" || [[ ! -d $stage/prefix || -L $stage/prefix ]] || ! prefix_complete "$stage/prefix"; then
    vb_die "$restore is not a complete backup made by 'vedabase backup'; nothing was changed"
  fi
fi

if ((reinstall)) && [[ -d $VB_PREFIX ]]; then
  vb_wine_stop
  if [[ -n $restore ]]; then # renamed, so that it comes back if the swap is cut short
    old_prefix=$VB_PREFIX.before-restore-$(date +%Y%m%d-%H%M%S)
    mv -T -- "$VB_PREFIX" "$old_prefix"
  else
    vb_say "Removing the old prefix"
    rm -rf -- "$VB_PREFIX"
  fi
fi

if [[ -n $restore ]]; then
  vb_say "Restoring the prefix from $restore"
  mv -T -- "$stage/prefix" "$VB_PREFIX"
  replaced=$old_prefix old_prefix='' # restored: nothing to roll back from here
  force_remove "$stage" || vb_warn "could not remove $stage; delete it by hand"
  stage=''
  if [[ -n $replaced ]]; then
    force_remove "$replaced" || vb_warn "could not remove the replaced prefix $replaced; delete it by hand"
  fi
fi

if ! vb_installed; then
  vb_fetch_files '' "$skip_vani"
  vb_recover_prefix # finishes an interrupted install, or moves it aside
  vb_display_stop install # a hidden display an interrupted run left behind
fi
if ! vb_installed; then
  saved_display=${DISPLAY-} saved_xauth=${XAUTHORITY-}
  # A private display keeps the wizard off your screen and the click offsets exact.
  if [[ -n ${VEDABASE_INSTALL_DISPLAY:-} ]]; then
    export DISPLAY=$VEDABASE_INSTALL_DISPLAY
    vb_ensure_pkgs deps xdotool
  elif vb_can_run_xvnc; then
    in_wizard=1
    vb_display_start install 1600x1000 None
  else
    vb_warn "x11-xkb-utils is not installed, so the installer runs on your screen (${DISPLAY:-}). Leave the mouse alone until it finishes."
    vb_ensure_pkgs deps xdotool
  fi
  [[ -n $name ]] || name=$(getent passwd "$VB_USER" | cut -d: -f5 | cut -d, -f1) || true
  in_wizard=1
  vb_make_prefix
  vb_stage_installer
  vb_run_installer "${name:-$VB_USER}"
  vb_check_install
  vb_postinstall
  vb_display_stop install
  in_wizard=0
  if [[ -n $saved_display ]]; then export DISPLAY=$saved_display; else unset DISPLAY; fi
  if [[ -n $saved_xauth ]]; then export XAUTHORITY=$saved_xauth; else unset XAUTHORITY; fi
else
  vb_say "Folio Views is installed"
fi
chmod 700 "$VB_PREFIX" # also tightens installs made before this was done

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
# Copy in VedaBase, then this: the clipboard then holds Unicode, ready to paste.
cat >"$VB_APPS_DIR/vedabase-unicode.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=VedaBase Unicode
Comment=Turn text copied out of VedaBase into Unicode, ready to paste anywhere
Exec=$VB_BIN_LINK unicode
Icon=$VB_HOME/icons/vedabase.png
Terminal=false
Categories=Education;Literature;Utility;
EOF
if command -v update-desktop-database >/dev/null; then
  update-desktop-database -q "$VB_APPS_DIR" 2>/dev/null || true
fi
# WSLg mirrors menu entries into the Windows Start menu, but only from system
# folders such as /usr/share/applications, never from ~/.local/share.
if [[ -n ${WSL_DISTRO_NAME:-} ]]; then
  wsl_entries=("$VB_APPS_DIR/vedabase.desktop" "$VB_APPS_DIR/vedabase-unicode.desktop")
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
Text copied out of VedaBase turns into Unicode with "VedaBase Unicode" in the
menu (give it a keyboard shortcut in your desktop's settings), or:
  vedabase unicode
EOF
if ! command -v vedabase >/dev/null; then
  vb_warn "the 'vedabase' command works in new terminals after you log out and back in; until then use $VB_BIN_LINK"
fi
