# Trying the Mac installer

So far (October 2026) the macOS installer has not run on a real Mac. It has
been checked only on Linux, under the bash that macOS ships, with stand-ins
for the commands that exist only on a Mac ([testing.md](testing.md)). This
page is for whoever tries it first on a real Mac: how to install, what to
check, and what to send back. Wherever your Mac does something this page does
not describe, that is exactly what is worth reporting.

**What you need:** a Mac with macOS 10.15.4 or later (Intel or Apple
Silicon), about 4 GB of free space, and an internet connection; CrossOver is
not needed. The installer downloads a free Wine for macOS (185 MB), which lets
a Mac run Windows programs such as VedaBase, and the VedaBase files (about
1.1 GB). On a Mac with an Apple chip it may also install Apple's Rosetta 2,
which this Wine needs there; that takes an administrator account and its
password.

**Screenshots.** Take one of every message macOS shows you, and of anything
that goes wrong or differs from this page. Shift-Command-3 takes the whole
screen and Shift-Command-4 a part you drag over; macOS normally saves them on
the Desktop. Start with **Apple menu → About This Mac**, which shows your
Mac's chip and macOS version.

## 1. Get the files

On <https://github.com/Zanzagar/vedabase>, choose **Code → Download ZIP**, or
use the ZIP you were given. Unzip it by double-clicking it in the Finder
(Safari may already have unzipped it, into a folder such as `vedabase-main`).
Keep the unzipped folder whole: the installer reads the `manifest` and `lib`
folders next to it.

## 2. Start the installer

1. In the unzipped folder, double-click **`Install-VedaBase-Mac.command`**.
   A Terminal window should open, with the installer running in it. If it
   opens without any warning from macOS, note that too.
2. **If macOS will not open it,** take a screenshot of its message. Then try
   the README's ways past it
   ([If macOS will not open the installer](../README.md#if-macos-will-not-open-the-installer))
   in this order, and note which one worked (the first shows what most people
   will meet; the second is the README's way that always works):
   - On macOS 15 or later, click **Done** on the warning, then go to
     **System Settings → Privacy & Security** and click **Open Anyway** next
     to the file. On macOS 14 or earlier, Control-click the file and choose
     **Open**.
   - If that does not work either, open **Terminal** (Applications →
     Utilities), type `bash ` (with a space after it), drag
     `Install-VedaBase-Mac.command` from the Finder into the Terminal window,
     and press Return.
3. If macOS asks whether Terminal may access a folder (such as Downloads),
   click **OK**. If you clicked *Don't Allow*, turn Terminal on under
   *System Settings → Privacy & Security → Files and Folders* (on macOS 12
   or earlier: *System Preferences → Security & Privacy → Privacy → Files and
   Folders*), then start again.
4. **Rosetta 2.** On a Mac with an Apple chip, the installer first installs
   Rosetta 2 if it is missing. The Terminal then says *Installing Rosetta 2
   (macOS asks for your password)*: type your Mac password and press Return
   (the letters may not show as you type). If it says instead that only an
   administrator can install Rosetta 2, do as it says, or stop there and
   report it.
5. It then downloads Wine and the VedaBase files. Keep the lid open until it
   is done: the installer stops the Mac from going to sleep, but closing the
   lid still sends it to sleep.

## 3. Click through the original installer

The original VedaBase installer, from 2003, should then open in a window of
its own, while the Terminal lists these steps:

1. **Next**, then **Accept** the license, then type your name (replace
   anything already there), then **Next**.
2. **Next** again (ignore its list of old Windows versions).
3. *Select Install Type*: choose **Custom**, then **Next**.
4. Tick **All Folio Program Files** and **VedaBase Master Files** (leave
   **WinAmp media player** unticked), then **Next**.
5. **Next**, **Next**, **Install**, then **Next**, **Next** and **Finish**.
6. Answer the restart questions (either answer is fine).

The license is the 2003 Bhaktivedanta Archives license
([License](../README.md#license) in the README). After step 6 the Terminal
should close the Fonts window the installer opens, and carry on by itself. If
it says instead *When the installer has finished, close its remaining
windows*, close them yourself (the Fonts window may be behind the Terminal),
and note that it asked.

It should then add VaniBase 25, put three apps in the `Applications` folder
inside your home folder, say *Done.*, open VedaBase 25, and end with
*Press Enter to close this window*. **Before you press Return there, save the
Terminal's text:** click in the Terminal window, choose **Edit → Select All**,
then **Edit → Copy**. Paste it into a new TextEdit document and save that (or
paste it straight into an email). Then press Return.

If the installer stops with an error, save the Terminal's text the same way,
then run the installer again: it continues where it stopped.

## 4. The checks

These are the checks of [testing.md](testing.md), as they apply on a Mac.
Give their numbers in your report.

1. The installer finished without an error, and no file showed a *did not
   arrive intact* warning.
2. **VedaBase 25 opens** at its title page (*VedaBase™ 25, The Complete
   Teachings*). If it says instead that *'VedaBase_25.nfo' could not be
   found*, run the installer again.
3. **Diacritics:** expand *02 Bhagavad-gītā As It Is → Bg 2 → Bg 2.13*. The
   verse shows Devanagari and *dehino 'smin yathā dehe*, and the contents tree
   on the left reads *Śrīmad-Bhāgavatam*. Take a screenshot if it reads
   *Çrémad-Bhägavatam* instead, or if you see plain letters with boxes.
4. **Search:** type `dehino` in the toolbar's search box and press Return.
   The status bar shows `Hit: 1 / …`, and the hits are highlighted.
5. **VaniBase 25** opens from its own app. Its status bar reads
   `Record: 1 / 518,550`.
6. **Close VedaBase** with *File → Exit*, and note whether it closes promptly.
7. Make a highlight or a note, close VedaBase (answer **Yes** when it asks
   whether to save changes), open it again, and check it is still there.
8. **VedaBase Unicode:** at Bg 2.13, select the verse's first line and copy it
   with ⌘C (if ⌘C does nothing, try Control-C, and note which worked). Paste
   it into TextEdit once: it must arrive, still reading *yathä*. Then open
   **VedaBase Unicode** from the `Applications` folder in your home folder,
   and paste again: it must read *dehino 'smin yathā dehe*. Open VedaBase
   Unicode again without copying: it must say *this is the text it has just
   converted* and change nothing. Copy a word with no diacritics, such as
   *dehino*, and open VedaBase Unicode: it must say *Nothing to convert*.

On a Mac only:

- **The apps:** in the Finder, choose **Go → Home** and open `Applications`.
  *VedaBase 25* there opens VedaBase directly. Note whether the apps show the
  VedaBase icon (a nice extra, not a must).
- **VedaBase Unicode:** note whether its small window appears in front of the
  others, and whether macOS asked for any permission the first time. Then copy
  just the word *yajña* in VedaBase, open VedaBase Unicode twice in quick
  succession (from the Dock: two quick clicks), and paste: it must read
  *yajña*, not *yajṣa*.
- **The Desktop:** apart from what you put there yourself, such as
  screenshots, nothing new appeared on it.
- **With an Apple chip:** open and close VedaBase about 20 times, and note any
  time it crashes or hangs. An open Wine bug, WineHQ 60494, makes some 32-bit
  Windows programs do that at random under Rosetta; whether it affects
  VedaBase is not known yet.

## 5. What to send back

To whoever gave you this installer:

- **Your Mac:** the screenshot of *About This Mac*.
- **The checks:** for each one, *OK* or what happened instead, with
  screenshots of anything that went wrong or looked odd.
- **macOS's messages:** what it showed when you opened the installer, and
  which way past it worked; whether the installer installed Rosetta 2 and
  asked for your password; any other permission macOS asked for.
- **The Terminal text** you saved.
- **The logs folder:** in the Finder, choose **Go → Go to Folder…**, paste
  `~/Library/Application Support/VedaBase` and press Return. Control-click the
  `logs` folder, choose **Compress "logs"**, and send the `logs.zip` that
  appears beside it (you can drag it into an email).

A run that went wrong is as useful as one that went well, as long as these
come with it. Afterwards you can keep VedaBase, or remove it as
[Removing VedaBase](../README.md#removing-vedabase) in the README says.
