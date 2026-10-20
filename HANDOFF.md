# HANDOFF — the living state of the VedaBase installers

Corrected in place (old text struck through). The newest file in `docs/handoffs/` is the
latest session's brief; this file is what is true. It is for agents and Corey, not for the
devotees the installers go to: `.gitattributes` keeps it out of GitHub's "Download ZIP"
(~~a clone or a collaborator still sees it~~ **► anyone browsing the public repository sees it**).

## What this is

- Installers for the Bhaktivedanta VedaBase desktop program (Folio Views 4.3, a 2003
  32-bit Windows program) with the VedaBase 25 and VaniBase 25 infobases, fetched from
  Ekanatha dāsa's public Google Drive folders and checked by SHA-256
  (`manifest/drive-files.tsv`): Linux and WSL (portable Wine 11.0, unattended), macOS
  (Gcenx Wine 11.0_1; the user clicks the wizard) and Windows 10/11 (native,
  PowerShell 5.1).
- Corey asked for it on 2026-10-19, after Tāraka dāsa offered him the program. Corey
  will give the repository and its documentation to Tāraka, who shares it with other
  devotees, many of them not technical. `README.md` and `docs/` are written for them.
- Never commit the program, the infobases, the fonts or anything an install produced
  (`.gitignore`). They belong to the Bhaktivedanta Archives and the BBT; the 2003
  licence allows one host computer and one user at a time plus an archival copy, and
  forbids "on-line system" use (`docs/how-it-works.md`, "The license you accept").

## State (2026-10-20)

- `main` holds ~~everything up to the merge of `review/verdict-followups`
  (`5e1dd70..58eec55`)~~ **the installers (`5e1dd70..58eec55`, merged), then the
  claude-harness adoption (73c9683, cb405ea)**, pushed to the private GitHub repository
  `Zanzagar/vedabase`.
- **Public since 2026-10-20** (Corey, 2026-10-20: *"Make it public so taraka prabhu can see
  it"*), with the README's opening rewritten for visitors and the GitHub "About" filled
  in. He will make it private again, shared with Tāraka's GitHub account, or remove it at
  Tāraka's request. Its history shows Corey's commit email, journel paths and two early
  remarks about Tāraka's messages; no credentials.
- **claude-harness adopted** 2026-10-20 under Corey's standing decision of 2026-09-28:
  AGENTS.md, CLAUDE.md, `.claude/settings.json`, `docs/handoffs/`, the commit gate
  (`core.hooksPath` set in journel's clone; a clone elsewhere, such as Atman's, runs
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
  run (41bc3f3): every `docs/testing.md` check passed, with *Complete* chosen in the
  wizard (it is pre-selected). Found and fixed: Windows XP compatibility mode made every
  start of Views.exe demand administrator rights (error 740), and Folio closed normally
  without it, so the installer no longer sets it, removes an earlier version's setting
  and flushes the compatibility cache; the wizard steps (a media player or "Pick an app"
  opens for INTRO.WAV, no Fonts window, restart prompts Cancel then OK, a pre-filled
  name); a stale recent-file entry Install.exe writes. ~~OPEN: after uninstalling,
  a *Custom* reinstall (63c0764) showed blank panes; the cause (Custom, or the uninstall)
  is unknown.~~ **► Solved by the Atman session: not Custom (its files, system DLLs and
  registry matched journel's working install). The 2003 uninstaller deletes the font
  files; the fonts Register-Fonts had loaded into that Windows sign-in stayed loaded but
  unusable, and the reinstall did not reload them, so everything drawn in VedaBase's own
  fonts was blank until the next sign-in. Register-Fonts now unloads and reloads all 51
  and broadcasts WM_FONTCHANGE (the same steps fixed it by hand on Atman).** **► Verified
  on Atman (Windows PowerShell 5.1), no reboot or sign-out: Remove-OldCompatMode removed
  a planted XP layer and VedaBase then opened with no UAC; the transcripts end cleanly;
  after 6151aa1 each font is loaded exactly once and VedaBase and VaniBase render. Not
  re-run with the fix: a real uninstall and reinstall in one sign-in.** The tester's report and evidence are on Atman in
  `/home/corey/projects/vedabase-testing/evidence/`. Not run there: a second account, a
  standard user, an accepted restart, a note saved without elevation, SmartScreen.**
- **Found this session, worth knowing:** Install.exe's launcher checks free space in
  32-bit arithmetic and refuses when the free space sits just above a multiple of
  4 GiB (the installers now write a 128 MiB filler first; `docs/how-it-works.md`).
  Bash's EXIT trap sees status 0 on SIGINT/SIGHUP unless INT/HUP/TERM traps exit.
- **journel's own install**: home `/journel/s0/cjh5690/vedabase` (made 0700 on
  2026-10-20: it was readable by every account on journel; refreshed with the merged
  code the same day, `doctor` passing), launcher
  `~/.local/bin/vedabase`, and `~/.config/vedabase/home` remembers the home. A
  from-scratch reinstall needs `./install.sh --home /journel/s0/cjh5690/vedabase`. Run
  `vedabase doctor` before assuming it is broken. Never test against it.
- **Archive** on journel: `/journel/s1/cjh5690/archive/vedabase/` holds the Drive files
  (with Tāraka's `VedaBase_CrossOver_Installation.pdf` and Ekanatha's `README.docx`), a
  backup of the working prefix, both Wine builds, and
  `session-7f53bfb5-2026-10-19/` (that session's transcript, workflow journals and agent
  transcripts, its scratch scripts and screenshots, and the bash 3.2, ShellCheck and
  PowerShell builds the tests use).

## Open, in order

1. ~~One real run each on Windows (Atman) and on a Mac~~ ~~**Windows: settle the blank
   panes** (State) before the README's "choose Custom" is trusted~~ (solved; Custom works);
   **Windows:** the checks the Atman runs skipped (a second account, a standard user, an
   accepted restart, the font reload in an uninstall-and-reinstall run). **Mac:** a field tester (Corey suggests Anandini Lalita, through
   Tāraka), following `docs/testing.md`.
   Everything Windows-specific (the elevated phase, Active Setup, the notes restore, the
  free-space filler) has only been read and parsed, never run.
2. ~~**Corey decides how to share it.** The repository is private, so the README's
   "Code → Download ZIP" and its `git clone` line fail for anyone else. Options: make it
   public (seven early commits name journel and the account, and the agent files carry
   journel paths; export-ignore only keeps them out of the ZIP), send a ZIP, or publish a
   fresh public repository from `git archive` output (no history, no agent files). It
   carries Ekanatha's Drive file IDs either way.~~ **► Decided 2026-10-20: public (see
   State). If Tāraka asks for it to be private, make it private and add his GitHub
   account as a collaborator; the README's download steps then work only for him.**
3. Corey decides whether to mirror the pinned Gcenx Wine as a release asset, so the Mac
   installer does not fall back to whatever Gcenx publishes next (review finding
   security:5); ~~it depends on 2~~ possible now that the repository is public.
4. Smaller, optional: curl's internal retries re-download the same span (linux-fresh:15);
   a Windows install whose master infobase is missing could copy the staged one into
   place instead of re-running the wizard (windows-ps51:2); `vedabase web` could reprint
   the tunnel even on WSL's early return.

## Where the session records are

Both sessions so far ran from `~/projects`, not from this folder, so their transcripts are
under `~/.claude/projects/-home-cjh5690-projects/`: `7f53bfb5-c5f0-4cc2-ab2c-f894b3a323d4`
built everything (workflows `wf_f94b032d-525`, Wine research; `wf_fdb69b90-1be`,
cross-platform research; `wf_efcb88f5-f2e`, the review), and
`7dc8950f-ca3e-4233-be0f-553ad6a93b38` closed the review. The first is also archived
(above); the newest file in `docs/handoffs/` names what the second ran.
