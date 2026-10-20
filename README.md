# VedaBase desktop installer

Installers for the **Bhaktivedanta VedaBase** desktop program, Folio Views 4.3,
with two infobases:

- **VedaBase 25:** Śrīla Prabhupāda's books, lecture transcripts, letters,
  conversations and the rest of his corpus.
- **VaniBase 25:** works by other devotees.

Each installer downloads Ekanatha dāsa's distribution of the files and runs
the original 2003 installer. Then it takes care of what that installer leaves
undone ([details](#what-the-installers-add)):

- **One file to double-click** on Windows and macOS, one command on Linux.
- **Every file is checked** against its SHA-256 before it is used.
- **VedaBase opens the first time.** The installers add the name the VedaBase
  icon looks for, so there is no *"master infobase … could not be found"*.
- **Diacritics display correctly.** The 51 Sanskrit fonts and Folio's display
  settings are put in place, on Windows for every account on the computer.
- **Your notes are protected.** Running an installer again leaves your
  highlights and notes alone (the Windows installer keeps them even through a
  repair), and a damaged backup never replaces a working installation.
- **The 2003 installer's quirks are handled:** its restart prompt, its intro
  sound under Wine, and a bug that can make it refuse to start on a large disk.
- **On Linux it runs unattended**, and can show VedaBase in a web browser on a
  computer with no screen.

| Your computer | What to run | Status |
| --- | --- | --- |
| Windows 10 or 11 | double-click `Install-VedaBase-Windows.cmd` | tested on one Windows 11 PC ([report](docs/windows-test-2026-10.md)) |
| Linux (Ubuntu, Debian; also WSL) | `./install.sh` in a terminal | tested end to end on Ubuntu 24.04 |
| macOS (Intel or Apple Silicon) | double-click `Install-VedaBase-Mac.command` | **not yet tried on a real Mac** |

The Windows installer has been tested on one Windows 11 PC so far, and the macOS
installer has only been checked as far as possible without a Mac. If you are
among the first to try one, please tell whoever gave you this installer how it went;
[docs/testing.md](docs/testing.md) lists what to look at, and
[What's next](#whats-next) what is planned.

**Getting the files.** On <https://github.com/Zanzagar/vedabase>, choose
**Code → Download ZIP**, or use the ZIP you were given. On Windows, right-click
the ZIP before unzipping, choose **Properties**, tick **Unblock**, and click
**OK**. Then unzip it (on Windows: right-click → *Extract All*). Keep the
unzipped folder whole, because each installer reads the `manifest` and `lib`
folders next to it.

Each installer downloads about 1.1 GB and needs about 4 GB of free space. It
checks every file against the SHA-256 in `manifest/drive-files.tsv` before
using it. Running an installer again is safe: it finishes whatever is missing.

## Windows 10 or 11

First, **S mode.** Windows in S mode runs only apps from the Microsoft Store,
so neither the installer nor VedaBase can run there. *Settings → System →
Activation* (on Windows 10, *Settings → Update & Security → Activation*) shows
whether a PC is in S mode. Switching out of it is free but cannot be undone.

1. Double-click **`Install-VedaBase-Windows.cmd`**.
   - If an *"Open File – Security Warning"* appears, click **Run**.
   - If *"Windows protected your PC"* appears, click **More info → Run anyway**.
2. Windows asks once for administrator rights, which the installer needs to
   write to `C:\` and the Fonts folder. Click **Yes**. A second window opens
   and downloads the files.
3. The original VedaBase installer then opens. A media player may open first
   to play a short welcome sound (or Windows asks which app should play it);
   close it, and the installer is behind it.
   Click through the installer:
   - **Next** → **Accept** → type your name (replace whatever it shows) →
     **Next**.
   - **Next** again. Ignore its list of old Windows versions.
   - At *Select Install Type*, choose **Custom**, then **Next**. (*Complete*
     would also install WinAmp, a 2002 media player.)
   - Tick **All Folio Program Files** and **VedaBase Master Files**. Leave
     *WinAmp* unticked. Then **Next**.
   - **Next** → **Next** → **Install** → **Next** → **Next** → **Finish**.
   - When it says your system must be restarted, choose **Cancel**, then
     **OK** on the next message. No restart is needed; if the PC does
     restart, run the `.cmd` again afterwards and it will finish the setup.
4. The installer finishes on its own:
   - it fixes the link to the infobase and adds VaniBase 25,
   - it registers the diacritic fonts with Windows,
   - it sets up Folio's display settings for every account on the PC,
   - it tidies up the setup files it put in `C:\`,
   - then it offers to open VedaBase.

Open **Bhaktivedanta VedaBase 2003** (VedaBase 25) or **VaniBase 25** from the
desktop or the Start menu.

Notes:

- **Freeze on exit.** If VedaBase freezes when you close it, end it from
  Task Manager (Ctrl+Shift+Esc). This is a known problem with this 2003
  program on newer Windows, though it did not happen on the Windows 11 PC it
  was tested on. Do not turn on Windows XP compatibility mode against it, as
  devotees did on Windows 7: on Windows 11 it makes VedaBase ask for
  administrator rights every time it starts. (The installer removes it if an
  earlier version of the installer set it.)
- **Leaving out VaniBase.** Open the unzipped folder, click the address bar,
  type `cmd` and press Enter. In the window that opens, type
  `.\Install-VedaBase-Windows.cmd -NoVaniBase` and press Enter.
- **Smart App Control.** If Windows blocks the 2003 programs, Smart App
  Control is the likely cause (*Windows Security → App & browser control*).
  Turning it off lets VedaBase run. On Windows 11 with the updates since March
  2026 you can turn it back on later from the same page; on older versions
  that needs a reset of Windows, so decide carefully. The installer warns you
  if it is on.

## macOS (Intel or Apple Silicon)

1. Double-click **`Install-VedaBase-Mac.command`**. If macOS refuses to open
   it, see [below](#if-macos-will-not-open-the-installer).
2. On Apple Silicon it first installs Rosetta 2 if it is missing. That needs
   an administrator account, and macOS asks for your password. It then
   downloads a free Wine for macOS (Gcenx's build, which WineHQ distributes;
   CrossOver is not needed) and the VedaBase files. Keep the lid open until
   it is done: the installer stops the Mac from going to sleep, but closing
   the lid still sends it to sleep.
3. The original installer opens. Click through it as in the Windows steps
   above: **Custom**, tick the first two packages, **Install**, **Finish**.
   Answer the restart questions either way. The Terminal window then closes
   the Fonts window the installer opens, and finishes.
4. It finishes the setup and puts **VedaBase 25** and **VaniBase 25** apps in
   the `Applications` folder inside your home folder. Drag them to the Dock if
   you like. In VedaBase, ⌘C and ⌘V copy and paste.

Everything lives in `~/Library/Application Support/VedaBase`, about 3.5 GB.

### If macOS will not open the installer

macOS blocks downloaded scripts that Apple has not notarized. The way that
always works:

1. Open **Terminal**, which is in Applications → Utilities.
2. Type `bash ` (with a space after it).
3. Drag `Install-VedaBase-Mac.command` from the Finder into the Terminal
   window, then press Return.
4. If macOS asks whether Terminal may access your Downloads folder, click
   **OK**. If you clicked *Don't Allow* before, turn Terminal on under
   *System Settings → Privacy & Security → Files and Folders*.

Alternatively, on macOS 15 or later click **Done** on the warning, then go to
**System Settings → Privacy & Security** and click **Open Anyway** next to the
file. On macOS 14 or earlier, Control-click the file and choose **Open**.

### How long the free Mac route will work

The free Wine for macOS is an Intel program. On Intel Macs it runs on macOS
10.15.4 through 26. On Apple Silicon it runs through Apple's Rosetta 2, which
Apple says will be limited to games from macOS 28 (expected autumn 2027). After
that, the free route probably ends on Apple Silicon Macs.

There is also an open WineHQ bug (60494): on Apple Silicon, some 32-bit Windows
programs crash or hang at random under Rosetta. Whether it affects VedaBase is
not known yet.

## Linux (Ubuntu, Debian; also WSL)

Once, install the tools the installer needs:

```bash
sudo apt-get install git curl xz-utils x11-xkb-utils xkb-data
```

On a desktop, `x11-xkb-utils` and `xkb-data` are usually there already. On a
server they let the installer run the original setup out of sight. After that
no root is needed:

```bash
git clone https://github.com/Zanzagar/vedabase.git ~/vedabase   # or unzip the ZIP
~/vedabase/install.sh
vedabase              # VedaBase 25: a window on a desktop, else the browser viewer
vedabase vanibase     # VaniBase 25
```

Running `install.sh` accepts the Bhaktivedanta Archives license that the
original installer shows (see [License](#license)), because it clicks Accept
for you. It answers the other screens too, in a hidden display, using a pinned
portable Wine (11.0). This takes a few minutes. Afterwards, *VedaBase 25* and
*VaniBase 25* also appear in the desktop's application menu. If the
`vedabase` command is not found at first, log out and back in, or run
`~/.local/bin/vedabase`.

`install.sh --help` lists the options: where to install (`--home`), leaving
out VaniBase, reinstalling, installing from a local copy of the files, and
restoring a backup.

**WSL on Windows:** prefer the Windows installer, since Folio is a Windows
program and runs natively there. If you do use WSL, the Windows Start menu
only picks up entries from `/usr/share/applications`. `install.sh` copies them
there when `sudo` needs no password, and otherwise prints the one command to
run.

### On a computer with no screen

On a server you reach over SSH, either of these works:

- **Browser (nothing to install on your own computer):** run `vedabase web`.
  It prints an `ssh -N -L 6080:…` tunnel command and a `http://localhost:6080/…`
  link. Run the tunnel on your computer, open the link, and VedaBase appears in
  the browser. Stop it with `vedabase stop`.
- **X11 forwarding:** with an X server on your computer, connect with
  `ssh -X`, then run `vedabase`.

The browser viewer is for the licensed user only, and it is private. Its
display has an X cookie and a VNC socket only your account can open. The page
listens only on `127.0.0.1`, and it asks for a password that is new each time
the viewer starts and is included in the printed link.

### Commands

| Command | What it does |
| --- | --- |
| `vedabase`, `vedabase vanibase` | open VedaBase 25 or VaniBase 25: a window if there is a display, else the browser viewer |
| `vedabase open INFOBASE` | open in a window on this display (`vedabase`, `vanibase`, `help` for Folio's own help, or `folio`) |
| `vedabase web INFOBASE` | headless: private display + browser link via SSH tunnel |
| `vedabase stop` | close VedaBase and the browser viewer |
| `vedabase status` | what is running, and the browser link |
| `vedabase doctor` | check the installation |
| `vedabase backup [FILE]` | save the program, the infobases **and your notes** as one `.tar.gz` |
| `vedabase where` | print where everything is |

Everything (about 3.5 GB) goes in `~/.local/share/vedabase` unless you choose
another place with `--home`. Choose a local disk if your home directory is
small or on a network share.

## Your notes are in the shadow files

Folio keeps your highlights, bookmarks and notes in the shadow files (the
files ending in `.sdw`), next to the infobases:

- **Windows:** `C:\Bhaktivedanta VedaBase 2003\Nfo`. Windows may hide the
  `.sdw` ending; the files are *Bhaktivedanta Vedabase 2003* and *VaniBase_25*.
- **macOS:** `~/Library/Application Support/VedaBase/prefix/drive_c/Bhaktivedanta VedaBase 2003/Nfo`.
  In the Finder, use *Go → Go to Folder…* and paste the path.
- **Linux:** `~/.local/share/vedabase/prefix/drive_c/Bhaktivedanta VedaBase 2003/Nfo`,
  or `vedabase where`. `vedabase backup` saves the whole installation, and
  `install.sh --restore FILE` puts it back on any Linux computer without
  running the installer again. Restore only a backup you made yourself: it
  holds programs that run as you.

Copy the `.sdw` files somewhere safe before reinstalling or uninstalling.

## If something goes wrong

Run the installer again first: it continues where it stopped. On Windows, if
VedaBase opens with blank pages after you uninstalled and reinstalled it, sign
out of Windows and back in (or restart). If that doesn't help, send whoever
gave you this installer a description, plus:

- **Windows:** a photo or screenshot of the error, and the log
  `C:\Program Files\VedaBase-Setup\install.log`.
- **macOS:** the Terminal text, and the folder
  `~/Library/Application Support/VedaBase/logs`.
- **Linux:** the output of `vedabase doctor`, and the folder
  `~/.local/share/vedabase/logs`.

### If the download breaks

The files come from public Google Drive links owned by Ekanatha dāsa.

- **"did not arrive intact".** Usually Google Drive is limiting downloads of
  a busy file for a while. Wait a few hours, then run the installer again.
- **The files changed.** If Ekanatha dāsa replaces them, the installers refuse
  the new files rather than install something unchecked, and they need an
  update.
- **Linux, installing from a copy.** You can install from a copy you already
  have, laid out like the Drive folders (`Install.exe`, `Fonts/`, `Nfo/`,
  `Spec/`, `VaniBase/`). The Windows and Mac installers have no such option
  yet.

```bash
./install.sh --source /path/to/copy
./install.sh --source you@server:/path/to/vedabase/downloads   # needs ssh login with a key
```

## Removing VedaBase

- **Windows:**
  - First copy your `.sdw` files out of `C:\Bhaktivedanta VedaBase 2003\Nfo`:
    uninstalling deletes the VedaBase one.
  - Uninstall *Bhaktivedanta VedaBase 2003* in *Settings → Apps*.
  - Delete `C:\Bhaktivedanta VedaBase 2003`, `C:\Program Files\VedaBase-Setup`,
    the *Bhaktivedanta VedaBase 2003* and *VaniBase 25* icons on the desktop,
    and the *Bhaktivedanta VedaBase 2003* folder in the Start menu.
- **macOS:** delete `~/Library/Application Support/VedaBase` and the two
  apps in `~/Applications`.
- **Linux:** delete the folder shown by `vedabase where` (home), the launcher
  `~/.local/bin/vedabase`, `~/.config/vedabase`, and
  `~/.local/share/applications/vedabase.desktop` and `vanibase.desktop`.

## Copying text out

The infobases store diacritics in the old 8-bit Balaram/SCA font encoding.
Copied text looks right only in those fonts, and shows odd characters
elsewhere until it is converted to Unicode.

## What the installers add

Each installer runs the original installer, then takes care of these:

- **The infobase link.** The shadow file that the VedaBase icon opens looks
  for its infobase under the name `VedaBase_25.nfo`, the name on the machine
  where it was made. The infobase itself ships as
  `Bhaktivedanta VedaBase 2003.NFO`, renamed from `VB2025.NFO` so that the 2003
  install script finds it. Under Wine the first launch then fails with *"The
  master infobase for this shadow, 'VedaBase_25.nfo' could not be found"*.
  The installers add `VedaBase_25.nfo` as a second name for the same file.
  This has not been checked on Windows yet; the Windows installer does it to
  be safe.
- **Fonts and settings.** Under Wine, the original installer copies the 51
  diacritic fonts but does not register them. It also writes its display
  settings only for the account that ran it. Missing either one leaves
  Sanskrit words garbled. The installers register the fonts and give every
  account the settings.
- **The intro sound.** On Linux and macOS, the installer would stall on its
  intro sound under Wine.

[docs/how-it-works.md](docs/how-it-works.md) explains every step and records
what was verified. [docs/sources.md](docs/sources.md) summarizes the original
instructions. [docs/testing.md](docs/testing.md) is the checklist for a first
run on a new system.

## What's next

The installers get better as reports come in:

- **The first run on a Mac**, and runs on more Windows PCs. What they show
  will correct these steps wherever they differ.
- **What Windows updates broke.** Some Folio features have stopped working on
  newer Windows. Once it is known which, the installers can add workarounds,
  as they already try to for the freeze on exit.
- **Unicode text.** Text copied out of VedaBase uses the old Balaram encoding
  (see [Copying text out](#copying-text-out)). A converter to standard Unicode
  would make it usable in other programs, including AI tools.
- **New releases.** When Ekanatha dāsa publishes a new VedaBase, the
  installers need only an updated `manifest/drive-files.tsv`.

## License

The scripts and documents in this repository are under the MIT license (see
[LICENSE](LICENSE)). It covers only them, not VedaBase. This repository
contains none of the VedaBase program or texts: everything is downloaded at
install time from Ekanatha dāsa's links.

VedaBase itself comes with the 2003 Bhaktivedanta Archives license, which the
original installer shows and which installing accepts:

- **Clause 2.1** "permits you to use one copy of the SOFTWARE on the Host
  Computer", "for each licensed use of the SOFTWARE, which you have
  purchased", with "only one person" using it at a time.
- **Clause 2.4** forbids copying "except to your personal archival copy",
  using it "in an on-line system", and "(h) transfer the SOFTWARE or any copy
  thereof to another party".

Questions about wider use are for the Bhaktivedanta Archives.

Thanks to Ekanatha dāsa for maintaining the VedaBase files and instructions,
and to Tāraka dāsa for sharing them. Wine builds come from
[Kron4ek](https://github.com/Kron4ek/Wine-Builds) (Linux) and
[Gcenx](https://github.com/Gcenx/macOS_Wine_builds) (macOS).
