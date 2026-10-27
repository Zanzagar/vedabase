# The Windows installer on a real PC (October 2026)

On 20 October 2026 the Windows installer was tried for the first time on a
real Windows PC. Here is what worked, what you will see while installing, what
went wrong and how it was fixed, and what has not been tested yet.

## The PC

Windows 11 Home, version 25H2 (build 26200.9711), 64-bit, in US English. The
account was an administrator, so Windows asked only for a click on **Yes**,
not for a password. Smart App Control was off, the PC was not in S mode, and
Microsoft Defender was on. (*Settings → System → About* shows the edition,
version and build of your own PC.) The ZIP was downloaded from GitHub,
unblocked and unzipped, and the administrator prompts and the original
VedaBase installer (from 2003) were clicked by hand.

The first run stopped early (problem 1 below). The second installed everything
with *Complete*, which the original installer selects unless you change it,
so it also installed WinAmp. The third, after uninstalling, chose *Custom*, as
the README says. Each fix below was then tried on the same PC, except where it
says otherwise.

## What works

The checks from the testing checklist ([testing.md](testing.md)), made after
the second run:

- **Download:** about 1.1 GB in about 6 minutes on that connection (a slower
  connection takes longer). Every file arrived intact, and the installer
  finished with no error or warning.
- **VedaBase 25** opens at its title page, with no *"master infobase … could
  not be found"* message.
- **Diacritics:** Bg 2.13 shows the Devanagari and *dehino 'smin yathā dehe*,
  and the contents list reads *Śrīmad-Bhāgavatam*.
- **Search:** `dehino` gives `Hit: 1 / 50`, with the hits highlighted.
- **VaniBase 25** opens from its own icon at `Record: 1 / 518,550`.
- **Closing:** after you add a note, File → Exit first asks *"Do you want to
  save changes to Bhaktivedanta VedaBase 2025?"* Click **Yes** to keep it.
  VedaBase then closed within a few seconds, with no freeze.
- **Notes:** a note was still there after closing VedaBase (answering **Yes**
  to that question) and opening it again, and after running the installer a
  second time, which found everything in place and changed nothing.
- **Behind the scenes:** the installer cleared its setup files from `C:\`,
  registered all 51 fonts and put Folio's display settings in place. Its
  record of what it did, `install.log`, is in `C:\Program Files\VedaBase-Setup`
  (send it with any report, as *If something goes wrong* in the README says).
  The third run, with *Custom*, passed the same file and settings checks; the
  blank pages it then showed are problem 3 below, now fixed.

Most of these checks inside VedaBase were made while it still ran with
administrator rights, because of problem 2 below. After that fix, VedaBase and
VaniBase opened from their desktop icons without Windows asking for
permission, showed their text with diacritics, and closed promptly.

## What you will see while installing

These are the surprises to expect. The full steps are in the
[README's Windows steps](../README.md#windows-10-or-11).

- **One administrator prompt.** The installer's window says that Windows will
  now ask for administrator rights. Windows then asks whether to allow an app
  to make changes to your device. That app is *Windows PowerShell*, the part
  of Windows that runs this installer, so the prompt may not mention
  VedaBase. Click **Yes**. A second window opens, starting with the line
  *VedaBase setup (administrator)*, and downloads the files. If you click
  **No**, or do not answer within about two minutes, the installer stops with
  *"Administrator permission was not given, so nothing was installed."* Press
  Enter, then run the installer again and click **Yes**.
- **A media player** may open first to play a short welcome sound, or Windows
  may ask which app to use for it. Close that window without choosing an app:
  the VedaBase installer is waiting behind it. On the test PC the player
  covered almost the whole screen, so the installer looked stuck.
- **The first page** advises uninstalling older versions of VedaBase first. On
  a PC that never had VedaBase, click **Next**. An older VedaBase on the same
  PC was not part of this test; if you have one, copy its notes somewhere safe
  before uninstalling it, as that page also advises.
- **User Information:** the *Name* box may already show a name or an email
  address that Windows has on record. Type your own name there instead.
- **Select Install Type** starts on *Complete*, which also installs WinAmp 3,
  a 2002 media player with its own setup and pop-up windows. Choose **Custom**
  (not *Minimum*, which expects a CD). On the next page, *Select Packages*,
  all three boxes start empty: tick **All Folio Program Files** and
  **VedaBase Master Files**, and leave **WinAmp media player** unticked.
  Ignore the note there that these files "can remain on the CD": there is no
  CD, and VedaBase needs them. The *WinAmp Install* page later on is just
  text: click **Next**. If you already went on with *Complete*, VedaBase still
  installs and works, as it did on the test PC. You can remove WinAmp
  afterwards in *Settings → Apps*; Windows may then ask which app to use for
  some sound files.
- **The last page** says *"The fonts will need to be initialized"* and
  mentions registering your copy. Click **Finish**. On the test PC no Fonts
  window and no registration window opened. If one opens on yours, close it:
  the installer registers the fonts itself.
- **Two restart messages.** The first says *"In order to complete the
  installation, your system must be restarted. Click OK to continue or Cancel
  if you wish to reboot later."* Click **Cancel**: it only puts off the
  restart and undoes nothing. The second says *"We recomend that you restart
  your system before running the Vedabase."* (the installer's own spelling).
  Click **OK**. No restart is needed. If you clicked **OK** at the first
  message and the PC restarted, run `Install-VedaBase-Windows.cmd` again
  afterwards and it will finish the setup (not yet tried; see *Not tested
  yet*).
- **At the end** the second window closes by itself. The first window (the
  one that opened when you double-clicked the installer; it may be behind
  other windows) says *Done.* and asks *"Open VedaBase now? [Y/n]"*. Press
  Enter to open VedaBase, or type **N** and press Enter to finish without
  opening it.

## Problems found, and how each was fixed

1. **It stopped before downloading anything**, with *"The path is not of a
   legal form."* Windows PowerShell, the part of Windows that runs this
   installer, refused to prepare the `C:\` drive for the download. Fixed; the
   second run went through.
2. **VedaBase asked for administrator rights every time it started.** The
   installer turned on Windows XP compatibility mode for VedaBase, a setting
   devotees used on Windows 7 to stop VedaBase freezing when it closes. On
   Windows 11 that setting makes Windows ask for administrator rights at every
   start. On the test PC, VedaBase closed normally without it. Fixed: the
   installer no longer turns the mode on, and if an earlier copy turned it on,
   running the new copy turns it off again at once, with no restart. If
   Windows cannot apply that change at once, the installer now says *"If
   VedaBase still asks for administrator rights when it starts, restart
   Windows once."* Do that. (This message has not yet been seen on a real PC.)
3. **Blank pages after uninstalling and reinstalling** without signing out of
   Windows. The original uninstaller deletes VedaBase's fonts while Windows
   still has them loaded, and the reinstall did not load them again. Fixed:
   the installer now reloads all 51 fonts every time it runs. That reload ran
   on the test PC, but a full uninstall and reinstall has not been repeated
   with it yet. Signing out of Windows and back in should clear the blank
   pages too.
4. **An error from the File menu's list of recent files.** Clicking an entry
   for a file that does not exist showed *"Unable to open the infobase.
   'Bhaktivedanta Vedabase 4 Sh' could not be opened."* The original installer
   adds that entry. The message is harmless: close it and open VedaBase from
   its desktop icon. Fixed: the installer now points that entry at VedaBase
   itself. After the third run, which used the fix, the list named only the
   real VedaBase file (clicking it was not tried again).

The README's installer steps were also corrected to match the pages the
original installer shows, and the third run followed them.

All of these fixes were made on 20 October 2026. To check your copy: if the
`docs` folder inside your unzipped folder has a file whose name starts with
`windows-test-2026-10` (this page), your copy has every fix described on this
page. If it does not, get a new copy as in *Getting the files* in the
[README](../README.md), or ask whoever gave you the installer for one. Running
the new copy over a VedaBase that an earlier copy installed is safe and keeps
your notes: it sees that VedaBase is already there, skips the original
installer and only finishes the setup.

## Not tested yet

None of these is known to fail; they simply have not been tried yet.

- **VedaBase Unicode** (Ctrl+Alt+U), which the installer gained after this
  test: it has not run on any Windows PC yet. Check 8 of
  [testing.md](testing.md) says what to try.

- Uninstalling VedaBase and installing it again with *Custom*, without
  signing out of Windows in between, using the newest installer. **Before you
  try this, copy your notes out of `C:\Bhaktivedanta VedaBase 2003\Nfo`** (the
  files *Bhaktivedanta Vedabase 2003* and *VaniBase_25*, ending in `.sdw`):
  uninstalling deletes the VedaBase one. See
  [Removing VedaBase](../README.md#removing-vedabase) in the README. (On the
  test PC the installer's new font step ran without trouble, and doing the
  same by hand brought back the missing text. If you see blank pages
  afterwards, sign out of Windows and back in.)
- Saving a note now that VedaBase runs without administrator rights (the note
  test above ran before the fix in problem 2). To try it, add a note, close
  VedaBase and click **Yes** to save, open it again and check the note is
  there.
- Opening VedaBase from a second Windows account on the same PC, and
  installing from a *standard* account (one that is not an administrator),
  where Windows asks for an administrator's password instead of just **Yes**.
- Clicking **OK** at the first restart message (the one that also offers
  Cancel), letting the PC restart, then running the installer again.
- Opening VedaBase from the File menu's list of recent files since the fix in
  problem 4.
- The *"Windows protected your PC"* and *"Open File – Security Warning"*
  messages, which did not appear because the ZIP was unblocked first.
- Other PCs: Windows 10, PCs with an Arm processor (*Settings → System →
  About* shows this under *System type*), and Windows in other languages.

If you try any of these, please tell whoever gave you the installer how it
went; [testing.md](testing.md) lists what to look at.

To install, follow the [README's Windows steps](../README.md#windows-10-or-11).
