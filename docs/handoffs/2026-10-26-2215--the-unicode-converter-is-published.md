---
handoff:      2026-10-26-2215--the-unicode-converter-is-published
written:      2026-10-26 22:15 -0400
sessionStart: 2026-10-26 19:26 -0400
sessionId:    39638aaf-16e5-45b4-804f-0ea9a4936dda (the first run from ~/projects/vedabase)
agentRuns:    no workflow; four pinned Codex adversarial reviews (gpt-6-astra): the branch, then each of its three fixes
branch:       main
commits:      95e288f.. (this brief's own commit last)
visibility:   public since 2026-10-20
tests:        on the merged code: tests/unicode.sh 197 checks, linux-e2e.sh 40 (on 0ef6106; the lock file's rename since is covered by unicode.sh), mac-sim.sh 16; static checks clean
supersedes:   the 2026-10-26-2146 brief (its first item is done: the lock was redone and the converter published)
---

# The Unicode converter is published

## Where things stand

`main` holds the converter and is pushed: *VedaBase Unicode* in all three
installers (Windows Ctrl+Alt+U, Linux `vedabase unicode` and a menu entry, a
Mac app), the maintainer having said that anything may go public for now.
Its lock is flock on Linux, a named mutex on Windows, none on the Mac. It has
never run on Windows or a real Mac. State: `HANDOFF.md`.

## Read first

1. The memory for this folder (its `MEMORY.md`): the correspondence with the
   devotee who shares the installers, and the questions waiting for him.
2. `HANDOFF.md`: State (2026-10-26, session 39638aaf), then Open B, F and G.
3. `docs/how-it-works.md`, "Text copied out of VedaBase".

## Highest-value work

1. **Copying text out of Folio under Wine** (HANDOFF.md, Open F). In the
   browser viewer, a copy reached the X clipboard in one session of five; a
   Linux desktop with a window manager and the Mac are untested. First,
   because on Linux and the Mac the converter has nothing to convert without it.
2. **Windows and the Mac, for real:** check 8 of `docs/testing.md` (VedaBase
   Unicode), with the Windows checks still open. Most devotees use Windows,
   and nothing of the converter has run there.
3. **È** (HANDOFF.md, Open G): the maintainer's call, after the devotee says
   whether È turns up in text he copies; the table now says Ṝ.
4. **The thanks wording** (Open B), after the maintainer has written to the
   devotee; then Open C and the rest.

## Hard rules

- Never commit the VedaBase files or anything an install produced.
- Never test against journel's live install (`/journel/s0/$USER/vedabase`).
- One verifier per question, never one per finding (harness ADR 0001); Codex
  review on diffs that matter.
- Every commit carries a `Fix:`/`Docs:`/`Chore:`/`Test:` or `Decided:` trailer.
- This repository is public: name roles, and put private context in the memory
  for this folder.

## Traps from this session

- **bash 3.2's `${var//x/y}` is quadratic**: 260 KB did not finish in 300 s;
  sed does it at once (AGENTS.md).
- **A hand-made lock is a trap.** An mkdir/PID lock drew new holes in three
  Codex reviews in a row; flock, which the kernel releases, ended it. A child
  that lingers (xclip serving the clipboard) inherits the lock's fd unless it
  is started with `9>&-`, and then holds the lock after the press.
- **A bare `wait` in a test waits for every background job**, the Xvnc
  started by `start_display` included: the run hangs. Wait for the PID.
- **`pgrep -f PATTERN` matches the shell running it** when the pattern is in
  its own command line: a `kill` of the result killed the session's shell.
  Pick processes by `ps -o comm=` instead.
- **A count of 0 can be a broken pattern**: `grep -c $'[\x80-\xff]'` found no
  non-ASCII bytes in a file full of them; `tr -d '\000-\177' | wc -c` did.
  `cut -c` cuts bytes and split a UTF-8 letter, making a log binary to grep.
- **Windows PowerShell 5.1 reads a script without a BOM as ANSI**: keep `.ps1`
  files plain ASCII; PowerShell 7 on Linux never shows the difference.
- **Headless Chromium's Ctrl+C through noVNC did not reach Folio**; `xdotool
  key ctrl+c` did, and Folio's search ignores case (it cannot count È apart
  from è) and keeps its old query unless the box is cleared.
