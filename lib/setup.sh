# shellcheck shell=bash
# Building the prefix and running Install.exe. The installer is a Setup
# Factory 5 wizard with no silent mode, so on Linux xdotool drives it: every
# screen is a top-level window whose title names it. Shared with mac/install.sh,
# so keep to bash 3.2 and BSD-compatible tools.

# Click offsets inside the 450x333 wizard pages (Wine's default 96 DPI, so the
# layout is the same on any display).
VB_XY_NAME=(286 117)   # Name field on "User Information"
VB_XY_CUSTOM=(170 223) # "Custom" on "Select Install Type"
VB_XY_PKG1=(170 73)    # "All Folio Program Files" on "Select Packages"
VB_XY_PKG2=(170 89)    # "VedaBase Master Files"; the third, WinAmp, stays off

VB_MASTER_NFO='Bhaktivedanta Vedabase 2003.nfo'
VB_MASTER_SIZE=649011200

vb_make_prefix() {
  vb_say "Creating the Wine prefix"
  mkdir -p "$VB_PREFIX"
  # winegstreamer= sidesteps a known hang while GStreamer plugins load. The
  # CrossOver report in the Drive folder: VedaBase crashed in a Windows 10
  # bottle, while 7 or XP worked. Install.exe first "opens" C:\Spec\intro.wav;
  # Wine has no player for it, and the error box would stall the wizard, so
  # .wav goes to rundll32 without arguments, which does nothing (a fresh prefix
  # has no .wav key; vb_postinstall deletes it again).
  {
    WINEDLLOVERRIDES="$WINEDLLOVERRIDES;winegstreamer=" wineboot --init &&
      wineserver -w &&
      wine winecfg /v win7 &&
      wine reg add 'HKCR\.wav' /ve /d vedabase.noop /f &&
      wine reg add 'HKCR\vedabase.noop\shell\open\command' /ve /d '"C:\windows\system32\rundll32.exe"' /f &&
      wineserver -w
  } >>"$VB_LOGS/wine.log" 2>&1 || vb_die "creating the Wine prefix failed; see $VB_LOGS/wine.log"
  # Wine links the Windows desktop to yours; Install.exe would put two Windows
  # shortcuts (.lnk) there, so give the prefix its own desktop folder.
  local desktop="$VB_PREFIX/drive_c/users/$USER/Desktop"
  if [[ -L $desktop ]]; then
    rm -f -- "$desktop"
    mkdir -p -- "$desktop"
  fi
}

# Ekanatha's README: Fonts\ Nfo\ Spec\ and Install.exe must sit at the root of C:\.
vb_stage_installer() {
  local x
  for x in Fonts Nfo Spec Install.exe; do
    ln -sfn -- "$VB_DOWNLOADS/$x" "$VB_PREFIX/drive_c/$x"
  done
}
vb_unstage_installer() {
  rm -f -- "$VB_PREFIX/drive_c/Fonts" "$VB_PREFIX/drive_c/Nfo" \
    "$VB_PREFIX/drive_c/Spec" "$VB_PREFIX/drive_c/Install.exe"
}

# "WID<TAB>title" for every visible top-level window.
vb_windows() {
  local w
  for w in $(xdotool search --onlyvisible --name . 2>/dev/null); do
    printf '%s\t%s\n' "$w" "$(xdotool getwindowname "$w" 2>/dev/null)"
  done
}

vb_click() { # WID X Y
  xdotool mousemove --window "$1" "$2" "$3" click 1
  sleep 0.3
}

# A click in the window's corner gives it the focus, then the keys go to it.
vb_press() { # WID KEY...
  vb_click "$1" 4 4
  xdotool key --clearmodifiers "${@:2}"
}

# Wait up to SECONDS for window WID to be gone, hidden, or renamed (the next
# wizard page). Returns 1 if it is still showing TITLE.
vb_wait_change() { # WID TITLE SECONDS
  local i t ids
  for ((i = 0; i < ${3:-120} * 2; i++)); do
    t=$(xdotool getwindowname "$1" 2>/dev/null) || return 0
    [[ $t == "$2" ]] || return 0
    ids=$(xdotool search --onlyvisible --name . 2>/dev/null) || true
    grep -qx -- "$1" <<<"$ids" || return 0
    sleep 0.5
  done
  return 1
}

vb_installer_running() {
  local pid
  for pid in $(pgrep -u "$(id -u)" -f 'irsetup|Install\.exe' 2>/dev/null); do
    grep -qzxF "WINEPREFIX=$VB_PREFIX" "/proc/$pid/environ" 2>/dev/null && return 0
  done
  return 1
}

vb_installer_stuck() { # LAST_SCREEN
  local titles
  titles=$(vb_windows | cut -f2 | paste -sd'|')
  wineserver -k 2>/dev/null || true
  vb_die "Install.exe stalled at screen '${1:-none}' (windows now: ${titles:-none}). Log: $VB_LOGS/installer.log. Run install.sh again; to watch the wizard, run it from a desktop with VEDABASE_INSTALL_DISPLAY=\$DISPLAY."
}

# Answer every wizard page. A page that does not move on within 20 s gets its
# confirming key again (never its clicks, which would untick the boxes), up to
# six times, since a key can be lost while Wine is still giving the page focus.
vb_run_installer() { # REGISTERED_NAME
  local name=$1 log=$VB_LOGS/installer.log wid title acted last='' seen='' tries=0 typed=0
  local deadline=$((SECONDS + 1800)) idle_since=$SECONDS
  vb_say "Running Install.exe (driven automatically; takes a few minutes)"
  (cd "$VB_PREFIX/drive_c" && setsid wine 'C:\Install.exe' >>"$log" 2>&1 </dev/null &)
  sleep 3
  while ((SECONDS < deadline)); do
    acted=''
    while IFS=$'\t' read -r wid title; do
      case $title in
        'Pre-Install' | 'License Agreement' | 'User Information' | 'Important Information' | \
          'Select Install Type' | 'Select Packages' | 'Install Folder' | 'Shortcut Folder' | \
          'Ready to Install' | 'VedaBase Icons' | 'WinAmp Install' | 'Finished' | 'Notice' | 'Error') ;;
        *) continue ;;
      esac
      if [[ "$wid:$title" == "$seen" ]]; then
        tries=$((tries + 1))
        ((tries <= 6)) || vb_installer_stuck "$title"
        case $title in
          'Notice' | 'Error') vb_press "$wid" Escape ;;
          *) vb_press "$wid" Return ;;
        esac
      else
        seen="$wid:$title" tries=0
        case $title in
          'User Information')
            if ((typed)); then
              vb_press "$wid" Return
            else
              vb_click "$wid" "${VB_XY_NAME[@]}"
              xdotool type --delay 20 -- "$name"
              xdotool key Return
              typed=1
            fi ;;
          'Select Install Type')
            vb_click "$wid" "${VB_XY_CUSTOM[@]}"
            vb_press "$wid" Return ;;
          'Select Packages')
            vb_click "$wid" "${VB_XY_PKG1[@]}"
            vb_click "$wid" "${VB_XY_PKG2[@]}"
            vb_press "$wid" Return ;;
          'Notice' | 'Error')
            # "Restart now?" gets Cancel (Wine is restarted below), "restart
            # recommended" gets OK; Escape answers both.
            vb_press "$wid" Escape ;;
          *) vb_press "$wid" Return ;;
        esac
      fi
      printf '%s\n' "$title" >>"$log"
      acted=$title
      last=$title
      vb_wait_change "$wid" "$title" 20 || true
      break
    done < <(vb_windows)
    if [[ -n $acted ]]; then
      idle_since=$SECONDS
      continue
    fi
    vb_installer_running || break
    ((SECONDS - idle_since < 600)) || vb_installer_stuck "$last"
    sleep 1
  done
  ((SECONDS < deadline)) || vb_installer_stuck "$last"
  [[ $last == Notice || $last == Finished ]] || vb_installer_stuck "$last"
  # It asks for a reboot; Wine's equivalent runs the pending boot-time steps.
  wineserver -k >/dev/null 2>&1 || true
  wineserver -w
  wineboot --restart >>"$log" 2>&1 || vb_die "restarting Wine after the install failed; see $log"
  wineserver -w
}

vb_check_install() {
  local f missing=0
  [[ -f $VB_APP_DIR/Views.exe ]] ||
    vb_die "Install.exe finished but Views.exe is missing; see $VB_LOGS/installer.log"
  [[ -f "$VB_APP_DIR/Nfo/$VB_MASTER_NFO" && $(vb_size "$VB_APP_DIR/Nfo/$VB_MASTER_NFO") == "$VB_MASTER_SIZE" ]] ||
    vb_die "the VedaBase infobase was not installed completely (was 'VedaBase Master Files' ticked?); see $VB_LOGS/installer.log"
  for f in "$VB_DOWNLOADS"/Fonts/*; do
    [[ -n $(find "$VB_PREFIX/drive_c/windows/Fonts" -maxdepth 1 -iname "${f##*/}" -print 2>/dev/null) ]] ||
      missing=$((missing + 1))
  done
  ((missing == 0)) || vb_die "$missing diacritic fonts did not reach C:\\windows\\Fonts"
}

# Hard link when possible (no second 649 MB copy), else a relative symlink;
# Wine follows both.
vb_link() { # TARGET NAME
  [[ -e $2 ]] && return 0
  ln -- "$1" "$2" 2>/dev/null || ln -s -- "${1##*/}" "$2"
}

# Safe to run more than once; it ends by stamping the prefix as finished.
vb_postinstall() {
  local nfo=$VB_APP_DIR/Nfo
  # The shadow file Install.exe's icon opens names its master "VedaBase_25.nfo"
  # (the path on the machine that made it), while the infobase is installed as
  # "Bhaktivedanta Vedabase 2003.nfo". Give it both names.
  vb_link "$nfo/$VB_MASTER_NFO" "$nfo/VedaBase_25.nfo"
  { wine reg delete 'HKCR\.wav' /f || true; } >>"$VB_LOGS/wine.log" 2>&1
  { wine reg delete 'HKCR\vedabase.noop' /f || true; } >>"$VB_LOGS/wine.log" 2>&1
  wineserver -w >>"$VB_LOGS/wine.log" 2>&1 || true
  vb_unstage_installer
  : >"$VB_PREFIX/.vedabase-installed"
}

# A prefix left by an interrupted run: finish it if Install.exe had copied
# everything, otherwise move it aside (it may hold notes) and start again.
vb_recover_prefix() {
  [[ -e $VB_PREFIX ]] || return 0
  if [[ -f $VB_APP_DIR/Views.exe && -f "$VB_APP_DIR/Nfo/$VB_MASTER_NFO" &&
    $(vb_size "$VB_APP_DIR/Nfo/$VB_MASTER_NFO") == "$VB_MASTER_SIZE" ]]; then
    vb_say "Finishing an install that was interrupted"
    vb_check_install
    vb_postinstall
    return 0
  fi
  local aside
  aside="$VB_PREFIX.unfinished-$(date +%Y%m%d-%H%M%S)"
  vb_warn "moving an unfinished install aside to $aside (delete it once you no longer need anything in it)"
  wineserver -k >/dev/null 2>&1 || true
  mv -- "$VB_PREFIX" "$aside"
}

# VaniBase 25 needs no installer: Folio opens its shadow file from the same Nfo
# folder. The .sdw is copied fresh only once, because it holds your own notes.
vb_add_vanibase() {
  local nfo=$VB_APP_DIR/Nfo src=$VB_DOWNLOADS/VaniBase/VaniBase_25.nfo
  if [[ ! -f $nfo/VaniBase_25.nfo || $(vb_size "$nfo/VaniBase_25.nfo") != "$(vb_size "$src")" ]]; then
    vb_say "Adding VaniBase 25"
    cp -f -- "$src" "$nfo/VaniBase_25.nfo"
  fi
  [[ -e $nfo/VaniBase_25.sdw ]] || cp -- "$VB_DOWNLOADS/VaniBase/VaniBase_25.sdw" "$nfo/VaniBase_25.sdw"
}
