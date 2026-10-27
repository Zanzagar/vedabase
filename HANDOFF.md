# HANDOFF — the living state of the VedaBase installers

Corrected in place (old text struck through). The newest file in `docs/handoffs/` is the
latest session's brief; this file is what is true. It is for agents and the maintainer,
not for the devotees the installers go to: `.gitattributes` keeps it out of GitHub's
"Download ZIP" (~~a clone or a collaborator still sees it~~ **► anyone browsing the
public repository sees it**).

## What this is

- Installers for the Bhaktivedanta VedaBase desktop program (Folio Views 4.3, a 2003
  32-bit Windows program) with the VedaBase 25 and VaniBase 25 infobases, fetched from
  Ekanatha dāsa's public Google Drive folders and checked by SHA-256
  (`manifest/drive-files.tsv`): Linux and WSL (portable Wine 11.0, unattended), macOS
  (Gcenx Wine 11.0_1; the user clicks the wizard) and Windows 10/11 (native,
  PowerShell 5.1).
- The maintainer asked for it on 2026-10-19, after the devotee who shares the installers
  offered him the program. The maintainer will give the repository and its documentation
  to that devotee, who shares it with other devotees, many of them not technical.
  `README.md` and `docs/` are written for them.
- Never commit the program, the infobases, the fonts or anything an install produced
  (`.gitignore`). They belong to the Bhaktivedanta Archives and the BBT; the 2003
  licence allows one host computer and one user at a time plus an archival copy, and
  forbids "on-line system" use (`docs/how-it-works.md`, "The license you accept").

## State (2026-10-20; ► checked 2026-10-26)

- **► 2026-10-26: nothing in the code has changed since cfd0463** (2026-10-20). The
  devotee who shares the installers answered the maintainer on the evening of 2026-10-20
  and sent five files about turning text copied out of VedaBase into Unicode, among them a
  2019 copy-to-Unicode utility whose buttons Windows updates break, which answers, at
  least in part, the README's "What's next" item "What Windows updates broke". They are in
  the archive below
  (`unicode-files-2026-10-20/`), not here, ~~and nobody has read them yet~~ **► and were
  read on 2026-10-26; the notes on them stay private, beside them in the archive
  (`analysis-2026-10-26/README.md`)**. The
  correspondence, and news in it about the Drive folders' maintainer, are in the
  maintainer's private notes (Claude's memory for this folder), since this repository is
  public. What follows from them: "Open, in order", A–C.
- **► 2026-10-26, session 39638aaf (the first run from this folder):** the five files
  were read (private notes in the archive). The maintainer decided Open A (a converter
  for text copied out of VedaBase, in all three installers) and the factual half of
  Open B (3449587). **The converter is finished on the local branch `unicode/converter`**
  (journel's clone only: it carries the 31-letter table, which waits for the devotee's
  yes; a bundle of it lies beside the private notes): `bin/vedabase-unicode` (Linux,
  macOS; `vedabase unicode`), `windows/vedabase-unicode.ps1` (Ctrl+Alt+U), the Mac app
  *VedaBase Unicode*, the Linux menu entry, `lib/balaram-unicode.tsv`, and
  `tests/unicode.sh`. On the branch, `unicode.sh` (198 checks) and `mac-sim.sh` (16) pass
  on its tip, and `linux-e2e.sh` (40, the browser checks included) passed before the two
  fixes below. Codex (gpt-6-astra) reviewed it three times: a failed step passing for
  success and a quick second press converting twice (both re-derived, fixed: 5a4124e);
  then a lock taken from a still-running press and unchecked reads (re-derived, fixed:
  621cdbd); the third found the lock itself still unsound (a reclaim that can take a
  fresh lock, a reclaim guard a kill can strand, a stale PID reused by another process),
  **open: do not merge before it is answered** (proposal in the 2026-10-26-2146 brief).
  Never run on Windows or a Mac.
- `main` holds ~~everything up to the merge of `review/verdict-followups`
  (`5e1dd70..58eec55`)~~ **the installers (`5e1dd70..58eec55`, merged), then the
  claude-harness adoption (73c9683, cb405ea)** **► and the Windows fixes from the Atman runs
  (9eefebf, 63c0764, 37d4adb, 6151aa1, d9b112d)**, pushed to the ~~private~~ **► public**
  GitHub repository `Zanzagar/vedabase`.
- **Public since 2026-10-20** (the maintainer's decision, so that the devotee who shares
  the installers can see it), with the README's opening rewritten for visitors and the
  GitHub "About" filled in. The maintainer will make it private again, shared with that
  devotee's GitHub account, or remove it at his request. Its history shows the
  maintainer's commit email, journel paths and two early remarks about that devotee's
  messages; no credentials. **► Since 2026-10-20 this file names roles, not people or
  accounts. AGENTS.md and the frozen handoffs still name the maintainer, that devotee and
  journel's account (the 2026-10-20-0405 handoff also names a possible Mac tester), and the
  README's thanks and `docs/sources.md` name that devotee: the maintainer's call.**
- **claude-harness adopted** 2026-10-20 under the maintainer's standing decision of
  2026-09-28: AGENTS.md, CLAUDE.md, `.claude/settings.json`, `docs/handoffs/`, the commit
  gate (`core.hooksPath` set in journel's clone; a clone elsewhere, such as Atman's, runs
  `git config core.hooksPath .githooks` once), grill-gate CI green, squash merges set to
  PR title / PR body. All of it export-ignored.
- **The review is closed.** Workflow `wf_efcb88f5-f2e` (five lenses, 68 findings, one
  verifier per finding, which harness ADR 0001 no longer allows) finished in the old
  session's process after that session ran out of context. Commit 6942798 had acted on
  the raw findings; f69c896 acted on the verdicts it had not covered; three Codex
  adversarial reviews (gpt-6-astra) then found more, all fixed (f77bd79, f477528,
  58eec55). One recommendation was not taken: counting the old prefix in the
  `--reinstall` free-space sum is already right, since deleting it frees that space.
- **Linux and WSL**, tested on Ubuntu 24.04 (journel) with `tests/` (see
  `tests/README.md`): clean unattended installs, `doctor`, private permissions, the
  browser viewer (connects, no lockout after wrong passwords, typing reaches Folio),
  backup and restore, damaged backups refused without touching the prefix, Ctrl-C /
  closed terminal / SIGKILL in the middle of the wizard. Not tried: a real WSL2,
  Debian 12, a desktop session.
- **macOS**, simulated only (`tests/mac-sim.sh`: real bash 3.2, macOS commands shimmed,
  Linux Wine standing in, a user who never closes the Fonts window). Never run on a Mac.
- **Windows**: parsed by PowerShell 7 on Linux; `Restore-Notes` and the Active Setup
  command line unit-tested there. ~~Never run on Windows.~~ **► First real run
  2026-10-20 on Atman (Windows 11 Home 25H2, Windows PowerShell 5.1.26100), by the
  Atman session: the elevated phase stopped before any download, because 5.1's
  `New-Item -Force` refuses `C:\`; fixed in 9eefebf, ~~re-run pending~~.** **► Second
  run (41bc3f3): ~~every `docs/testing.md` check passed~~ ► the seven "Every system"
  checks of `docs/testing.md` and 35 file and registry checks passed, with *Complete*
  chosen in the wizard (it is pre-selected). Found and fixed: Windows XP compatibility
  mode made every start of Views.exe demand administrator rights (error 740), and Folio
  closed normally without it, so the installer no longer sets it, removes an earlier
  version's setting and flushes the compatibility cache; the wizard steps (a media player
  or "Pick an app" opens for INTRO.WAV, no Fonts window, restart prompts Cancel then OK,
  a pre-filled name); a stale recent-file entry Install.exe writes.** ~~OPEN: after
  uninstalling, a *Custom* reinstall (63c0764) showed blank panes; the cause (Custom, or
  the uninstall) is unknown.~~ **► Solved by the Atman session: not Custom (its files,
  system DLLs and registry matched journel's working install). The 2003 uninstaller
  deletes the font files; the fonts Register-Fonts had loaded into that Windows sign-in
  stayed loaded but unusable, and the reinstall did not reload them, so everything drawn
  in VedaBase's own fonts was blank until the next sign-in. Register-Fonts now unloads
  and reloads all 51 and broadcasts WM_FONTCHANGE (the same steps fixed it by hand on
  Atman).** **► Verified on Atman (Windows PowerShell 5.1), no reboot or sign-out:
  Remove-OldCompatMode removed a planted XP layer and VedaBase then opened with no UAC;
  the transcripts end cleanly; after 6151aa1 each font is loaded exactly once and
  VedaBase and VaniBase render. Not re-run with the fix: a real uninstall and reinstall
  in one sign-in; d9b112d's change (warn when the cache flush returns False) has not run
  on Windows.**
- **2026-10-20: Windows, what is still open.** Devotee-facing summary of the Atman runs:
  [`docs/windows-test-2026-10.md`](docs/windows-test-2026-10.md). Run 3 (63c0764,
  *Custom* after an uninstall) matched the README's wizard steps and passed the 35 file
  and registry checks. The evidence (the tester's report, logs and screenshots) stays on
  the test PC (`~/projects/vedabase-testing/evidence/` in its WSL), not in this
  repository: it names accounts and holds private screenshots. Not yet run on Windows: a
  full uninstall and *Custom* reinstall in one sign-in on d9b112d or later; a second
  account (Active Setup there); a standard-user install; an accepted restart; a note
  saved while Views.exe runs unelevated; d9b112d's warning; an error inside the
  administrator window (9eefebf's single pause; only an unanswered UAC was re-tested);
  opening the File menu's recent-file entry (after run 3 the registry already held only
  the corrected `File1`); the notes restore across a wizard re-run; the free-space
  filler (not needed on Atman); SmartScreen and the "Open File – Security Warning"
  (never shown: the ZIP was unblocked first); Windows 10, Arm, a non-English Windows.
- **Found this session, worth knowing:** Install.exe's launcher checks free space in
  32-bit arithmetic and refuses when the free space sits just above a multiple of
  4 GiB (the installers now write a 128 MiB filler first; `docs/how-it-works.md`).
  Bash's EXIT trap sees status 0 on SIGINT/SIGHUP unless INT/HUP/TERM traps exit.
- **journel's own install**: home `/journel/s0/$USER/vedabase` (made 0700 on
  2026-10-20: it was readable by every account on journel; refreshed with the merged
  code the same day, `doctor` passing), launcher
  `~/.local/bin/vedabase`, and `~/.config/vedabase/home` remembers the home. A
  from-scratch reinstall needs `./install.sh --home /journel/s0/$USER/vedabase`. Run
  `vedabase doctor` before assuming it is broken. Never test against it.
- **Archive** on journel: `/journel/s1/$USER/archive/vedabase/` holds the Drive files
  (with the CrossOver guide `VedaBase_CrossOver_Installation.pdf`, which the devotee who
  shares the installers passed on, and Ekanatha's `README.docx`), a backup of the working
  prefix, both Wine builds, and
  `session-7f53bfb5-2026-10-19/` (that session's transcript, workflow journals and agent
  transcripts, its scratch scripts and screenshots, and the bash 3.2, ShellCheck and
  PowerShell builds the tests use). **► Since 2026-10-26 also `session-7dc8950f-2026-10-20/`
  (that session's transcript) and `unicode-files-2026-10-20/` (the five files of
  2026-10-20 from the devotee who shares the installers, one folder each, with
  `SHA256SUMS`; untrusted, and not for this repository; ► with the private notes on them,
  2026-10-26, in `analysis-2026-10-26/`).**

## Open, in order

**► New on 2026-10-26, ahead of 1–4** (lettered, so that the numbers the frozen briefs
cite stay right):

A. ~~**Read the devotee's five files** (State, 2026-10-26) as data, the plain-text brief
   addressed to the maintainer first; run nothing from them.~~ **► Read on 2026-10-26: start
   from the private notes in the archive (`unicode-files-2026-10-20/analysis-2026-10-26/README.md`),
   not from the files; still run nothing from them.** Then settle with the
   maintainer what to build. They bear on two of the README's "What's next" items, "What
   Windows updates broke" and "Unicode text". Nothing from the files enters this
   repository until the maintainer agrees, and so do their authors: the utility's author
   for the zip; for the other four, ~~who wrote them is not stated (ask the devotee who sent
   them)~~ **► the private notes say who made them**.
   <a id="unicode-converter"></a>**► Decided 2026-10-26 (the maintainer): a converter in all
   three installers**, which turns text copied out of VedaBase into Unicode on the
   clipboard: Windows a shortcut with a key (PowerShell), Linux `vedabase unicode`, the Mac
   an app; tests at four seams (the shell filter under bash and bash 3.2, the PowerShell
   twin and the two agreeing byte for byte, the Linux clipboard, the Mac app in the
   simulation). **The table it needs enters this repository only after the devotee who
   shares the installers agrees**, so the work lives on the local branch
   `unicode/converter` in journel's clone, unpushed until then.
B. **The maintainer's call:** how the README ("If the download breaks", "What's next",
   the closing thanks) and `docs/sources.md` speak of the Drive folders' maintainer, given
   the news in the private notes. Ask the maintainer how it should read before changing
   those lines. **► Decided 2026-10-26: the lines about the downloads name the folders, not
   him ("set up by" where his name stays: `docs/sources.md`, `docs/how-it-works.md`); the
   README's closing thanks stays as it is until the devotee who shares the installers
   says how he would like it worded.** **► Later the same evening the maintainer asked for
   the thanks now: it remembers him with gratitude, "until his passing", and offers the
   installers "in continuation of his service". Provisional: revisit once the maintainer
   has written to the devotee.**
C. **Where the Drive files live in the long run.** The installers download from those
   folders and stop working if the folders go away; the archive holds the copy of
   2026-10-19 (`drive-files-2026-10-19/`). A question for the maintainer and the devotee
   who shares the installers; the licence's clause 2.4 limits copies.
D. ~~**A stale line in the README:** "What's next" says the installers "already try to" work
   around the freeze on exit, which they stopped doing in 37d4adb (the README's own
   Windows notes say so). A one-line fix, best made when A or B rewrites that section.~~
   **► Fixed 2026-10-26, with B.**
E. **The merged branch `review/verdict-followups`** is still on GitHub and in journel's
   clone; deleting it needs the maintainer's OK (`.claude/settings.json` asks before a
   remote delete).
F. **Copying text out of Folio under Wine** (found 2026-10-26). In
   the browser viewer's display (Xvnc, a Wine virtual desktop, no window manager), a
   word copied in Folio reached the X clipboard in one session of five. Folio offers its
   text on request only (`SetClipboardData` with no data, for "Folio Document Format"
   and CF_TEXT); Wine logged `acquire_selection`, yet the X server showed no owner of
   CLIPBOARD, and Wine's log had no X error. When the text did arrive, a NUL and
   leftovers of Folio's buffer followed it. Not tried: a Linux desktop with a window
   manager (`vedabase open`), the Mac. Next: try those; trace the X protocol around
   `acquire_selection`; look for a Wine bug. Meanwhile `vedabase web`'s hint "Copy text
   out through the clipboard tab on the noVNC side panel" is unverified.

1. ~~One real run each on Windows (Atman) and on a Mac~~ ~~**Windows: settle the blank
   panes** (State) before the README's "choose Custom" is trusted~~ (solved; Custom works);
   **Windows:** the checks still open in State ("Windows, what is still open").
   **Mac:** a field tester with a Mac (the maintainer has someone in mind), following
   `docs/testing.md`.
   ~~Everything Windows-specific (the elevated phase, Active Setup, the notes restore, the
  free-space filler) has only been read and parsed, never run.~~ **► 2026-10-20: the
   elevated phase ran on Atman and Active Setup's entry was checked there; what is still
   unrun is in State.**
2. ~~**The maintainer decides how to share it.** The repository is private, so the
   README's "Code → Download ZIP" and its `git clone` line fail for anyone else. Options:
   make it public (seven early commits name journel and the account, and the agent files
   carry journel paths; export-ignore only keeps them out of the ZIP), send a ZIP, or
   publish a fresh public repository from `git archive` output (no history, no agent
   files). It carries Ekanatha's Drive file IDs either way.~~ **► Decided 2026-10-20:
   public (see State). If the devotee who shares the installers asks for it to be
   private, make it private and add his GitHub account as a collaborator; the README's
   download steps then work only for him.**
3. The maintainer decides whether to mirror the pinned Gcenx Wine as a release asset, so
   the Mac installer does not fall back to whatever Gcenx publishes next (review finding
   security:5); ~~it depends on 2~~ possible now that the repository is public.
4. Smaller, optional: curl's internal retries re-download the same span (linux-fresh:15);
   a Windows install whose master infobase is missing could copy the staged one into
   place instead of re-running the wizard (windows-ps51:2); `vedabase web` could reprint
   the tunnel even on WSL's early return; the finish phase repoints only the recent-file
   list's `File1`, so an install where VedaBase was opened before that fix, which moves
   the stale "4 Sh" entry to `File2`, keeps it (a harmless error dialog if clicked).

## Where the session records are

~~Both sessions so far ran~~ **► The first three sessions ran** from `~/projects`, not from
this folder, so their transcripts are under `~/.claude/projects/-home-$USER-projects/`:
`7f53bfb5-c5f0-4cc2-ab2c-f894b3a323d4`
built everything (workflows `wf_f94b032d-525`, Wine research; `wf_fdb69b90-1be`,
cross-platform research; `wf_efcb88f5-f2e`, the review), ~~and~~
`7dc8950f-ca3e-4233-be0f-553ad6a93b38` closed the review **► and relayed the Windows runs,
then filled its context (its handoff was already pushed, cfd0463), and
`8f688260-7d77-43bc-b696-04c3d156cd94` (2026-10-26) moved the work to this folder**
**► ; `39638aaf-16e5-45b4-804f-0ea9a4936dda` (2026-10-26) was the first run from this
folder (see below)**.
~~The first is also archived (above); the newest file in `docs/handoffs/` names what the
second ran.~~ **► The first two are also archived (above); the 2026-10-20-0405 brief names
what the second ran. From 2026-10-26, sessions run from this folder
(`cd ~/projects/vedabase && claude`), so their transcripts are under
`~/.claude/projects/-home-$USER-projects-vedabase/`, beside this folder's own memory.**
