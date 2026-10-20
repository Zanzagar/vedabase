# Testing a new install

The Linux installer was tested end to end on an Ubuntu 24.04 server
(2026-10-19). The Windows and macOS installers have not yet run on those
systems: they were checked only for syntax (PowerShell 7 parser,
ShellCheck) and on Linux where possible. Before showing them to anyone, run
each once on a real machine and go through this list.

## Every system

1. The installer finishes without an error. Each file is reported as
   downloaded once, then verified.
2. **VedaBase 25 opens** at its title page ("VedaBase™ 25, The Complete
   Teachings"). If it shows *"Unable to open the infobase … 'VedaBase_25.nfo'
   could not be found"*, the link fix did not run. Re-run the installer.
3. **Diacritics:** expand *02 Bhagavad-gītā As It Is → Bg 2 → Bg 2.13*. The
   verse shows Devanagari and *dehino 'smin yathā dehe*. Plain letters with
   boxes or wrong accents mean the fonts are missing.
4. **Search:** type `dehino` in the toolbar's search box and press Enter. The
   status bar shows `Hit: 1 / …`, and the hits are highlighted.
5. **VaniBase 25** opens from its own icon. Its status bar reads
   `Record: 1 / 518,550`.
6. **Close Folio** with File → Exit. Note whether it closes promptly: a hang on
   exit is the known Folio problem on Windows 10/11.
7. Make a highlight or a note, close, reopen, and check it is still there.
   That proves the shadow file is writable.

## Windows only

- Registry checks after the install (run `regedit`, or `reg query` in a
  terminal):
  - `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts` has entries
    such as `Sanskrit Times (TrueType)` and `Balaram (TrueType)`.
  - `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers`
    has the value `C:\Bhaktivedanta VedaBase 2003\Views.exe`, set to
    `~ WINXPSP2`. Any other programs' entries in that key are still there.
  - `HKCU\Software\VedaBase\4` exists for the user who will read VedaBase.
- If possible, also install as a standard user, typing an administrator's
  password when Windows asks. Then check that the contents pane still shows
  correct diacritics: the finish phase should restore the settings.

- Record which prompts appeared (UAC, SmartScreen, "Open File – Security
  Warning"), so the README can describe them exactly.
- After the install, `C:\Install.exe`, `C:\Fonts`, `C:\Nfo` and `C:\Spec` are
  gone, unless they existed before.
- Accept the installer's restart prompt once, on purpose, then run the `.cmd`
  again. It should finish cleanly.
- Try once with and once without `-NoCompatMode`, and note any difference in
  closing.

## macOS only

- Open and close VedaBase about 20 times on an Apple Silicon Mac. Open WineHQ
  bug 60494 makes some 32-bit programs crash or hang at random under Rosetta.

- Record what Gatekeeper showed for the `.command` and which way past it
  worked.
- On Apple Silicon, note whether Rosetta was installed and asked for a
  password.
- After the install, `~/Applications/VedaBase 25.app` opens VedaBase directly
  and shows an icon. The icon is optional; it comes from `sips`.
