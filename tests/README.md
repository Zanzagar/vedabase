# Tests

For whoever changes the installers. These are not needed to install VedaBase,
and GitHub's "Download ZIP" leaves this folder out.

Every test installs into scratch folders under `VB_TEST_WORK`, with `HOME`
pointed there too, so your own install, the `vedabase` launcher and
`~/.config/vedabase` are never touched. Each prints `PASS`/`FAIL` lines and
exits non-zero if a check failed.

| Script | What it proves | Time |
| --- | --- | --- |
| `linux-e2e.sh` | a clean unattended Linux install; `doctor`; private permissions; the browser viewer (it connects, six wrong passwords do not lock you out, typing reaches Folio); `stop`; a backup restored with `--reinstall --restore` | ~5 min |
| `interrupt.sh` | Ctrl-C and a closed terminal in the middle of the wizard leave nothing running; after SIGKILL the re-run cleans up; every re-run finishes the install | ~8 min |
| `rollback.sh` | the exit trap's rollback of a restore: install.sh's own functions against fake prefixes (rejected restore, interrupted swap, impossible rename); no install needed | seconds |
| `mac-sim.sh` | `mac/install.sh` under a real bash 3.2 with the macOS commands shimmed and Linux Wine standing in, the wizard clicked by a script that never closes the Fonts window | ~2 min |

Settings, as environment variables:

- `VB_TEST_WORK` (required): a scratch folder with about 4 GB free per install.
- `VB_TEST_SOURCE`: a copy of the VedaBase files laid out like the Drive
  folders. Without it the tests download from Google Drive, which limits
  repeated downloads.
- `VB_TEST_PORT`: the browser viewer's port in `linux-e2e.sh` (default 6091).
- `CHROME_EXE`: a Chromium for Playwright (Python package `playwright`); the
  browser checks are skipped without it.
- `VB_TEST_BASH32` (`mac-sim.sh`): a bash 3.2 binary, the version macOS ships.
  Build it from GNU's `bash-3.2.57.tar.gz` with `./configure && make`; if the
  build wants `yacc`, `touch y.tab.c y.tab.h` first, since the tarball ships
  the generated parser.
- `VB_TEST_TOOLS`, `VB_TEST_WINE` (`mac-sim.sh`): Xvnc, xdotool and xauth,
  and a Linux Wine. They default to the ones inside your own VedaBase install.

Before every commit, also run ShellCheck (`shellcheck -x`; SC2034 aside,
since library variables look unused on their own), `bash -n` with bash 3.2
on the files macOS uses, and a PowerShell parse of
`windows/install-vedabase.ps1`. Nothing here runs the Windows installer: only
a real Windows PC can (`docs/testing.md`).
