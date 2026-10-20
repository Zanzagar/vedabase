#!/bin/bash
# Install the Bhaktivedanta VedaBase (Folio Views 4.3, VedaBase 25, VaniBase 25)
# on macOS with Gcenx's free Wine build (the one WineHQ distributes), no
# CrossOver needed. Started by Install-VedaBase-Mac.command; you click through
# the original installer's wizard, and it leaves "VedaBase 25" and
# "VaniBase 25" apps in ~/Applications. Safe to re-run: it finishes whatever
# is missing. Written for the bash 3.2 that macOS ships.
set -euo pipefail

VB_REPO=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../lib/common.sh
source "$VB_REPO/lib/common.sh"
# shellcheck source=../lib/fetch.sh
source "$VB_REPO/lib/fetch.sh"
# shellcheck source=../lib/setup.sh
source "$VB_REPO/lib/setup.sh"

# Stable branch, like the Linux build; checksum from the GitHub release.
MAC_WINE_URL=https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.0_1/wine-stable-11.0_1-osx64.tar.xz
MAC_WINE_SHA256=b50dc50ec7f41d58b115a6b685d4d1315ba3c797bd3aa0f49213f2703cb82388
MAC_APPS=$HOME/Applications

[[ $(uname -s) == Darwin ]] || vb_die "this is the macOS installer; on Linux run ./install.sh"
# Gcenx's builds need macOS 10.15.4 or later.
IFS=. read -r mac_major mac_minor mac_patch _ <<<"$(sw_vers -productVersion).0.0"
if ((mac_major == 10 && (mac_minor < 15 || (mac_minor == 15 && mac_patch < 4)))); then
  vb_die "needs macOS 10.15.4 or later (this is $(sw_vers -productVersion))"
fi

vb_init_paths
VB_WINE_DIR="$VB_HOME/wine/Wine Stable.app/Contents/Resources/wine"
mkdir -p "$VB_HOME" "$VB_LOGS"
vb_say "Installing into $VB_HOME"

# Gcenx's Wine is an Intel (x86_64) program; Apple Silicon runs it through Rosetta 2.
if [[ $(uname -m) == arm64 ]] && ! /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
  id -Gn | tr ' ' '\n' | grep -qx admin ||
    vb_die "this Mac needs Rosetta 2, which only an administrator can install: sign in as one and run  softwareupdate --install-rosetta --agree-to-license  then run this installer again"
  vb_say "Installing Rosetta 2 (macOS asks for your password)"
  sudo /usr/sbin/softwareupdate --install-rosetta --agree-to-license
fi

if [[ ! -x $VB_WINE_DIR/bin/wine ]]; then
  tarball=$VB_HOME/cache/wine-stable-osx64.tar.xz
  mkdir -p "$VB_HOME/cache" "$VB_HOME/wine"
  vb_say "Downloading Wine for macOS (185 MB)"
  if ! curl -fL -# --retry 3 -o "$tarball" "$MAC_WINE_URL"; then
    # Gcenx retags releases and removes old files. Fall back to the newest
    # stable build, checked against the SHA-256 GitHub publishes for it.
    vb_warn "the pinned Wine build is gone; looking up the newest stable one"
    # JavaScript for Automation parses the JSON: a stock Mac has no real python3.
    releases=$(curl -fsSL 'https://api.github.com/repos/Gcenx/macOS_Wine_builds/releases?per_page=30')
    read -r MAC_WINE_URL MAC_WINE_SHA256 < <(osascript -l JavaScript -e '
      function run(argv) {
        for (const r of JSON.parse(argv[0]))
          for (const a of r.assets)
            if (/^wine-stable-.*-osx64[.]tar[.]xz$/.test(a.name) && /^sha256:/.test(a.digest || ""))
              return a.browser_download_url + " " + a.digest.slice(7);
        return "";
      }' "$releases") ||
      vb_die "no stable Wine build found at github.com/Gcenx/macOS_Wine_builds"
    curl -fL -# --retry 3 -o "$tarball" "$MAC_WINE_URL"
  fi
  [[ $(vb_sha256 <"$tarball") == "$MAC_WINE_SHA256" ]] || vb_die "checksum mismatch for $MAC_WINE_URL"
  tar -xJf "$tarball" -C "$VB_HOME/wine"
  rm -f "$tarball"
  # curl does not quarantine, but clear it in case the files came another way.
  xattr -dr com.apple.quarantine "$VB_HOME/wine/Wine Stable.app" 2>/dev/null || true
fi
vb_env

vb_fetch_files

if ! vb_installed; then
  [[ ! -e $VB_PREFIX ]] || rm -rf "$VB_PREFIX" # a half-made prefix from an interrupted run
  vb_make_prefix
  # Let Cmd+C / Cmd+V work as Ctrl+C / Ctrl+V in Folio.
  for key in LeftCommandIsCtrl RightCommandIsCtrl; do
    wine reg add 'HKCU\Software\Wine\Mac Driver' /v "$key" /t REG_SZ /d Y /f >>"$VB_LOGS/wine.log" 2>&1
  done
  vb_stage_installer
  cat <<'EOF'

==> The original VedaBase installer opens now. In its window:
      1. Next, then Accept the license, then type your name, then Next.
      2. "Select Install Type": choose Custom, then Next.
      3. Tick "All Folio Program Files" and "VedaBase Master Files"
         (leave "WinAmp media player" unticked), then Next.
      4. Next, Next, Install, then Next and Finish.
      5. Answer the restart questions (either answer is fine), and close the
         Fonts window it opens. This Terminal window then carries on.

EOF
  (cd "$VB_PREFIX/drive_c" && wine 'C:\Install.exe' >>"$VB_LOGS/installer.log" 2>&1) || true
  wineserver -w
  wineboot --restart >>"$VB_LOGS/installer.log" 2>&1 || true
  wineserver -w
  vb_check_install
  vb_postinstall
fi
vb_add_vanibase

# --- apps for the Dock and Launchpad ---------------------------------------------
make_app() { # NAME BUNDLE_ID WINDOWS_PATH_OF_SHADOW_FILE
  local app="$MAC_APPS/$1.app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cat >"$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$1</string>
  <key>CFBundleDisplayName</key><string>$1</string>
  <key>CFBundleIdentifier</key><string>$2</string>
  <key>CFBundleExecutable</key><string>launch</string>
  <key>CFBundleIconFile</key><string>vedabase</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>25</string>
  <key>LSMinimumSystemVersion</key><string>10.15</string>
</dict>
</plist>
EOF
  {
    echo '#!/bin/bash'
    printf 'export WINEPREFIX=%q WINEDEBUG=-all WINEDLLOVERRIDES=%q\n' "$VB_PREFIX" "$WINEDLLOVERRIDES"
    printf 'cd %q || exit 1\n' "$VB_APP_DIR"
    printf 'exec %q %q %q\n' "$VB_WINE_DIR/bin/wine" "$VB_APP_WIN\\Views.exe" "$3"
  } >"$app/Contents/MacOS/launch"
  chmod +x "$app/Contents/MacOS/launch"
  sips -s format icns "$VB_APP_DIR/vedabase.ico" --out "$app/Contents/Resources/vedabase.icns" >/dev/null 2>&1 ||
    vb_warn "could not convert the icon for $1"
}
mkdir -p "$MAC_APPS"
make_app 'VedaBase 25' org.vedabase.vedabase25 "$VB_APP_WIN\\Nfo\\Bhaktivedanta Vedabase 2003.sdw"
make_app 'VaniBase 25' org.vedabase.vanibase25 "$VB_APP_WIN\\Nfo\\VaniBase_25.sdw"

vb_say "Done. VedaBase 25 and VaniBase 25 are in $MAC_APPS (drag them to the Dock if you like)."
open "$MAC_APPS/VedaBase 25.app"
