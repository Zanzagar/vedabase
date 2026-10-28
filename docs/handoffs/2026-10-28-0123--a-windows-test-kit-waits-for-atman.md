---
handoff:      2026-10-28-0123--a-windows-test-kit-waits-for-atman
written:      2026-10-28 01:23 -0400
sessionStart: 2026-10-27 12:16 -0400
sessionId:    68ae51a3-5b15-4047-9457-6178d1b9544a
agentRuns:    wf_e8ff7ca7-c84 (seven tasks, one read-only verifier each; 7 of 7 returned, the Devanagari claim refuted); one agent for the lock fix on viewer/port-and-install-lock; pinned Codex reviews (gpt-6-astra): mac/wine-copy (the copy's missing LGPL sources) and viewer/port-and-install-lock twice (needs-attention both times)
branch:       main
commits:      2885be3.. (this brief's own commit last)
visibility:   public since 2026-10-20
tests:        main's installer code is unchanged since 21d526c, where the whole suite passed (unicode.sh 199, nudge.sh 13, linux-e2e.sh 85 with Chromium, mac-sim.sh 16, interrupt.sh 13, rollback.sh 9); tests/windows/check.ps1 is new, parsed and ASCII, never run on Windows; the parked branch passed linux-e2e.sh 93 at f2cd065 and 106 at f5aa5a7
supersedes:   the 2026-10-27-1634 brief: its items 1, 2, 4, 5 and 6 and the quick jobs are done or settled (HANDOFF.md, State); its item 3 waits on the devotee, with evidence now
---

# A Windows test kit waits for Atman

## Where things stand

`main` is pushed and green. It holds a Windows test kit, `tests/windows/check.ps1`,
which has never run on Windows. The next session runs on Atman, the maintainer's
Windows 11 PC, starting fresh. Two branches are parked, unmerged:
`viewer/port-and-install-lock` and `mac/wine-copy` (HANDOFF.md, State and Open 3).
State: `HANDOFF.md`.

## Read first

1. `tests/windows/README.md`: how to run the kit, and what it does and does not check.
2. `docs/testing.md`: check 8 and "Windows only".
3. `HANDOFF.md`: State (both 68ae51a3 bullets), then "Windows, what is still open".
   The correspondence with the devotee is in the memory on journel, not on Atman;
   the Windows checks do not need it.

## Highest-value work

1. **On Atman, the Windows checks.** Pull `main` into the clone there. Install from
   it (`Install-VedaBase-Windows.cmd`; over the existing install it only finishes the
   setup and keeps the notes). Then, in an ordinary Command Prompt (not as
   administrator), in the clone's folder:
   `powershell -ExecutionPolicy Bypass -File tests\windows\check.ps1 > check.txt`.
   Then do the checks it lists as needing a person: Ctrl+Alt+U inside VedaBase and in
   another program, a console flash, the focus afterwards, a second account, a
   standard user, an accepted restart, an uninstall and reinstall. Since the kit has
   never run, a FAIL may be its own bug: its detail lines tell which. Write the results
   up for devotees the way `docs/windows-test-2026-10.md` does, in a new dated report,
   and keep the evidence on Atman.
2. **On Atman's WSL, WSLg:** the Linux installer and check 8 there (copy in Folio,
   paste in a Windows program, `vedabase unicode`). It has never been tried.
3. **Later, on journel, the maintainer's calls:** È → ü once the devotee confirms (the
   unsent draft in the session archive asks him; Open G has the count); Open 3 (the
   Gcenx copy's sources, or stopping the Mac installer when its Wine is gone, or
   leaving it); Open H (Kron4ek 11.19, or a later build with 3c49b97b, through the
   archive's address-space probe first); the parked viewer branch (HANDOFF.md, State,
   says how to finish it); Devanagari (Open I).

## Hard rules

- Never commit the VedaBase files or anything an install produced.
- Never test against journel's live install (`/journel/s0/$USER/vedabase`).
- One verifier per question, never one per finding (harness ADR 0001); Codex
  review on diffs that matter.
- Every commit carries a `Fix:`/`Docs:`/`Chore:`/`Test:` or `Decided:` trailer.
- This repository is public: name roles, and put private context in the memory
  for this folder.

## Traps from this session

- **The kit has only run with Windows faked** (a harness passed 79 of 79 under
  pwsh 7 on Linux): its registry, ACL, WinForms clipboard and shortcut-launch paths
  are untested; and on a PC whose ANSI code page is not 1252 it skips one test.
- **A wave's agents can write into each other's worktrees:** the Mac-sheet agent's
  files landed in the viewer-fixes worktree. Take each task's files by path, from
  wherever they are, and check `git status` in every worktree before removing it.
- **Republishing a binary bundle brings its licences' duties:** the Gcenx Wine
  bundles MacPorts LGPL libraries (GnuTLS, nettle, GMP...), whose exact sources a copy
  must carry; the copy was withdrawn within the hour.
- **journel's 250 GiB hides memory bugs:** Wine 11.20 commits a 32 GiB mapping at
  start (bug 60528), fine there, fatal on an ordinary PC.
- **`setpriv --pdeathsig` needs util-linux 2.33 or later,** and it kills only the
  process it is set on, not that process's children.
- **A lock handed from one copy of a script to another leaks at the handover;** see
  HANDOFF.md, State, for the design that avoids it.
