# VedaBase desktop installer

Installers for the **Bhaktivedanta VedaBase** desktop program, Folio Views 4.3,
with two infobases:

- **VedaBase 25:** Śrīla Prabhupāda's books, lecture transcripts, letters,
  conversations and the rest of his corpus.
- **VaniBase 25:** works by other devotees.

They download Ekanatha dāsa's distribution of the files, check every file, run
the original 2003 installer, and then fix two problems that otherwise stop
VedaBase from opening correctly (see [Why these installers exist](#why-these-installers-exist)).

| Your computer | What to run | Status |
| --- | --- | --- |
| Windows 10 or 11 | double-click `Install-VedaBase-Windows.cmd` | ready for its first real-world test |
| Linux (Ubuntu, Debian; also WSL) | `./install.sh` in a terminal | tested end to end on Ubuntu 24.04 |
| macOS (Intel or Apple Silicon) | double-click `Install-VedaBase-Mac.command` | ready for its first real-world test |

**Get the files.** On the GitHub page, use **Code → Download ZIP**. Before
unzipping on Windows, right-click the ZIP, choose **Properties**, tick
**Unblock**, then click **OK**. Then unzip it (on Windows: right-click →
*Extract All*). Keep the folder whole, because each installer reads the
`manifest` and `lib` folders next to it.

Each installer downloads about 1.1 GB, and checks every file against the
SHA-256 in `manifest/drive-files.tsv` before using it. Running an installer
again is safe: it finishes whatever is missing.

## Windows 10 or 11

1. Double-click **`Install-VedaBase-Windows.cmd`**.
   - If an *"Open File – Security Warning"* appears, click **Run**.
   - If *"Windows protected your PC"* appears, click **More info → Run anyway**.
2. Windows asks once for administrator rights, which the installer needs to
   write to `C:\` and the Fonts folder. Click **Yes**. A second window opens
   and downloads the files.
3. The original VedaBase installer then opens. Click through it:
   - **Next** → **Accept** → type your name → **Next** → **Next**.
   - At *Select Install Type*, choose **Custom**, then **Next**.
   - Tick **All Folio Program Files** and **VedaBase Master Files**. Leave
     *WinAmp* unticked. Then **Next**.
   - **Next** → **Next** → **Install** → **Next** → **Finish**.
   - If it offers to restart, choose **Cancel**. If the PC does restart, run
     the `.cmd` again afterwards and it will finish the setup.
4. The installer finishes on its own:
   - it fixes the link to the infobase and adds VaniBase 25,
   - it registers the diacritic fonts with Windows,
   - it restores Folio's display settings if they are missing,
   - it tidies up the setup files it put in `C:\`,
   - then it offers to open VedaBase.

Open **Bhaktivedanta VedaBase 2003** (VedaBase 25) or **VaniBase 25** from the
desktop or the Start menu.

Notes:

- **Smart App Control.** If Windows blocks the 2003 programs, turn off Smart
  App Control in *Windows Security → App & browser control*. The installer
  warns you when it is on.
- **Freeze on exit.** If VedaBase freezes when you close it, end it from
  Task Manager (Ctrl+Shift+Esc). This is a known problem with this 2003
  program on newer Windows. The installer sets Windows XP compatibility mode,
  which devotees used against it on Windows 7, though one report says it did
  not help on Windows 10. Run `windows\install-vedabase.ps1 -NoCompatMode`
  to skip setting it.
- **Without VaniBase.** Run `windows\install-vedabase.ps1 -NoVaniBase`.

## macOS (Intel or Apple Silicon)

1. Double-click **`Install-VedaBase-Mac.command`**. If macOS refuses to open
   it, see [below](#if-macos-will-not-open-the-installer).
2. On Apple Silicon it first installs Rosetta 2 if it is missing. That needs
   an administrator account, and macOS asks for your password. It then
   downloads a free Wine for macOS (Gcenx's build,
   which WineHQ distributes; CrossOver is not needed) and the VedaBase files.
3. The original installer opens. Click through it as in the Windows steps
   above: **Custom**, tick the first two packages, **Install**, **Finish**.
   Answer the restart questions either way, and close the Fonts window it opens.
4. The Terminal window finishes the setup and puts **VedaBase 25** and
   **VaniBase 25** apps in the `Applications` folder inside your home folder.
   Drag them to the Dock if you like. In VedaBase, ⌘C and ⌘V copy and paste.

Everything lives in `~/Library/Application Support/VedaBase`.

### If macOS will not open the installer

macOS blocks downloaded scripts that Apple has not notarized. The way that
always works:

1. Open **Terminal**, which is in Applications → Utilities.
2. Type `bash ` (with a space after it).
3. Drag `Install-VedaBase-Mac.command` from the Finder into the Terminal
   window, then press Return.
4. If macOS asks whether Terminal may access your Downloads folder, click
   **OK**.

Alternatively, on macOS 15 or later click **Done** on the warning, then go to
**System Settings → Privacy & Security** and click **Open Anyway** next to the
file. On macOS 14 or earlier, Control-click the file and choose **Open**.

### How long the free Mac route will work

The free Wine for macOS is an Intel program. On Intel Macs it runs on macOS
10.15.4 through 26. On Apple Silicon it runs through Apple's Rosetta 2, which
Apple says will be limited to games from macOS 28 (expected autumn 2027). After
that, the free route probably ends on Apple Silicon Macs. The only announced
alternative is paid CrossOver.

There is also an open WineHQ bug (60494): on Apple Silicon, some 32-bit Windows
programs crash or hang at random under Rosetta. Nobody has tried VedaBase on a
Mac with these installers yet, so the first Mac run is also the test of this.

## Linux (Ubuntu, Debian; also WSL)

```bash
git clone https://github.com/Zanzagar/vedabase.git ~/vedabase
~/vedabase/install.sh
vedabase              # VedaBase 25: a window on a desktop, else the browser viewer
vedabase vanibase     # VaniBase 25
```

- **No root needed.** It uses a pinned portable Wine (11.0). Missing
  libraries are unpacked from Ubuntu's own packages into the install folder.
- **It answers the original installer's screens itself**, in a hidden
  display; this takes a few minutes. VedaBase 25 and VaniBase 25 then appear
  in the desktop's application menu.
- **Options:** `install.sh --help` covers where to install (`--home`), leaving
  out VaniBase, reinstalling, installing from a local copy of the files, and
  restoring a backup.

**WSL on Windows:** prefer the Windows installer. Folio is a Windows program,
so it runs natively there with nothing in between. If you do use WSL, the
Windows Start menu only picks up entries from `/usr/share/applications`.
`install.sh` copies them there when `sudo` needs no password, and otherwise
prints the one command to run.

### On a computer with no screen

On a server you reach over SSH, either of these works:

- **Browser (nothing to install on your own computer):** run `vedabase web`.
  It prints an `ssh -N -L 6080:…` tunnel command and a `http://localhost:6080/…`
  link. Run the tunnel on your computer, open the link, and VedaBase appears in
  the browser. Stop it with `vedabase stop`.
- **X11 forwarding:** with an X server on your computer, connect with
  `ssh -X`, then run `vedabase`.

The browser viewer is private. Its display has an X cookie and a VNC socket
only your account can open. The page listens only on `127.0.0.1` and asks for
the password included in the printed link.

### Commands

| Command | What it does |
| --- | --- |
| `vedabase [vedabase\|vanibase\|help\|folio]` | open it: a window if there is a display, else the browser viewer |
| `vedabase open INFOBASE` | open in a window on this display |
| `vedabase web INFOBASE` | headless: private display + browser link via SSH tunnel |
| `vedabase stop` | close VedaBase and the browser viewer |
| `vedabase status` | what is running, and the browser link |
| `vedabase doctor` | check the installation |
| `vedabase backup [FILE]` | save the program, the infobases **and your notes** as one `.tar.gz` |
| `vedabase where` | print where everything is |

Everything (about 3 GB) goes in `~/.local/share/vedabase` unless you choose
another place with `--home`. Choose a local disk if your home directory is
small or on a network share.

## Your notes are in the shadow files

Folio keeps your highlights, bookmarks and notes in the shadow files
(`Nfo\*.sdw`), next to the infobases:

- Windows: `C:\Bhaktivedanta VedaBase 2003\Nfo`.
- macOS and Linux: inside the Wine prefix. On Linux, `vedabase backup`
  saves the whole installation. `install.sh --restore FILE` puts it back on
  any Linux computer without running the installer again.

Back up before reinstalling.

## If the download breaks

The files come from public Google Drive links owned by Ekanatha dāsa. If they
move or change, the installers stop with an error instead of installing
something else. On Linux you can install from a copy you already have, laid
out like the Drive folders (`Install.exe`, `Fonts/`, `Nfo/`, `Spec/`,
`VaniBase/`):

```bash
./install.sh --source /path/to/copy
./install.sh --source you@server:/path/to/vedabase/downloads
```

## Copying text out

The infobases store diacritics in the old 8-bit Balaram/SCA font encoding.
Copied text looks right only in those fonts, and shows odd characters
elsewhere until it is converted to Unicode.

## Why these installers exist

Following Ekanatha's README by hand runs into two problems:

- **VedaBase doesn't open at first.** The shadow file that the VedaBase icon
  opens looks for its infobase under the name `VedaBase_25.nfo`. The README
  renamed that file to `Bhaktivedanta VedaBase 2003.NFO` so the 2003 install
  script would find it. The first launch then fails with *"The master infobase
  for this shadow, 'VedaBase_25.nfo' could not be found"*. The installers
  restore the old name as a link to the same file.
- **Fonts and settings can go missing.** The installer copies the 51
  diacritic fonts but, at least under Wine, does not register them. Its
  display settings also go to whichever account ran it. Missing either one
  leaves Sanskrit words garbled. The installers take care of both.

On Linux and macOS, Wine adds one more problem: the installer stalls on its
intro sound.

[docs/how-it-works.md](docs/how-it-works.md) explains every step and records
what was verified. [docs/sources.md](docs/sources.md) summarizes the original
instructions. [docs/testing.md](docs/testing.md) is the checklist for a first
run on a new system.

## License

`Install.exe` shows the 2003 Bhaktivedanta Archives license, which installing
accepts. It allows one copy on one computer, used by one person at a time,
plus a personal archival copy, and forbids use "in an on-line system". This
repository contains none of the VedaBase program or texts. Everything is
downloaded at install time from Ekanatha dāsa's links.

Thanks to Ekanatha dāsa for maintaining the VedaBase files and instructions, and
to Tāraka dāsa for sharing them. Wine builds come from
[Kron4ek](https://github.com/Kron4ek/Wine-Builds) (Linux) and
[Gcenx](https://github.com/Gcenx/macOS_Wine_builds) (macOS).
