# VedaBase desktop installer

Installs the **Bhaktivedanta VedaBase** desktop client: Folio Views 4.3 with the
**VedaBase 25** and **VaniBase 25** infobases. It uses the files Tāraka dāsa
shared from Ekanatha dāsa's Google Drive. The program is a 2003 Windows
installer. This repo wraps it in one installer per system, and adds two fixes
that installation needs (see [How it works](#how-it-works-and-the-license)).

| Your computer | What to run | Status |
| --- | --- | --- |
| Windows 10 or 11 | double-click `Install-VedaBase-Windows.cmd` | written; needs a first test on Windows |
| Linux (Ubuntu, Debian; also WSL) | `./install.sh` in a terminal | tested end to end (Ubuntu 24.04) |
| macOS (Intel or Apple Silicon) | double-click `Install-VedaBase-Mac.command` | written; needs a first test on a Mac |

To get the files: on GitHub use **Code → Download ZIP** and unzip it, or run
`git clone https://github.com/Zanzagar/vedabase.git`. Keep the folder whole,
because each installer reads `manifest/` and `lib/`.

All three installers download the same files (about 1.1 GB) and check each
one against the SHA-256 in `manifest/drive-files.tsv` before using it. All
three are safe to run again, and a re-run finishes whatever is missing.

## Windows 10 or 11

1. Double-click **`Install-VedaBase-Windows.cmd`**. Windows asks for
   administrator rights, because the installer writes to `C:\` and the Fonts
   folder. Say yes. If a blue *"Windows protected your PC"* box appears, click
   *More info → Run anyway*. That happens with any downloaded script.
2. It downloads the files to the root of `C:\`, which is where Ekanatha's
   README says they must go. Then it opens the original installer. Click
   through it:
   - Next → **Accept** → type your name → Next.
   - *Select Install Type*: **Custom** → Next.
   - Tick **All Folio Program Files** and **VedaBase Master Files**. Leave
     *WinAmp* unticked.
   - Next → Next → **Install** → Next → **Finish**.
   - If it offers to restart now, choose **Cancel**. If the PC does restart,
     double-click the `.cmd` again afterwards to finish.
3. The script then:
   - fixes the infobase link (below),
   - adds VaniBase 25 with desktop and Start-menu icons,
   - installs any fonts Windows missed,
   - removes the setup files it put in `C:\`.

Open **Bhaktivedanta VedaBase 2003** (VedaBase 25) or **VaniBase 25** from the
desktop or the Start menu.

Two options for `windows\install-vedabase.ps1`: `-NoVaniBase` skips VaniBase,
and `-NoCompatMode` skips setting Windows XP compatibility on Views.exe. XP
compatibility was a known fix for Folio hanging on exit under Windows 7; one
2015 report says it didn't help on Windows 10.

## Linux (Ubuntu / Debian / WSL)

```bash
git clone https://github.com/Zanzagar/vedabase.git ~/projects/vedabase
~/projects/vedabase/install.sh
vedabase              # VedaBase 25 (a window on a desktop, else the browser viewer)
vedabase vanibase     # VaniBase 25
```

- **No root needed.** Missing libraries are unpacked from Ubuntu packages
  into the install folder.
- **It runs the original `Install.exe` for you**, in a hidden display, and
  answers every screen; this takes a few minutes. It uses a pinned portable
  Wine (11.0).
- **Options:** `install.sh --help` covers install location, VaniBase on or
  off, reinstall, and restore from a backup.

On a desktop, *VedaBase 25* and *VaniBase 25* also appear in the application
menu.

**On WSL:** use the Windows installer instead if you can. Folio is a Windows
program, so it runs natively there with no VM in between. If you do use WSL,
the Windows Start menu only picks up entries from `/usr/share/applications`.
`install.sh` puts them there when `sudo` needs no password, and otherwise
prints the one command to run.

### On journel (no screen)

- **Browser (nothing to install on your PC):** run `vedabase web`. It prints
  an `ssh -N -L 6080:…` tunnel command and a `http://localhost:6080/…` link.
  Run the tunnel on your PC, then open the link. To keep it permanently, add
  a local forward 6080 → 127.0.0.1:6080 to the Tabby *journel* profile, next
  to the 8888 one. Stop it with `vedabase stop`.
- **X11 forwarding:** with an X server on your PC (VcXsrv, or MobaXterm's),
  `ssh -X journel` and then `vedabase`.

The browser viewer is private. Its display has an X cookie and a VNC socket
only you can open. The page listens only on `127.0.0.1` and asks for a
password, which is the one in the printed link.

### Commands

| Command | What it does |
| --- | --- |
| `vedabase [vedabase\|vanibase\|help\|folio]` | open it: a window if there is a display, else the browser viewer |
| `vedabase open INFOBASE` | open in a window on this display |
| `vedabase web INFOBASE` | headless: private display + browser link via SSH tunnel |
| `vedabase stop` | close VedaBase and the browser viewer |
| `vedabase status` | what is running, and the browser link |
| `vedabase doctor` | check the installation |
| `vedabase backup [FILE]` | save the prefix (program, infobases, **your notes**) as `.tar.gz` |
| `vedabase where` | print the paths |

`VEDABASE_HOME` holds everything, about 3 GB. It defaults to
`~/.local/share/vedabase`, or `/journel/s0/$USER/vedabase` on journel, whose
home directory is a 40 GiB NFS quota.

## macOS (Intel or Apple Silicon)

1. Double-click **`Install-VedaBase-Mac.command`**. If macOS refuses to open
   it ("unidentified developer" or "cannot be verified"), see
   [below](#if-macos-will-not-open-the-installer).
2. On Apple Silicon it first installs Rosetta 2 if needed, which asks for your
   password. Then it downloads a free Wine build for macOS (Gcenx's, which
   WineHQ distributes) and the VedaBase files.
3. The original installer opens. Click through it as in the Windows steps
   above: Custom, tick the first two packages, Install, Finish. Then close
   the Fonts window it opens.
4. It finishes the setup and puts **VedaBase 25** and **VaniBase 25** apps in
   your `Applications` folder, inside your home folder. Drag them to the Dock
   if you like.

No CrossOver is needed. Everything lives in
`~/Library/Application Support/VedaBase`.

### If macOS will not open the installer

macOS blocks scripts downloaded from the internet unless Apple has notarized
them:

- **macOS 15 or later:** click **Done** on the warning. Open
  **System Settings → Privacy & Security**, scroll down, and click
  **Open Anyway** next to `Install-VedaBase-Mac.command`. Do this within about
  an hour. Enter your password, then click **Open**.
- **macOS 14 or earlier:** Control-click the file and choose **Open**.
- **Any version:** open **Terminal**, type `bash ` (with a space), drag
  `Install-VedaBase-Mac.command` into the window, and press Return.

### How long the free Mac route will work

The free Wine for macOS is an Intel program. On Intel Macs it runs on macOS
10.15.4 through 26. On Apple Silicon it runs through Apple's Rosetta 2, which
Apple says will be limited to games from macOS 28 (expected autumn 2027). After
that, the free route probably ends on Apple Silicon Macs. The only announced
alternative is paid CrossOver. Check again before then.

## Your notes are in the shadow files

Folio keeps your highlights, bookmarks and notes in the shadow files
(`Nfo\*.sdw`), next to the infobases:

- Windows: `C:\Bhaktivedanta VedaBase 2003\Nfo`.
- Linux and macOS: inside the Wine prefix. On Linux, `vedabase backup`
  saves the whole prefix, and `install.sh --restore FILE` puts it back on any
  Linux machine without re-running the installer.

`install.sh --reinstall` deletes the prefix, so back up first.

## If the download breaks

The files come from public Drive links owned by Ekanatha dāsa. If they move or
change, the installers stop with an error instead of installing something
else. On Linux you can install from a copy you already have, laid out like the
Drive folders (`Install.exe`, `Fonts/`, `Nfo/`, `Spec/`, `VaniBase/`):

```bash
./install.sh --source /path/to/copy
./install.sh --source journel.eme.psu.edu:/journel/s0/$USER/vedabase/downloads
```

journel keeps an archival copy in `/journel/s1/cjh5690/archive/vedabase/`.

## Copying text out

The infobases store diacritics in the old 8-bit Balaram/SCA font encoding.
Copied text therefore looks right only in those fonts, and shows odd
characters elsewhere until it is converted to Unicode.

## How it works, and the license

[docs/how-it-works.md](docs/how-it-works.md) covers every step and why it is
there, and records what was verified. It includes the two fixes Ekanatha's
README doesn't mention:

- The shipped shadow file points at `VedaBase_25.nfo`, a name the install
  renames away, so Folio cannot open it until a link restores that name.
  This affects Windows too.
- Under Wine, the installer stalls on its intro sound.

[docs/sources.md](docs/sources.md) summarizes Tāraka's messages, Ekanatha's
README and the CrossOver report. [docs/testing.md](docs/testing.md) is the
checklist for the first Windows and Mac runs.

`Install.exe` shows the 2003 Bhaktivedanta Archives license, which you accept
by installing. It allows one copy on one computer, used by one person at a
time, plus a personal archival copy, and forbids use "in an on-line system".
Nothing copyrighted is in this repo. Everything is downloaded at install time
from Ekanatha's links.

Credits: the files and the original instructions come from Ekanatha dāsa and
Tāraka dāsa. Wine builds come from
[Kron4ek](https://github.com/Kron4ek/Wine-Builds) (Linux) and
[Gcenx](https://github.com/Gcenx/macOS_Wine_builds) (macOS).
