# shellcheck shell=bash
# Building the prefix and running Install.exe. The installer is a Setup
# Factory 5 wizard that ignores /S, so xdotool drives it: every screen is a
# top-level window whose title names it.

# Click offsets inside the 450x333 wizard pages (Wine's default 96 DPI, so the
# layout is the same on any display).
VB_XY_NAME=(286 117)   # Name field on "User Information"
VB_XY_CUSTOM=(170 223) # "Custom" on "Select Install Type"
VB_XY_PKG1=(170 73)    # "All Folio Program Files" on "Select Packages"
VB_XY_PKG2=(170 89)    # "VedaBase Master Files"; the third, WinAmp, stays off

vb_make_prefix() {
  vb_say "Creating the Wine prefix"
  mkdir -p "$VB_PREFIX"
  {
    wineboot --init
    wineserver -w
    # Tāraka's CrossOver report: VedaBase crashed in a Windows 10 bottle; 7 or XP worked.
    wine winecfg /v win7
    # Install.exe first "opens" C:\Spec\intro.wav. Wine has no player for it,
    # and the error box would stall the wizard; rundll32 without arguments
    # does nothing. A fresh prefix has no .wav key, so vb_postinstall deletes it.
    wine reg add 'HKCR\.wav' /ve /d vedabase.noop /f
    wine reg add 'HKCR\vedabase.noop\shell\open\command' /ve /d '"C:\windows\system32\rundll32.exe"' /f
    wineserver -w
  } >>"$VB_LOGS/wine.log" 2>&1
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

# Wait until window WID is gone, hidden, or renamed (the next wizard page).
vb_wait_change() { # WID TITLE
  local i t ids
  for i in {1..240}; do
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
  vb_die "Install.exe stalled after screen '${1:-none}' (windows now: ${titles:-none}). Log: $VB_LOGS/installer.log. Re-run with --reinstall; to watch it, add VEDABASE_INSTALL_DISPLAY=\$DISPLAY from a desktop session."
}

vb_run_installer() { # REGISTERED_NAME
  local name=$1 log=$VB_LOGS/installer.log wid title acted last=''
  local deadline=$((SECONDS + 1800)) idle_since=$SECONDS
  vb_say "Running Install.exe (driven automatically; takes a minute or two)"
  (cd "$VB_PREFIX/drive_c" && setsid wine 'C:\Install.exe' >>"$log" 2>&1 </dev/null &)
  sleep 3
  while ((SECONDS < deadline)); do
    acted=''
    while IFS=$'\t' read -r wid title; do
      case $title in
        'User Information')
          vb_click "$wid" "${VB_XY_NAME[@]}"
          xdotool type --delay 20 -- "$name"
          xdotool key Return ;;
        'Select Install Type')
          vb_click "$wid" "${VB_XY_CUSTOM[@]}"
          vb_press "$wid" Return ;;
        'Select Packages')
          vb_click "$wid" "${VB_XY_PKG1[@]}"
          vb_click "$wid" "${VB_XY_PKG2[@]}"
          vb_press "$wid" Return ;;
        'Pre-Install' | 'License Agreement' | 'Important Information' | 'Install Folder' | \
          'Shortcut Folder' | 'Ready to Install' | 'VedaBase Icons' | 'WinAmp Install' | 'Finished')
          vb_press "$wid" Return ;;
        'Notice' | 'Error')
          # "Restart now?" gets Cancel (Wine is restarted below), "restart
          # recommended" gets OK; Escape answers both.
          vb_press "$wid" Escape ;;
        *) continue ;;
      esac
      printf '%s\n' "$title" >>"$log"
      acted=$title
      last=$title
      vb_wait_change "$wid" "$title" || vb_installer_stuck "$last"
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
  wineboot --restart >>"$log" 2>&1
  wineserver -w
}

vb_check_install() {
  local f missing=0
  [[ -f $VB_APP_DIR/Views.exe ]] ||
    vb_die "Install.exe finished but Views.exe is missing; see $VB_LOGS/installer.log"
  [[ -f "$VB_APP_DIR/Nfo/Bhaktivedanta Vedabase 2003.nfo" ]] ||
    vb_die "the VedaBase infobase was not installed; see $VB_LOGS/installer.log"
  for f in "$VB_DOWNLOADS"/Fonts/*; do
    [[ -n $(find "$VB_PREFIX/drive_c/windows/Fonts" -maxdepth 1 -iname "${f##*/}" -print -quit) ]] ||
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

vb_postinstall() {
  local nfo=$VB_APP_DIR/Nfo
  # The shadow file Install.exe opens names its master "VedaBase_25.nfo", the
  # name the infobase had before the README renamed it for the install script.
  vb_link "$nfo/Bhaktivedanta Vedabase 2003.nfo" "$nfo/VedaBase_25.nfo"
  {
    wine reg delete 'HKCR\.wav' /f
    wine reg delete 'HKCR\vedabase.noop' /f
    wineserver -w
  } >>"$VB_LOGS/wine.log" 2>&1
  vb_unstage_installer
}

# VaniBase 25 needs no installer: Folio opens its shadow file from the same Nfo
# folder. The .sdw is copied fresh only once, because it holds your own notes.
vb_add_vanibase() {
  local nfo=$VB_APP_DIR/Nfo src=$VB_DOWNLOADS/VaniBase/VaniBase_25.nfo
  if [[ $(stat -c %s -- "$nfo/VaniBase_25.nfo" 2>/dev/null) != "$(stat -c %s -- "$src")" ]]; then
    vb_say "Adding VaniBase 25"
    cp -f -- "$src" "$nfo/VaniBase_25.nfo"
  fi
  [[ -e $nfo/VaniBase_25.sdw ]] || cp -- "$VB_DOWNLOADS/VaniBase/VaniBase_25.sdw" "$nfo/VaniBase_25.sdw"
}
