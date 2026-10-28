# Testing a new install

The Linux installer was tested end to end on an Ubuntu 24.04 server in October
2026. The macOS installer ran to completion under a real bash 3.2 on Linux,
with stand-ins for the commands that exist only on a Mac. The Windows
installer was tested on one Windows 11 PC in October 2026. Its report,
[windows-test-2026-10.md](windows-test-2026-10.md), says what passed there and
which of the Windows checks below have not been run yet.

The macOS installer has not run on a Mac yet; before relying on it, someone
should run it once on a real Mac and go through this list. On Windows, the
checks most worth trying next are the ones not yet run: a second account, a
standard (non-administrator) account, accepting the restart, saving a note now
that VedaBase runs without administrator rights, and uninstalling and
reinstalling without signing out of Windows.

## Every system

1. The installer finishes without an error. No file shows a "did not arrive
   intact" warning.
2. **VedaBase 25 opens** at its title page ("VedaBase™ 25, The Complete
   Teachings"). If it shows *"Unable to open the infobase … 'VedaBase_25.nfo'
   could not be found"*, the link step did not run. Run the installer again.
3. **Diacritics:** expand *02 Bhagavad-gītā As It Is → Bg 2 → Bg 2.13*. The
   verse shows Devanagari and *dehino 'smin yathā dehe*, and the contents tree
   on the left reads *Śrīmad-Bhāgavatam*. *Çrémad-Bhägavatam* there means
   Folio's settings are missing. Plain letters with boxes mean the fonts are
   missing.
4. **Search:** type `dehino` in the toolbar's search box and press Enter. The
   status bar shows `Hit: 1 / …`, and the hits are highlighted.
5. **VaniBase 25** opens from its own icon. Its status bar reads
   `Record: 1 / 518,550`.
6. **Close Folio** with File → Exit. Note whether it closes promptly: a hang on
   exit is the known Folio problem on Windows 10/11.
7. Make a highlight or a note, close VedaBase (answer **Yes** when it asks
   whether to save changes), reopen it, and check it is still there. That
   proves the shadow file is writable.
8. **VedaBase Unicode:** at Bg 2.13, select the verse's first line and copy it
   (Ctrl+C; on a Mac, ⌘C). Paste it into a text editor once before converting:
   it must arrive, still reading *yathä*. That shows the copy leaves VedaBase
   at all, which on Linux and the Mac is Wine's doing. Convert it as
   [Copying text out](../README.md#copying-text-out) says, then paste it into
   a text editor: it must read *dehino 'smin yathā dehe*, not *yathä*. Convert
   again without copying: it must say *this is the text it has just converted*
   and change nothing. Copy a word with no diacritics, such as *dehino*, and
   convert: it must say *Nothing to convert*.

## Windows only

On the PC itself, `tests\windows\check.ps1` (in a clone of the repository)
checks much of what follows by itself and lists what needs a person; see
`tests/windows/README.md`. It has not yet run on Windows.

- Record which prompts appeared (UAC, SmartScreen, "Open File – Security
  Warning"), so the README can describe them exactly.
- After the install:
  - `C:\Install.exe`, `C:\Fonts`, `C:\Nfo` and `C:\Spec` are gone, unless they
    existed before.
  - `C:\Program Files\VedaBase-Setup\install.log` exists.
- Registry, checked with `regedit`:
  - `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts` has entries
    such as `Sanskrit Times (TrueType)` and `Balaram (TrueType)`.
  - `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers`
    has no entry for `C:\Bhaktivedanta VedaBase 2003\Views.exe` (no
    compatibility mode), and VedaBase opens from its icon without a UAC
    prompt.
  - `HKLM\SOFTWARE\WOW6432Node\VedaBase\4\Server\SwapPath` points to
    `C:\Bhaktivedanta VedaBase 2003\Temp`.
  - `HKLM\SOFTWARE\Microsoft\Active Setup\Installed Components\{8C9EE47A-5102-4B2C-B476-0212DFBB3EC0}`
    exists, and its `StubPath` names
    `C:\Program Files\VedaBase-Setup\vedabase-defaults.reg`, which exists.
  - `HKCU\Software\VedaBase\4` exists.
- Sign in as a **second account** on the same PC and repeat checks 2–4 above.
  Active Setup should have given that account the settings.
- If possible, install as a standard user, typing an administrator's password
  when Windows asks. Then, as that standard user, repeat check 3, and:
  - `reg query "HKLM\SOFTWARE\VedaBase\4\Server\Index\TempPath" /reg:32`
    shows `C:\Bhaktivedanta VedaBase 2003\Temp`, not a folder in anyone's
    profile.
  - Paste a few pages of text into a note, press Ctrl+S, search, then close
    VedaBase and save. None of these may stick on "Saving Document..." or
    "Updating Index...".
- Accept the installer's restart prompt once, on purpose, then run the `.cmd`
  again. It should finish cleanly.
- Copy your notes (the `.sdw` files in `C:\Bhaktivedanta VedaBase 2003\Nfo`)
  somewhere safe first: uninstalling deletes the VedaBase one. Then uninstall
  VedaBase (*Settings → Apps*), delete its folder, and install it again
  without signing out of Windows. VedaBase must still show text (an earlier
  version left its pages blank until the next sign-in).
- Note whether a media player, or Windows asking which app to use, opened at
  the start (the installer plays `C:\Spec\INTRO.WAV`), and record the restart
  messages word for word.
- **VedaBase Unicode** (check 8): try **Ctrl+Alt+U** both with VedaBase in
  front and with another program in front, and note whether the keys worked
  at once or only after signing out and back in. Note whether a console
  window flashes, whether the small window's text shows ā and ṣ (not
  "Ä" and other odd letters), and which program has the focus after it
  closes. Press Ctrl+Alt+U twice quickly after copying *yajña* out of a
  verse: the result must read *yajña*, never *yajṣa*. Try the desktop icon
  too, and both again in a second account.
  `C:\Program Files\VedaBase-Setup` holds `vedabase-unicode.ps1` and
  `balaram-unicode.tsv`.

## macOS only

- Record what Gatekeeper showed for the `.command`, and which way past it
  worked.
- On Apple Silicon, note whether Rosetta was installed and asked for a
  password.
- After the install, `~/Applications/VedaBase 25.app` opens VedaBase directly
  and shows an icon. The icon is optional; it comes from `sips`.
- **VedaBase Unicode** (check 8): note whether its dialog appears in front, and
  whether macOS asked for any permission the first time. Click it twice
  quickly after copying *yajña*: the result must read *yajña*, not *yajṣa*
  (the Mac version has no lock and counts on macOS running one copy of an app).
- Nothing new appeared on the Desktop.
- On an Apple Silicon Mac, open and close VedaBase about 20 times. Open WineHQ
  bug 60494 makes some 32-bit programs crash or hang at random under Rosetta.
