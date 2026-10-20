# VedaBase desktop installer

Installs the **Bhaktivedanta VedaBase** desktop client: Folio Views 4.3 with the
**VedaBase 25** and **VaniBase 25** infobases. It uses the files Tāraka dāsa
shared from Ekanatha dāsa's Google Drive. The original program is a 2003
Windows installer; this repo turns it into one command on Linux, including
WSL.

**Status:** Linux (Ubuntu 24.04) is tested end to end on journel. Windows
10/11 and macOS installers are in progress; see [Other systems](#other-systems).

## Install (Linux / WSL)

```bash
gh repo clone Zanzagar/vedabase ~/projects/vedabase   # or: git clone https://github.com/Zanzagar/vedabase.git
~/projects/vedabase/install.sh
```

What to expect:

- **No root needed.** It downloads about 1.2 GB (Wine, then the VedaBase
  files, each checked against a SHA-256 in `manifest/`).
- **It runs the original `Install.exe` for you**, in a hidden display, and
  answers every screen. That takes a few minutes.
- **Re-running is safe.** Finished steps are skipped, so `install.sh` also
  repairs an install. `--help` lists the options: install location, VaniBase
  on or off, reinstall, restore from a backup.

Then:

```bash
vedabase              # VedaBase 25 (a window on a desktop, else the browser viewer)
vedabase vanibase     # VaniBase 25
```

On a desktop, or under WSLg, the menu entries *VedaBase 25* and *VaniBase 25*
appear as well.

## Using it on journel (no screen)

journel has no display, so pick one of these:

- **Browser (nothing to install on your PC):** run `vedabase web`. It prints
  an `ssh -N -L 6080:…` tunnel command and a `http://localhost:6080/…` link.
  Run the tunnel on your PC, then open the link. To keep the tunnel
  permanently, add a local forward 6080 → 127.0.0.1:6080 to the Tabby
  *journel* profile, alongside the 8888 one for Jupyter. Stop it with
  `vedabase stop`.
- **X11 forwarding:** if your PC runs an X server (VcXsrv, or MobaXterm's
  built-in one), `ssh -X journel` and then `vedabase`. journel's sshd allows
  X11 forwarding.

The browser viewer is private. Its display has an X cookie and a VNC
socket only you can open. The viewer listens only on `127.0.0.1`, and asks for
a password, which is the one in the printed link.

## Commands

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

## Your notes are in the shadow files

Folio keeps your highlights, bookmarks and notes in the shadow files
(`Nfo/*.sdw`) inside the prefix. `install.sh --reinstall` deletes the
prefix, so run `vedabase backup` first. Restore that backup on another Linux
machine with `install.sh --restore FILE`, which skips the installer entirely.

## Where things live

`VEDABASE_HOME` holds Wine, the prefix, the downloads and the helper tools,
about 3 GB. It defaults to `~/.local/share/vedabase`. On journel it defaults
to `/journel/s0/$USER/vedabase`, because home there is a 40 GiB NFS quota.
Override it with `--home`. The launcher is `~/.local/bin/vedabase`. The menu
entries are in `~/.local/share/applications`.

## If the download breaks

The files come from public Drive links owned by Ekanatha dāsa. If they move or
change, `install.sh` stops with "does not match the manifest" rather than
installing something else. To install from a copy you already have, laid out
like the Drive folders (`Install.exe`, `Fonts/`, `Nfo/`, `Spec/`,
`VaniBase/`):

```bash
./install.sh --source /path/to/copy
./install.sh --source journel.eme.psu.edu:/journel/s0/$USER/vedabase/downloads
```

## Other systems

- **Windows 10/11:** in progress. A double-click installer will run the
  original `Install.exe` natively, then apply the shadow-file fix described in
  [docs/how-it-works.md](docs/how-it-works.md). Meanwhile, Ekanatha's README
  works ([docs/sources.md](docs/sources.md)).
- **macOS:** in progress, using a free Wine build instead of CrossOver.

## How it works, and the license

[docs/how-it-works.md](docs/how-it-works.md) covers every step and why it is
there. That includes two fixes Ekanatha's README doesn't mention:

- The shipped shadow file points at `VedaBase_25.nfo`, a name the install
  renames away, so Folio cannot open it until a link restores that name.
- Under Wine, the installer stalls on its intro sound.

It also records what was verified. [docs/sources.md](docs/sources.md)
summarizes Tāraka's messages, Ekanatha's README and the CrossOver report.

`Install.exe` shows the 2003 Bhaktivedanta Archives license, and the installer
accepts it for you. It allows one copy on one computer, used by one person at
a time, plus a personal archival copy, and forbids use "in an on-line system".
Nothing copyrighted is in this repo. Everything is downloaded at install time.

Credits: the files and the original instructions come from Ekanatha dāsa and
Tāraka dāsa. Wine builds: [Kron4ek/Wine-Builds](https://github.com/Kron4ek/Wine-Builds).
