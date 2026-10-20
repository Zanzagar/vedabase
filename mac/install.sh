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
[[ $EUID -ne 0 ]] || vb_die "run the installer as yourself, without sudo"
# Gcenx's builds need macOS 10.15.4 or later.
IFS=. read -r mac_major mac_minor mac_patch _ <<<"$(sw_vers -productVersion).0.0"
if ((mac_major == 10 && (mac_minor < 15 || (mac_minor == 15 && mac_patch < 4)))); then
  vb_die "needs macOS 10.15.4 or later (this is $(sw_vers -productVersion))"
fi

vb_init_paths
VB_WINE_DIR="$VB_HOME/wine/Wine Stable.app/Contents/Resources/wine"
mkdir -p "$VB_HOME" "$VB_LOGS"
in_wizard=0 # set while the installer's windows are open
on_exit() {
  local rc=$?
  ((rc == 0)) && return
  if ((in_wizard)); then wineserver -k >/dev/null 2>&1 || true; fi # close its windows
  vb_warn "the install did not finish. Logs: $VB_LOGS (in Finder: Go > Go to Folder). Running the installer again continues where it stopped."
}
trap on_exit EXIT
vb_say "Installing into $VB_HOME"
# Keep the Mac awake while this runs: the downloads and the wizard take a while.
caffeinate -i -w $$ >/dev/null 2>&1 &

if ! vb_installed; then
  # About 4 GB in all, less whatever an earlier run already put here.
  have_kb=$(du -sk "$VB_HOME/wine" "$VB_DOWNLOADS" "$VB_PREFIX" 2>/dev/null | awk '{s += $1} END {print s + 0}') ||
    true # du fails on the folders a fresh install has not made yet; awk still sums the rest
  need_kb=$((4 * 1024 * 1024 - have_kb))
  avail_kb=$(df -Pk "$VB_HOME" 2>/dev/null | awk 'NR == 2 {print $4}') || avail_kb=''
  [[ -z $avail_kb ]] || ((avail_kb >= need_kb)) ||
    vb_die "the installer needs about $((need_kb / 1024)) MB more free disk space (this Mac has $((avail_kb / 1024)) MB free)"
fi

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
  status=$(curl -sIL -o /dev/null -w '%{http_code}' "$MAC_WINE_URL") || status=''
  if [[ $status == 404 ]]; then
    # Gcenx retags releases and removes old files. Fall back to the newest
    # stable build, checked against the SHA-256 GitHub publishes for it.
    vb_warn "the pinned Wine build is gone; looking up the newest stable one"
    # JavaScript for Automation parses the JSON: a stock Mac has no real python3.
    releases=$(curl -fsSL 'https://api.github.com/repos/Gcenx/macOS_Wine_builds/releases?per_page=30') ||
      vb_die "could not look up a newer Wine build on github.com; check the internet connection and run the installer again later"
    read -r MAC_WINE_URL MAC_WINE_SHA256 < <(osascript -l JavaScript -e '
      function run(argv) {
        for (const r of JSON.parse(argv[0]))
          for (const a of r.assets)
            if (/^wine-stable-.*-osx64[.]tar[.]xz$/.test(a.name) && /^sha256:/.test(a.digest || ""))
              return a.browser_download_url + " " + a.digest.slice(7);
        return "";
      }' "$releases") || true
    [[ -n ${MAC_WINE_URL:-} && -n ${MAC_WINE_SHA256:-} ]] ||
      vb_die "no stable Wine build found at github.com/Gcenx/macOS_Wine_builds"
  fi
  curl -fL -# --retry 3 -o "$tarball" "$MAC_WINE_URL" ||
    vb_die "could not download Wine; check the internet connection and run the installer again"
  [[ $(vb_sha256 <"$tarball") == "$MAC_WINE_SHA256" ]] || vb_die "checksum mismatch for $MAC_WINE_URL"
  tar -xJf "$tarball" -C "$VB_HOME/wine"
  rm -f "$tarball"
  # curl does not quarantine, but clear it in case the files came another way.
  xattr -dr com.apple.quarantine "$VB_HOME/wine/Wine Stable.app" 2>/dev/null || true
fi
vb_env

if ! vb_installed; then
  vb_fetch_files
  vb_recover_prefix # finishes an interrupted install, or moves it aside
fi
if ! vb_installed; then
  vb_make_prefix
  # Let Cmd+C / Cmd+V work as Ctrl+C / Ctrl+V in Folio.
  for key in LeftCommandIsCtrl RightCommandIsCtrl; do
    wine reg add 'HKCU\Software\Wine\Mac Driver' /v "$key" /t REG_SZ /d Y /f >>"$VB_LOGS/wine.log" 2>&1 ||
      vb_warn "could not map Cmd to Ctrl (Ctrl+C / Ctrl+V still work)"
  done
  vb_stage_installer
  cat <<'EOF'

==> The original VedaBase installer opens now. In its window:
      1. Next, then Accept the license, then type your name, then Next.
      2. Next again (ignore its list of old Windows versions).
      3. "Select Install Type": choose Custom, then Next.
      4. Tick "All Folio Program Files" and "VedaBase Master Files"
         (leave "WinAmp media player" unticked), then Next.
      5. Next, Next, Install, then Next, Next and Finish.
      6. Answer the restart questions (either answer is fine). This Terminal
         window then closes the Fonts window the installer opens, and carries on.

EOF
  in_wizard=1
  (cd "$VB_PREFIX/drive_c" && wine 'C:\Install.exe' >>"$VB_LOGS/installer.log" 2>&1) || true
  # The launcher hands over to irsetup.exe, the wizard. Once that has gone,
  # end what it leaves open (the Fonts window, which can sit behind others),
  # as the Linux installer does, then do Wine's equivalent of the restart.
  # Wine's own process list tells; if it shows nothing usable (no services.exe,
  # which every running prefix has), the user closes the windows instead.
  vb_say "Waiting for the installer to finish (click through its window)"
  sleep 3
  while :; do
    tasks=$(wine tasklist /fo csv /nh 2>/dev/null) || tasks=''
    grep -qi '"services[.]exe"' <<<"$tasks" || { wizard=unknown; break; }
    grep -qiE '"(irsetup|install)[.]exe"' <<<"$tasks" || { wizard=gone; break; }
    sleep 3
  done
  if [[ $wizard == gone ]]; then
    wineserver -k >/dev/null 2>&1 || true
  else
    vb_say "When the installer has finished, close its remaining windows (the Fonts window may be behind this one)."
  fi
  wineserver -w
  wineboot --restart >>"$VB_LOGS/installer.log" 2>&1 || true
  wineserver -w
  in_wizard=0
  vb_check_install
  vb_postinstall
fi
chmod 700 "$VB_PREFIX" # also tightens installs made before this was done
vani=$VB_APP_DIR/Nfo/VaniBase_25.nfo
if [[ ! -f $vani || ! -f $VB_APP_DIR/Nfo/VaniBase_25.sdw || $(vb_size "$vani") != "$(vb_manifest_size VaniBase/VaniBase_25.nfo)" ]]; then
  vb_fetch_files VaniBase/
  vb_add_vanibase
fi

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
