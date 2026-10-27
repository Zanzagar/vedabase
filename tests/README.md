# Tests

For whoever changes the installers. These are not needed to install VedaBase,
and GitHub's "Download ZIP" leaves this folder out.

Every test installs into scratch folders under `VB_TEST_WORK`, with `HOME`
pointed there too, so your own install, the `vedabase` launcher and
`~/.config/vedabase` are never touched. Each prints `PASS`/`FAIL` lines and
exits non-zero if a check failed.

| Script | What it proves | Time (journel, with `VB_TEST_SOURCE`) |
| --- | --- | --- |
| `unicode.sh` | the Unicode converter on worked examples, under bash, bash 3.2 and PowerShell 7 (line ends, refusals); the shell and PowerShell versions agreeing byte for byte; the clipboard round trip on a private X display, also from an owner that, like Wine 11.0, sends its claim only when woken (`x11/lazy-owner.py`); no install needed | ~1 min |
| `nudge.sh` | the browser viewer's nudger (`lib/x11-nudge.py`) on a private X display: one per X server (a second leaves, one that loses its selection leaves), a request whose requestor vanishes does not end it, a new server under an old one's number gets a nudger of its own while the old one is held up, a nudger ends with its display; no install needed | ~15 s |
| `linux-e2e.sh` | a clean unattended Linux install; `doctor`; private permissions; `vedabase unicode` and its menu entry; the browser viewer (a word copied in Folio reaches its clipboard by itself and converts; it connects, six wrong passwords do not lock you out, typing reaches Folio, converted text reaches noVNC's clipboard panel whole, a word copied through the browser shows there); `stop`, which ends the viewer's nudger too and reports a display that outlives it; a nudger that fails reported, and none held up by an old display's; a backup restored with `--reinstall --restore`; damaged backups refused without touching the prefix | ~5 min |
| `interrupt.sh` | Ctrl-C and a closed terminal in the middle of the wizard leave nothing running; after SIGKILL the re-run cleans up; every re-run finishes the install | ~6 min |
| `rollback.sh` | the exit trap's rollback of a restore: install.sh's own functions against fake prefixes (rejected restore, interrupted swap, impossible rename); no install needed | seconds |
| `mac-sim.sh` | `mac/install.sh` under a real bash 3.2 with the macOS commands shimmed and Linux Wine standing in, the wizard clicked by a script that never closes the Fonts window; the *VedaBase Unicode* app converting the (shimmed) pasteboard | ~1.5 min |

Settings, as environment variables:

- `VB_TEST_WORK` (required): a scratch folder with about 4 GB free per install.
- `VB_TEST_SOURCE`: a copy of the VedaBase files laid out like the Drive
  folders. Without it the tests download from Google Drive, which limits
  repeated downloads.
- `VB_TEST_PORT`: the browser viewer's port in `linux-e2e.sh` (default 6091).
- `CHROME_EXE`: a Chromium for Playwright (Python package `playwright`); the
  browser checks are skipped without it.
- `VB_TEST_PWSH` (`unicode.sh`): PowerShell 7 (`pwsh`), for the Windows
  converter; without it, and with no `pwsh` on PATH, those checks are skipped.
- `VB_TEST_BASH32` (`mac-sim.sh`, `unicode.sh`): a bash 3.2 binary, the version macOS ships.
  Build it from GNU's `bash-3.2.57.tar.gz` with `./configure && make`; if the
  build wants `yacc`, `touch y.tab.c y.tab.h` first, since the tarball ships
  the generated parser.
- `VB_TEST_TOOLS`, `VB_TEST_WINE` (`mac-sim.sh`): Xvnc, xdotool and xauth,
  and a Linux Wine. They default to the ones inside your own VedaBase install.

Before every commit, also run ShellCheck (`shellcheck -x`; SC2034 aside,
since library variables look unused on their own), `bash -n` with bash 3.2
on the files macOS uses (`bin/vedabase-unicode` among them), and a
PowerShell parse of `windows/install-vedabase.ps1` and
`windows/vedabase-unicode.ps1`. Nothing here runs the Windows installer: only
a real Windows PC can (`docs/testing.md`).
