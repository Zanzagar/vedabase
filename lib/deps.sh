# shellcheck shell=bash
# Host packages. Anything missing is fetched with `apt-get download` and
# unpacked under $VB_TOOLS, so no root is needed; `sudo apt-get install` is
# only the fallback when downloading is impossible.

# Libraries the Wine build links or dlopens (winex11.so, win32u.so).
VB_PKGS_WINE=(libx11-6 libxext6 libxrender1 libxrandr2 libxi6 libxcursor1
  libxcomposite1 libxinerama1 libxfixes3 libxxf86vm1 libfreetype6 libfontconfig1)
# A private X display (TigerVNC's Xvnc) plus the tool that drives Install.exe.
VB_PKGS_DISPLAY=(tigervnc-standalone-server tigervnc-tools xdotool xauth)
# The browser viewer. Only the files are needed: novnc's nodejs and numpy
# dependencies are not, so these are unpacked without their dependencies.
VB_PKGS_WEB=(novnc python3-websockify)
# The clipboard, for 'vedabase unicode' (on desktops and in the browser viewer).
VB_PKGS_CLIP=(xclip)

vb_pkg_installed() { [[ $(dpkg-query -W -f='${Status}' "$1" 2>/dev/null) == *'ok installed' ]]; }
vb_pkg_unpacked() { [[ -e $VB_HOME/tools/stamps/$1 ]]; }

# Print the packages (with their dependencies when $1 is "deps") that are
# neither installed nor already unpacked. apt-get's simulation works without
# root and resolves alternatives against what is installed.
vb_pkgs_missing() {
  local mode=$1 p plan
  shift
  # If apt cannot plan (no package lists, unknown name), fall back to the
  # names themselves so the download step fails loudly instead of silently.
  if [[ $mode == deps ]] && plan=$(apt-get -s -q install --no-install-recommends "$@" 2>/dev/null); then
    awk '/^Inst /{print $2}' <<<"$plan"
  else
    printf '%s\n' "$@"
  fi | while read -r p; do
    [[ -n $p ]] || continue
    vb_pkg_installed "$p" || vb_pkg_unpacked "$p" || printf '%s\n' "$p"
  done
}

# vb_ensure_pkgs deps|nodeps PKG...
vb_ensure_pkgs() {
  local mode=$1 missing p deb debs=$VB_HOME/tools/debs
  shift
  command -v dpkg-query >/dev/null ||
    vb_die "this installer expects a Debian/Ubuntu system (needs: $*)"
  mapfile -t missing < <(vb_pkgs_missing "$mode" "$@")
  ((${#missing[@]})) || return 0
  vb_say "Fetching without root: ${missing[*]}"
  mkdir -p "$debs" "$VB_TOOLS" "$VB_HOME/tools/stamps"
  if ! (cd "$debs" && apt-get download "${missing[@]}" >/dev/null 2>&1); then
    vb_sudo_install "${missing[@]}"
    return
  fi
  for p in "${missing[@]}"; do
    deb=$(compgen -G "$debs/${p}_*.deb" | head -n1 || true)
    [[ -n $deb ]] || vb_die "apt-get download produced no .deb for $p"
    dpkg-deb -x "$deb" "$VB_TOOLS"
    : >"$VB_HOME/tools/stamps/$p"
  done
  rm -f "$debs"/*.deb
}

vb_sudo_install() {
  local cmd=(sudo apt-get install -y --no-install-recommends "$@")
  if [[ -t 0 ]] && command -v sudo >/dev/null; then
    vb_warn "apt-get download failed; installing system-wide instead: ${cmd[*]}"
    sudo apt-get update && "${cmd[@]}"
  else
    vb_die "could not fetch $*. Run this once, then re-run the installer:  ${cmd[*]}"
  fi
}

# Xvnc runs the keymap compiler from the path it was built with, so a private
# display needs xkbcomp installed system-wide (package x11-xkb-utils).
vb_can_run_xvnc() { [[ -x /usr/bin/xkbcomp && -d /usr/share/X11/xkb ]]; }

vb_ensure_wine() {
  [[ -x $VB_WINE_DIR/bin/wine ]] && return 0
  local tarball=$VB_HOME/cache/$VB_WINE_NAME.tar.xz
  mkdir -p "$VB_HOME/cache" "$VB_HOME/wine"
  if ! sha256sum -c --status <<<"$VB_WINE_SHA256  $tarball" 2>/dev/null; then
    vb_say "Downloading $VB_WINE_NAME (73 MB)"
    curl -fL --retry 3 -o "$tarball.part" "$VB_WINE_URL"
    mv -f -- "$tarball.part" "$tarball"
    sha256sum -c --status <<<"$VB_WINE_SHA256  $tarball" ||
      vb_die "checksum mismatch for $VB_WINE_URL"
  fi
  tar -xJf "$tarball" -C "$VB_HOME/wine"
  [[ -x $VB_WINE_DIR/bin/wine ]] || vb_die "unpacking $tarball did not produce $VB_WINE_DIR/bin/wine"
  rm -f -- "$tarball"
}
