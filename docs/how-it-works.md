# How the installer works

What `install.sh` does and why, written down on 2026-10-19 while installing on
journel. The why matters most: each step below fixes something that broke when
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

journel has no display, so `vedabase web` makes one. Every part runs as you,
with no root:

- **TigerVNC's `Xvnc`**, from the Ubuntu package unpacked under
  `tools/`. It takes an X cookie, and serves VNC only on a unix socket with
  mode 0600. It does need `xkbcomp` at `/usr/bin` (package `x11-xkb-utils`),
  because the keymap compiler's path is compiled into it.
- **websockify + noVNC**, also unpacked from Ubuntu packages. websockify is
  started with the system `/usr/bin/python3`, because the package is built for
  it. It listens on `127.0.0.1:6080`, and the VNC password (in
  `run/web/password`) keeps out other local users, since a localhost port is
  open to everyone on journel.
- **A Wine virtual desktop** (`explorer /desktop=VedaBase,1600x1000`). Without
  a window manager, Folio's window would have no frame, so it couldn't be
  moved or maximized. Folio also doesn't maximize itself under Wine, so
  `vedabase web` sets `HKCU\Software\VedaBase\4\Views\Frame\Layout\AppPosition`
  (left,top,right,bottom) to fill the desktop.

The installer uses the same kind of private display: a separate `Xvnc`, so the
wizard never appears on anyone's screen. Where `x11-xkb-utils` is missing but
a desktop exists (for example WSLg), it uses that desktop instead.

## What was verified on journel

Checked 2026-10-19 on Ubuntu 24.04 with Wine 11.0:

- VedaBase 25 opens at record 1 of 1,613,056.
- Bg 2.13 renders with Devanagari, transliteration (*dehino 'smin yathā dehe*),
  synonyms, translation and purport.
- A search for "krsna Bhaktisiddhanta" in VaniBase 25 (518,550 records)
  returned 50 hits. VedaBase's language module (`nlsveda.dll`) works, since the
  query matched diacritic forms.

## The license you accept

`Install.exe` shows the 2003 Bhaktivedanta Archives license, and the
installer accepts it on your behalf. Clause 2.1: "permits you to use one copy
of the SOFTWARE on the Host Computer … only one person may access the SOFTWARE
at a time". Clause 2.4 forbids copying "except to your personal archival
copy" and use "in an on-line system". The `vedabase backup` tarball is that
archival copy. Installing on more than one machine, or giving it to others,
goes beyond the license's wording; ask Tāraka how he handles that.
