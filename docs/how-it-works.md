# How the installers work

What the installers do and why. This was written while installing on an Ubuntu
24.04 server in October 2026, and the why matters most: each step fixes
something that broke when the original Windows instructions ran under Wine, or
that would break on some Windows setups.

## The inputs

**The VedaBase files.** Two Google Drive folders maintained by Ekanatha dāsa.
*VedaBase with Program* holds `Install.exe`, `Fonts\`, `Nfo\`, `Spec\`, a
README and a CrossOver-on-macOS report. *VaniBase* holds `VaniBase_25.nfo` and
`.sdw`.

`manifest/drive-files.tsv` lists all 65 files with their Drive IDs, sizes and
SHA-256 hashes. The installers download them from
`drive.usercontent.google.com` with `confirm=t`, which skips Drive's "can't
scan this file for viruses" page for the two large infobases. They reject any
file whose size or hash differs from the manifest. On Linux and macOS a broken
download resumes from where it stopped, and the two documents at the top of
the folder are skipped because installing doesn't need them.

**Wine** (Linux). Kron4ek's portable build `wine-11.0-amd64-wow64`, from the
stable branch, pinned by SHA-256. It needs no root. Because it is a WoW64
build, it runs the 32-bit Folio program without any i386 host libraries. Wine
needs `libX11` and `libXext`, plus libraries it loads at runtime: Xrender,
Xrandr, Xi, Xcursor, Xcomposite, Xinerama, Xfixes, Xxf86vm, FreeType and
fontconfig. `lib/deps.sh` fetches whichever are missing with
`apt-get download`, after `apt-get -s` has worked out the dependencies, and
unpacks them under `VEDABASE_HOME/tools`.

## The prefix

`wineboot --init` runs with `WINEDLLOVERRIDES="mscoree,mshtml=;winemenubuilder.exe=d"`.
That stops Wine offering to install Mono and Gecko, and stops it creating host
menu entries; the installer writes its own. Two more settings:

- **Windows 7.** The CrossOver report in the Drive folder says VedaBase crashed
  or would not start in a Windows 10 bottle, and worked in 7 or XP.
- **Its own desktop folder.** The prefix's Windows desktop is a real folder
  rather than Wine's usual link to yours. Otherwise the installer's two
  shortcut files would land on your actual desktop.

The prefix is private to your account (mode 0700), because it holds your notes
and the licensed files; a re-run tightens an older prefix the same way.

## Install.exe

`Install.exe` is an Indigo Rose **Setup Factory 5.0.1.6** launcher. It unpacks
`irsetup.exe` and `irsetup.dat` into `%TEMP%`, starts the wizard, and exits.
It has no silent mode, so the wizard always shows. It reads `Fonts\`, `Nfo\`
and `Spec\` from the root of its own drive, which is why Ekanatha dāsa's README
insists on `C:\`. The Linux and Mac installers symlink the downloaded folders
into `drive_c/` and remove the links afterwards.

On Linux, every wizard page is a top-level window whose title names it.
`lib/setup.sh` loops: read the visible titles, act on the page it knows, and
wait for that page to change. A page that has not moved on after 20 seconds
gets its confirming key again, up to six times, because a key can be lost
while Wine is still giving the page focus. Only the key is resent, never the
clicks, so a ticked box is never unticked.

| Window title | What `setup.sh` does |
| --- | --- |
| Pre-Install | Enter (Next) |
| License Agreement | Enter (Accept). Note the terms below. |
| User Information | types your full name from `/etc/passwd` (or `--name`), Enter |
| Important Information | Enter. This page lists the old Windows versions the program was made for. |
| Select Install Type | clicks **Custom**, Enter |
| Select Packages | ticks *All Folio Program Files* and *VedaBase Master Files*; leaves *WinAmp media player* off |
| Install Folder | Enter (default `C:\Bhaktivedanta VedaBase 2003`) |
| Shortcut Folder | Enter |
| Ready to Install | Enter (Install), then the files are copied |
| VedaBase Icons, WinAmp Install | Enter |
| Finished | Enter (Finish); it then opens the Fonts folder |
| Notice ("restart now?") | Escape (= Cancel) |
| Notice ("we recommend that you restart") | Escape (= OK) |

The click offsets are relative to the 450×333 wizard window. They hold on any
display, because Wine lays dialogs out at its own 96 DPI.

Three problems came up under Wine:

- **The intro sound.** The first thing the wizard does is "run"
  `C:\Spec\intro.wav`. Wine has nothing registered for `.wav`, so it shows an
  error box and then a Retry/Cancel box, and the wizard waits.
  `vb_make_prefix` registers `.wav` to `rundll32.exe` with no arguments, which
  does nothing. `vb_postinstall` deletes the key again; a fresh prefix has no
  `.wav` key at all.
- **The free-space check.** Before it starts the wizard, the launcher checks
  for 2 MB free on its TEMP drive, but in 32-bit arithmetic, so it refuses
  ("You must have at least 2MB of free space on your TEMP drive!") whenever
  the free space sits just above a multiple of 4 GiB, even on a disk with
  terabytes free. Where the free space is that close, the installers write a
  128 MiB filler file of random bytes until the wizard is up. Seen under Wine
  on a disk with 10 TiB free; the Windows installer does the same to be safe.
- **The restart.** The wizard ends by asking for a reboot. The installer
  answers "later", then does Wine's equivalent itself: `wineserver -k`, then
  `wineboot --restart`.

**What the installer writes.**

- *Files:* the program (`Views.exe`, the Folio 4.3 DLLs, filters) to
  `C:\Bhaktivedanta VedaBase 2003`, and the infobase into its `Nfo\` folder.
  It copies the 51 fonts into `C:\windows\Fonts` without registering them.
- *System folders:* only `mfc40.dll` (MFC 4.0, 1996) in `syswow64`. Wine has
  no built-in MFC, so Folio needs it. None of Wine's own DLLs are overwritten,
  which some Setup Factory installers do (WineHQ bug 49076).
- *Registry:* `HKCU\Software\VedaBase\4`, which holds Folio's display
  settings, and machine-wide keys under `HKLM\SOFTWARE\VedaBase\4`. Among the
  latter, the swap and index folders are set to the installing account's
  `TEMP`.
- *Shortcuts:* the main one runs
  `Views.exe "C:\Bhaktivedanta VedaBase 2003\Nfo\Bhaktivedanta Vedabase 2003.sdw"`.

**Finished means stamped.** `vb_postinstall` leaves a stamp file in the
prefix. A re-run first ends whatever an interrupted run left running (the
wizard, its hidden display), then handles the prefix in one of two ways. If
Install.exe had got as far as its last file, `irunin.ini`, with the infobase
whole, it finishes the remaining steps. If not, it moves the half-made prefix
aside, since that may still hold notes, and starts again.

## The infobase name the shadow file expects

Folio opens an infobase through its **shadow file** (`.sdw`), which holds your
own notes and highlights plus the path of its master `.nfo`. The shadow files
in the Drive folders point to the folder on the machine where they were made:

```
Bhaktivedanta Vedabase 2003.sdw -> X:\____VedaBase-VaniBase25\VedaBase_25.nfo
VaniBase_25.sdw                 -> X:\____VedaBase-VaniBase25\VaniBase_25.nfo
```

When that path is missing, Folio looks next to the shadow file for the same
file name. VaniBase's infobase has that name, so it opens. The VedaBase
infobase does not: it ships as `Bhaktivedanta VedaBase 2003.NFO`, renamed from
`VB2025.NFO` "to make the script function properly", as Ekanatha dāsa's README
explains. Under Wine the first launch therefore fails:

> Unable to open the infobase. The master infobase for this shadow,
> 'VedaBase_25.nfo' could not be found or was replaced by another infobase
> with the same name. (3706,1)

The installers add a **hard link** named `VedaBase_25.nfo` to the installed
infobase. Both names then work, and no second 649 MB copy is made. Windows
probably behaves the same, but that has not been checked; the Windows
installer adds the link anyway.

## VaniBase 25

VaniBase has no installer of its own. The installers copy `VaniBase_25.nfo`
and `VaniBase_25.sdw` into the same `Nfo\` folder, and its icon opens the
shadow file. The `.sdw` is copied only once, because your notes live in it.

## Showing it on a headless machine (Linux)

A headless server has no display, so `vedabase web` makes one. Every part runs
as you, with no root:

- **TigerVNC's `Xvnc`**, from the Ubuntu package unpacked under `tools/`.
  - *Display:* it takes an X cookie, passed to `xauth` on stdin, because every
    user on a shared server can read command lines.
  - *VNC:* it serves VNC only on a unix socket, mode 0600, in a short private
    directory: `/tmp/vedabase-<uid>`, or a new randomly named one in `/tmp`
    if another user has taken that name. Unix socket paths can't exceed 107
    bytes, which a deep `--home` would.
  - *Display number:* `-displayfd` lets Xvnc take the first display whose
    sockets it can claim completely, so a number another user has squatted
    is skipped, never shared.
  - *No TCP:* `-rfbport -1` is essential. `-rfbport 0` still opens TCP
    5900+N on every interface, as the first test run showed.
  - *Requirement:* it needs `xkbcomp` at `/usr/bin` (packages `x11-xkb-utils`
    and `xkb-data`), because the keymap compiler's path is compiled in.
- **websockify + noVNC**, also unpacked from Ubuntu packages. websockify is
  started with the system `/usr/bin/python3`, because the package is built for
  it. It listens on `127.0.0.1:6080`. A localhost port is open to every user
  of the machine, so a VNC password keeps the others out. The password is
  new each time the viewer starts, 48 bits, so failed logins are not locked
  out (`-UseBlacklist=0`): the lockout would let any local user lock you out
  through that port, and there is nothing to guess.
- **A Wine virtual desktop** (`explorer /desktop=VedaBase,1600x1000`). With no
  window manager, Folio's window would have no frame, so it couldn't be moved
  or maximized. Folio also doesn't maximize itself under Wine, so
  `vedabase web` sets `HKCU\Software\VedaBase\4\Views\Frame\Layout\AppPosition`
  (left,top,right,bottom) to fill the desktop.

The Linux installer uses the same kind of private display, a separate `Xvnc`,
so the wizard never appears on anyone's screen. Where `x11-xkb-utils` is
missing but a desktop exists (for example WSLg), it uses that desktop instead.

## Windows

`windows/install-vedabase.ps1` needs no Wine. It follows Ekanatha dāsa's
README on Windows itself, in three phases, so that each step runs as the right
account. The phases pass a random token, so a run is never fooled by an old
"done" file.

1. **User:**
   - Checks: locked-down PowerShell (Smart App Control or App Control) stops
     it with an explanation, because that policy would also block the 2003
     programs; Smart App Control in its "on" state gets a warning; and it
     checks disk space.
   - It clears the downloaded files' Mark of the Web.
   - It asks for administrator rights once, then waits for that one process.
2. **Machine** (elevated). Its working folder is
   `C:\Program Files\VedaBase-Setup`, where only administrators can create
   anything, so no other account can plant files it would trust.
   - *Download:* to the root of `C:\`, checked against the same manifest.
   - *No compatibility mode:* Windows XP mode, which devotees used against
     Folio hanging on exit under Windows 7, makes Windows 11 refuse to start
     `Views.exe` without administrator rights (error 740), so every launch
     asked for them; Folio closed normally without it on the test PC. If an
     earlier version of the installer set it, the installer deletes it and
     calls `BaseFlushAppcompatCache`, because Windows' compatibility cache
     otherwise goes on applying it.
   - *Wizard:* the original `Install.exe`, which the user clicks through. Any
     existing `.sdw` notes are copied aside first and put back afterwards,
     also when a restart cut that run short: the list of files to put back
     stays in the working folder until they are back. If
     the infobase did not arrive (*VedaBase Master Files* left unticked), it
     says so. While the wizard is still on its last pages, it adds the
     `VedaBase_25.nfo` link and VaniBase 25, so a "restart now" answered with
     OK cannot skip them.
   - *Fonts:* it registers all 51 (`manifest/fonts.tsv`). Real Windows
     loads only registered fonts, which fits the README's "drag them onto
     Fonts if the diacritics fail". It also unloads and reloads each one in
     the current sign-in: the 2003 uninstaller deletes the font files, and
     after a reinstall Windows kept the deleted copies loaded, so everything
     VedaBase draws in its own fonts came out blank until the next sign-in.
   - *Swap folders:* Folio's swap and index folders move from the installing
     account's `TEMP` to `C:\Bhaktivedanta VedaBase 2003\Temp`, which every
     account can write. It matters: saving a large note spills Folio's index
     into that folder, and where it cannot write, Folio retries for ever and
     hangs (seen under Wine with the real Folio files).
   - *Per-account settings:* `windows/vedabase-defaults.reg` holds the
     `HKCU\Software\VedaBase` values that Install.exe writes, captured from a
     fresh install. An Active Setup entry imports it at each account's next
     sign-in unless the account already has Folio's contents font set. It
     imports the copy in `C:\Program Files\VedaBase-Setup`, which only
     administrators can change; a copy any account could edit would be
     imported into every other account. Without these settings, Folio
     shows the contents pane in a plain font, so the diacritics come out as
     "Çrémad-Bhägavatam", and moves its toolbars. This was checked by
     deleting the key under Wine.
   - *Shortcuts:* the desktop icon moves to the shared desktop.
   - *Cleanup:* in the `C:\` staging folders it created, it deletes only
     files whose size and SHA-256 match the manifest, then any of those
     folders left empty.
3. **Finish** (the user again): it imports the default settings now if your
   own account lacks them, then offers to open VedaBase.

## macOS

`mac/install.sh` shares `lib/fetch.sh` and `lib/setup.sh` with Linux; both are
kept compatible with bash 3.2. It uses Gcenx's `wine-stable-11.0_1`, which is
WoW64-only and bundles FreeType and GnuTLS. That build is an x86_64 program,
so Apple Silicon runs it through Rosetta 2. If Gcenx removes the pinned build,
the installer takes the newest stable one, checked against the SHA-256 GitHub
publishes for it.

There is no xdotool on macOS, so the user clicks through the wizard. Once
the wizard (`irsetup.exe`) has gone, the installer closes what it left open,
including the Fonts window, which can sit behind other windows, as the Linux
installer does. The same Windows 7 mode, `intro.wav` handler, desktop folder
and post-install steps apply as on Linux.

It then writes two small app bundles to `~/Applications`. Each one's `launch`
script runs `Views.exe` on its shadow file. They are built locally, so
Gatekeeper never quarantines them.

## What was verified

Checked in October 2026 on Ubuntu 24.04 with Wine 11.0:

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
- Three clean unattended Linux installs: one downloading from Drive, two from
  `--source` with a local copy. Re-running `install.sh` on a finished install
  repairs it without touching the prefix.
- Deleting `HKCU\Software\VedaBase` makes the contents pane's diacritics
  garbled ("Çrémad-Bhägavatam") and moves the toolbars. Importing the captured
  defaults restores both.
- `mac/install.sh` ran to completion under a real bash 3.2.57, the version
  macOS ships. For that test, `uname`, `sw_vers`, `open` and `sips` were
  stubbed, Linux Wine stood in for the Mac build, and a helper clicked the
  wizard. The app it built opened VedaBase 25 with correct diacritics.

Checked in October 2026 on one Windows 11 Home 25H2 PC (x64), with the README's
steps (*Complete* first, then *Custom* after an uninstall): the downloads, the wizard, VedaBase
and VaniBase opening, the diacritics at Bg 2.13, search, a note kept across
restarts, no hang on exit, the fonts, the swap folders, Active Setup and the
clean-up of `C:\`, and a second run that changes nothing. Found there and
fixed: Windows PowerShell 5.1 refused to create a folder at `C:\`; Windows XP
mode made every start ask for administrator rights; a stale recent-file entry;
blank pages after an uninstall and reinstall in one sign-in (the fonts).

**Not yet verified:** a real Mac; a second account, a standard user and an
accepted restart on Windows; a real uninstall and reinstall with the font
reload in place (the reload itself ran on the test PC and the blank pages
were fixed by the same steps by hand); WineHQ bug 60494 on Apple Silicon; and
whether Windows itself needs the `VedaBase_25.nfo` link.

## The license you accept

`Install.exe` shows the 2003 Bhaktivedanta Archives license. The Linux
installer clicks Accept for you; on Windows and macOS you click it yourself.

- **Clause 2.1** "permits you to use one copy of the SOFTWARE on the Host
  Computer. For each licensed use of the SOFTWARE, which you have purchased,
  only one person may access the SOFTWARE at a time".
- **Clause 2.4** forbids copying "except to your personal archival copy
  only", use "in an on-line system", and "(h) transfer the SOFTWARE or any
  copy thereof to another party".

`vedabase backup` makes that archival copy. Any wider use is a question for
the Bhaktivedanta Archives.
