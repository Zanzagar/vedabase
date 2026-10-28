# Windows test kit

`check.ps1` checks a VedaBase install on a Windows PC as far as a script can,
then lists what still needs a person. It is the scripted half of the Windows
checks in [docs/testing.md](../../docs/testing.md). Like the rest of
`tests/`, it is left out of GitHub's "Download ZIP": run it from a clone.

## Running it

1. Install from this clone: double-click `Install-VedaBase-Windows.cmd`.
   Over an existing install it only finishes the setup and keeps the notes.
2. In the account to check, in an ordinary Command Prompt or PowerShell
   window (not "Run as administrator"), in the clone's folder:

       powershell -ExecutionPolicy Bypass -File tests\windows\check.ps1

   Add `-NoVaniBase` if VedaBase was installed with it, and `> check.txt` to
   keep the output. Each letter outside ASCII is also shown by its code (as
   `\u0101`), which no file encoding loses.
3. Leave the PC alone for about a minute while it runs VedaBase Unicode: its
   small window shows after each run and closes by itself. A copy made
   meanwhile would spoil the test.

It prints `PASS`, `FAIL`, `SKIP` and `NOTE` lines, the number of failures,
then the checks that need a person. Exit status: 0 nothing failed, 1 a check
failed, 2 it could not run (the 32-bit PowerShell, or Windows restricting
PowerShell).

## What it checks

Each value comes from `windows/install-vedabase.ps1` or
`windows/vedabase-unicode.ps1`; the script's comments give the line (as of
commit 5b8bf42). When the installer changes, change this too.

| Part | Checks | In the installer |
| --- | --- | --- |
| Files left | `Views.exe`; the master infobase at 649,011,200 bytes and `VedaBase_25.nfo` matching it; both shadow files; `VaniBase_25.nfo` at the manifest's size; `Temp`, `vedabase.ico`; `install.log` and `machine-phase.done`; the last run in the log with no `error:` and no file that "did not arrive intact"; this account's log reaching `Done.`; the installed converter, its table and `vedabase-defaults.reg` the same as this checkout's | `Test-Installed`, `Complete-Install`, `Set-SharedTemp`, `Invoke-MachinePhase`, `Install-UnicodeConverter`, `Register-UserDefaults` |
| Files removed | `C:\Install.exe`, `C:\Fonts`, `C:\Nfo`, `C:\Spec` (a FAIL if the installer made one and it stayed; a NOTE if it was there before); `VedaBase-Setup\VaniBase`, `sdw-restore.pending`; the `.reg` in the program folder; Install.exe's icon on this account's desktop; the space filler | `Remove-Staging`, `Restore-Notes`, `Register-UserDefaults`, `Move-DesktopIcon`, `Add-SpaceFiller` |
| Registry | all 51 fonts of `manifest/fonts.tsv` in `C:\Windows\Fonts` and registered, each value naming a file that is there; no `AppCompatFlags\Layers` entry for `Views.exe` in HKLM or HKCU; `SwapPath` and `Index\TempPath`; the Active Setup entry, its `StubPath` exactly | `Register-Fonts`, `Remove-OldCompatMode`, `Set-SharedTemp`, `Register-UserDefaults` |
| Shortcuts | the shared desktop's VedaBase and VaniBase icons, the Start menu's VaniBase 25, both VedaBase Unicode shortcuts (program, arguments, folder, icon, window style, not "run as administrator"); Ctrl+Alt+U on the Start menu's alone; no other shortcut on a desktop or in a Start menu with Ctrl+Alt+U. Read from the `.lnk` files themselves (Microsoft's MS-SHLLINK format), with Windows' own reading of target and arguments as a second opinion | `New-Shortcut`, `Complete-Install`, `Install-UnicodeConverter`, `Move-DesktopIcon` |
| This account | `HKCU\Software\VedaBase\4`; the contents font `BellCentennial`; whether Active Setup has run here yet (a NOTE); the File menu's first recent file; every account may write in `Temp`, `Nfo` and the shadow files; this account may open the shadow files to write | `Test-FolioSettings`, `Invoke-FinishPhase`, `Set-SharedTemp` |
| VedaBase Unicode | run with its Start-menu shortcut's command on known text: Bg 2.13's first line; a second run (refused, status 4); `dehino` (nothing to convert, 3); `yajïa`, then a second run that must not make `yajṣa` of it; two runs at once (statuses 0 and 4); all 31 letters with Windows-1252 punctuation and line ends; an ANSI-only copy, as a program from 2003 makes (when the ANSI code page is 1252); `Kṛṣṇa`, already Unicode (4) | `vedabase-unicode.ps1`, `tests/unicode.sh` |

## What it changes

Nothing but the clipboard:

- It saves the clipboard's text first and puts it back at the end: the text
  only, not its formatting. When the clipboard holds no text but something
  else (a picture, files), it skips VedaBase Unicode, unless `-ReplaceClipboard`
  is given; then the clipboard ends empty. `-SkipConverter` leaves the
  clipboard alone.
- It puts back what VedaBase Unicode remembers of its last conversion
  (`%LOCALAPPDATA%\VedaBase\unicode-last.txt`): its bytes and time, or its
  absence.
- With clipboard history (Win+V) on, the test texts stay in it.
- It opens the two shadow files to write, writing nothing, to see whether
  this account may. It never prints the clipboard's text.

## What it cannot check

What it lists at the end: checks 2–7 inside VedaBase and VaniBase; Ctrl+Alt+U
pressed with VedaBase in front and with another program, and whether the key
works before signing out and in; a console flash; the focus afterwards; how
the small window draws ā and ṣ; a second account; a standard user; an
accepted restart; an uninstall and reinstall; the prompts and messages to
write down. It runs the converter with its shortcut's command, not through the
key: the key is Windows' part.

## How far it has been tested

Not yet on Windows. On Linux, on 2026-10-27, under PowerShell 7.6: it parses,
is plain ASCII, uses no syntax PowerShell 7 added and only cmdlets Windows
PowerShell 5.1 has, and reads no variable it does not define. Its shortcut
reader reads the `.lnk` files Install.exe wrote under Wine (which count a
closing NUL in each string, where MS-SHLLINK does not), and files laid out as
that specification has them. Whole runs against a stand-in install pass on a
good install and fail on broken ones: fonts, leftovers, keys, registry values,
another version, a converter that converts twice or runs without its lock, or
whose window never closes. In the stand-in, the C: drive is a scratch folder,
the registry, clipboard, access lists and the converter's process are faked,
and the conversions are made by the installed `vedabase-unicode.ps1 -InFile`.
The harness that ran these is not in this repository. The first run on Windows
is the real test.

Windows PowerShell 5.1 runs it, not 7. Keep it plain ASCII, writing other
letters as `\uXXXX` through its `U` function, and use nothing PowerShell 7
added.
