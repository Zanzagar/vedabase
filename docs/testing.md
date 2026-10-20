# Testing a new install

The Linux installer was tested end to end on an Ubuntu 24.04 server in October
2026. The macOS installer ran to completion under a real bash 3.2 on Linux,
with the Mac-only commands stubbed. The Windows installer has only been parsed
and partly exercised with PowerShell on Linux.

Neither the Windows nor the macOS installer has run on its own system yet. Do
that once with this list before relying on either.

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
7. Make a highlight or a note, close, reopen, and check it is still there.
   That proves the shadow file is writable.

## Windows only

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
    has `C:\Bhaktivedanta VedaBase 2003\Views.exe` = `~ WINXPSP2`. Other
    programs' entries in that key are still there.
  - `HKLM\SOFTWARE\WOW6432Node\VedaBase\4\Server\SwapPath` points to
    `C:\Bhaktivedanta VedaBase 2003\Temp`.
  - `HKLM\SOFTWARE\Microsoft\Active Setup\Installed Components\{8C9EE47A-5102-4B2C-B476-0212DFBB3EC0}`
    exists.
  - `HKCU\Software\VedaBase\4` exists.
- Sign in as a **second account** on the same PC and repeat checks 2–4 above.
  Active Setup should have given that account the settings.
- If possible, install as a standard user, typing an administrator's password
  when Windows asks, then repeat check 3.
- Accept the installer's restart prompt once, on purpose, then run the `.cmd`
  again. It should finish cleanly.
- To compare without compatibility mode, first remove the setting by running
  this in an administrator Command Prompt:

  ```
  reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "C:\Bhaktivedanta VedaBase 2003\Views.exe" /reg:64 /f
  ```

  Then run `Install-VedaBase-Windows.cmd -NoCompatMode` and repeat check 6.

## macOS only

- Record what Gatekeeper showed for the `.command`, and which way past it
  worked.
- On Apple Silicon, note whether Rosetta was installed and asked for a
  password.
- After the install, `~/Applications/VedaBase 25.app` opens VedaBase directly
  and shows an icon. The icon is optional; it comes from `sips`.
- Nothing new appeared on the Desktop.
- On an Apple Silicon Mac, open and close VedaBase about 20 times. Open WineHQ
  bug 60494 makes some 32-bit programs crash or hang at random under Rosetta.
