# How the installer works

What `install.sh` does and why, written down on 2026-10-19 while installing on
an Ubuntu 24.04 server. The why matters most: each step below fixes something that broke when
the original Windows instructions ran under Wine.

## The inputs

**The VedaBase files.** Tāraka dāsa shared two Google Drive folders, owned by
Ekanatha dāsa (`eka108`): *VedaBase with Program* (`Install.exe`, `Fonts\`,
`Nfo\`, `Spec\`, a README and a CrossOver-on-macOS report) and *VaniBase*
(`VaniBase_25.nfo` and `.sdw`). `manifest/drive-files.tsv` lists all 65 files
with their Drive IDs, sizes and SHA-256 hashes. `lib/fetch.sh` downloads them
from `drive.usercontent.google.com` with `confirm=t`, which skips Drive's
"can't scan this file for viruses" page for the two large infobases, and
rejects any file whose size or hash differs from the manifest.

**Wine.** Kron4ek's portable build `wine-11.0-amd64-wow64` (stable branch,
SHA-256 from the GitHub release). It needs no root. Being a WoW64 build, it
runs the 32-bit Folio program without i386 host libraries. Wine itself needs only
`libX11`/`libXext` plus libraries it loads at runtime: Xrender, Xrandr, Xi,
Xcursor, Xcomposite, Xinerama, Xfixes, Xxf86vm, FreeType and fontconfig.
`lib/deps.sh` fetches whichever of those are missing with `apt-get download`
and unpacks them under `VEDABASE_HOME/tools`.

## The prefix

`wineboot --init` runs with `WINEDLLOVERRIDES="mscoree,mshtml=;winemenubuilder.exe=d"`.
That stops Wine asking to install Mono and Gecko, and stops it creating host
menu entries; `install.sh` writes its own two. The Windows version is set to 7:
Tāraka's CrossOver report says VedaBase crashed or would not start in a
Windows 10 bottle, and worked in 7 or XP.

## Install.exe

`Install.exe` is an Indigo Rose **Setup Factory 5.0.1.6** launcher. It unpacks
`irsetup.exe` and `irsetup.dat` into `%TEMP%`, starts the wizard, and exits.
It ignores `/S`; the wizard always shows. It reads `Fonts\`, `Nfo\` and `Spec\`
from the root of its own drive (`%SrcDrv%`), which is why Ekanatha's README
insists on `C:\`. `install.sh` symlinks the downloaded folders into
`drive_c/`, then removes the links afterwards.

Every wizard page is a top-level window whose title names it, so
`lib/setup.sh` loops: read the visible window titles, act on the one it
knows, wait for that window to change, repeat.

| Window title | What `setup.sh` does |
| --- | --- |
| Pre-Install | Enter (Next) |
| License Agreement | Enter (Accept). Note the terms below. |
| User Information | types your full name from `/etc/passwd` (or `--name`), Enter |
| Important Information | Enter |
| Select Install Type | clicks **Custom**, Enter |
| Select Packages | ticks *All Folio Program Files* and *VedaBase Master Files*; leaves *WinAmp media player* off |
| Install Folder | Enter (default `C:\Bhaktivedanta VedaBase 2003`) |
| Shortcut Folder | Enter |
| Ready to Install | Enter (Install), then the files are copied |
| VedaBase Icons, WinAmp Install | Enter |
| Finished | Enter (Finish); it then opens the Fonts folder |
| Notice ("restart now?") | Escape (= Cancel) |
| Notice ("we recommend that you restart") | Escape (= OK) |

The click offsets are relative to the 450×333 wizard window. They hold
anywhere because Wine lays dialogs out at its own 96 DPI, whatever the
display's DPI.

Two problems came up under Wine:

- **The intro sound.** The first thing the wizard does is "run"
  `C:\Spec\intro.wav`. Wine has nothing registered for `.wav`, so it shows an
  error box and then a Retry/Cancel box, and the wizard waits.
  `vb_make_prefix` registers `.wav` to `rundll32.exe` with no arguments, which
  does nothing. `vb_postinstall` deletes the key afterwards; a fresh prefix has
  no `.wav` key at all.
- **The restart.** The wizard ends by asking for a reboot.
  `install.sh` answers "later", then does Wine's equivalent itself:
  `wineserver -k`, then `wineboot --restart`.

The installer copies the program (Views.exe, Folio 4.3 DLLs, filters) to
`C:\Bhaktivedanta VedaBase 2003`, copies the infobase into its `Nfo\` folder,
puts the 51 fonts in `C:\windows\Fonts`, writes `HKCU\Software\VedaBase\4`,
and creates shortcuts. The main shortcut runs
`Views.exe "C:\Bhaktivedanta VedaBase 2003\Nfo\Bhaktivedanta Vedabase 2003.sdw"`.

Of the system folders, the installer touches only one file: it adds
`mfc40.dll` (MFC 4.0, 1996) to `syswow64`. Wine has no built-in MFC, so Folio
needs it. None of Wine's own DLLs were overwritten, which some Setup Factory
installers do (WineHQ bug 49076).

## The fix the README doesn't mention: `VedaBase_25.nfo`

Folio opens an infobase through its **shadow file** (`.sdw`). The shadow file
holds your own notes and highlights, plus the path of its master `.nfo`. The
shadow files Ekanatha shipped point to the paths on his own machine:

```
Bhaktivedanta Vedabase 2003.sdw -> X:\____VedaBase-VaniBase25\VedaBase_25.nfo
VaniBase_25.sdw                 -> X:\____VedaBase-VaniBase25\VaniBase_25.nfo
```

When that path is missing, Folio looks next to the shadow file for the same
name. VaniBase's file keeps its name, so it opens. The VedaBase infobase,
though, was renamed to `Bhaktivedanta VedaBase 2003.NFO` "to make the script
function properly" (README). The first launch therefore fails:

> Unable to open the infobase. The master infobase for this shadow,
> 'VedaBase_25.nfo' could not be found or was replaced by another infobase
> with the same name. (3706,1)

`vb_postinstall` adds a **hard link** named `VedaBase_25.nfo` to the installed
infobase. Both names then work, and no second 649 MB copy is made. This
almost certainly affects Windows installs of the same files too.

## VaniBase 25

VaniBase has no installer of its own. `install.sh` copies `VaniBase_25.nfo` and
`VaniBase_25.sdw` into the same `Nfo\` folder, and `vedabase vanibase` opens
the shadow file. The `.sdw` is copied only once, because your notes live in it.

## Showing it on a headless machine

A headless server has no display, so `vedabase web` makes one. Every part runs as you,
with no root:

- **TigerVNC's `Xvnc`**, from the Ubuntu package unpacked under
  `tools/`. It takes an X cookie, passed to `xauth` on stdin because every
  user on a shared server can read command lines. It serves VNC only on a unix socket
  with mode 0600. `-rfbport -1` is essential: `-rfbport 0` still opens TCP
  5900+N on every interface, as the first test run showed. It does need
  `xkbcomp` at `/usr/bin` (package `x11-xkb-utils`), because the keymap
  compiler's path is compiled into it.
- **websockify + noVNC**, also unpacked from Ubuntu packages. websockify is
  started with the system `/usr/bin/python3`, because the package is built for
  it. It listens on `127.0.0.1:6080`, and the VNC password (in
  `run/web/password`) keeps out other local users, since a localhost port is
  open to every user of the machine.
- **A Wine virtual desktop** (`explorer /desktop=VedaBase,1600x1000`). Without
  a window manager, Folio's window would have no frame, so it couldn't be
  moved or maximized. Folio also doesn't maximize itself under Wine, so
  `vedabase web` sets `HKCU\Software\VedaBase\4\Views\Frame\Layout\AppPosition`
  (left,top,right,bottom) to fill the desktop.

The installer uses the same kind of private display: a separate `Xvnc`, so the
wizard never appears on anyone's screen. Where `x11-xkb-utils` is missing but
a desktop exists (for example WSLg), it uses that desktop instead.

## Windows and macOS

**Windows** (`windows/install-vedabase.ps1`) needs no Wine. It follows
Ekanatha's README on Windows itself, in three phases, so that each step runs as
the right account:

1. **User:** checks first. Locked-down PowerShell (Smart App Control or App
   Control) stops it with an explanation, since that policy would also block
   the 2003 programs. Smart App Control in its "on" state gets a warning, and
   it also checks disk space. Then it asks for administrator rights once.
2. **Machine** (elevated):
   - It downloads to the root of `C:\`, checked against the same manifest.
   - It sets Windows XP SP2 compatibility on `Views.exe` with `reg.exe`.
     Devotees used that against Folio hanging on exit under Windows 7; a 2015
     report says it didn't help on Windows 10.
   - It runs the original `Install.exe`, and the user clicks through, because
     Setup Factory 5 has no silent switch. While the wizard is still on its
     last pages, it adds the `VedaBase_25.nfo` hard link and VaniBase 25, so a
     "restart now" answered with OK cannot skip them.
   - It registers all 51 fonts (`manifest/fonts.tsv`). Under Wine, Install.exe
     only copied them, writing nothing to the registry, and real Windows loads
     only registered fonts. That fits the README's "drag them onto Fonts if the
     diacritics fail".
   - It removes the `C:\` items it created.
3. **Finish** (the user again): if `HKCU\Software\VedaBase\4` is missing, it
   imports `windows/vedabase-defaults.reg`. That is what Install.exe writes,
   captured from a fresh install. The settings land in another account when
   someone elevates with a different administrator, or under Windows 11's
   Administrator protection. Without them, Folio shows the contents pane in a
   plain font, so the diacritics come out as "Çrémad-Bhägavatam", and moves its
   toolbars; this was checked by deleting the key under Wine. It then makes sure
   the user has a desktop icon.

**macOS** (`mac/install.sh`) shares `lib/fetch.sh` and `lib/setup.sh` with
Linux, both kept bash 3.2-compatible. It uses Gcenx's `wine-stable-11.0_1`.
That build is WoW64-only and bundles FreeType and GnuTLS, but it is an x86_64
program, so Apple Silicon runs it through Rosetta 2. There is no xdotool on
macOS, so the user clicks through the wizard. `wineserver -w` waits for every
installer window to close. The same Windows 7 mode, `intro.wav` handler and
post-install steps apply. It then writes two small app bundles to
`~/Applications`; each one's `launch` script runs `Views.exe` on its shadow
file. They are built locally, so Gatekeeper never quarantines them.

## What was verified

Checked 2026-10-19 on Ubuntu 24.04 with Wine 11.0:

- VedaBase 25 opens at record 1 of 1,613,056.
- Bg 2.13 renders with Devanagari, transliteration (*dehino 'smin yathā dehe*),
  synonyms, translation and purport.
- A search for "krsna Bhaktisiddhanta" in VaniBase 25 (518,550 records)
  returned 50 hits. VedaBase's language module (`nlsveda.dll`) works, since the
  query matched diacritic forms.
- The browser path, end to end, through headless Chromium and noVNC. The page
  connects with the printed password and refuses a wrong one ("Authentication
  failure"). Typing a query into Folio's search box through the browser found
  Bg 2.13 quoted in a 1975 lecture.
- Diacritics render the same under `LANG=C.UTF-8`, WSL's default, as under
  `en_US.UTF-8`, so the launcher sets no locale.
- Two clean unattended installs ran from scratch: one downloading from Drive,
  one from `--source` with a local copy. Re-running `install.sh` on a finished
  install repairs it without touching the prefix.

## The license you accept

`Install.exe` shows the 2003 Bhaktivedanta Archives license. The Linux
installer clicks Accept for you; on Windows and macOS you click it yourself.
Clause 2.1 "permits you to use one copy of the SOFTWARE on the Host Computer …
only one person may access the SOFTWARE at a time". Clause 2.4 forbids copying
"except to your personal archival copy", and use "in an on-line system".
`vedabase backup` makes that archival copy. Any wider use is a question for
the Bhaktivedanta Archives.
