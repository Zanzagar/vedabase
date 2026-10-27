---
handoff:      2026-10-27-1634--the-browser-viewers-processes-are-found-by-what-they-are
written:      2026-10-27 16:34 -0400
sessionStart: 2026-10-27 12:16 -0400
sessionId:    68ae51a3-5b15-4047-9457-6178d1b9544a
agentRuns:    no workflow (AGENTS.md: a wave is the last resort, and tests and Codex answered the questions); five pinned Codex adversarial reviews (gpt-6-astra): the branch, then each round of fixes; the fifth approved
branch:       main
commits:      ec28d31.. (this brief's own commit last)
visibility:   public since 2026-10-20
tests:        on the merged code (21d526c): unicode.sh 199 checks, nudge.sh 13, linux-e2e.sh 85 (Chromium included), mac-sim.sh 16, interrupt.sh 13, rollback.sh 9; static checks clean; grill-gate green
supersedes:   the 2026-10-27-0105 brief: its trap "tests/interrupt.sh fails now and then on timing" is fixed (02503d0)
---

# The browser viewer's processes are found by what they are

## Where things stand

`main` holds the branch `viewer/pid-identity`, merged and pushed: `vedabase
stop` and `web` find Xvnc and websockify by the socket their display was
started with, never by a PID file, and `open`, `web` and `stop` run one at a
time under a lock. Tested on journel only (Ubuntu 24.04). State: `HANDOFF.md`.

## Read first

1. The memory for this folder (its `MEMORY.md`): the correspondence with the
   devotee who shares the installers. A draft message for the maintainer to
   send him waits, unsent, in this session's archive.
2. `HANDOFF.md`: State (session 68ae51a3), then Open H, G, B and 4.
3. `docs/how-it-works.md`, "Showing it on a headless machine (Linux)".

## Highest-value work

1. **Windows and the Mac, for real** (unchanged): check 8 of
   `docs/testing.md` on a Windows PC, and the Windows checks still open
   (HANDOFF.md, State); a field tester for the Mac. Most devotees use Windows,
   and nothing of the converter has run there.
2. **Open H, the maintainer's call:** a Wine with a33000a6 (11.14 or later;
   12.0 in about January 2027) makes the nudges unnecessary.
3. **È (Open G) and the thanks (Open B):** both wait on the devotee, who has
   not written since 2026-10-22 (the bridge was current at 11:39 on
   2026-10-27).
4. **A full Linux desktop:** check 8 passed under GNOME Shell 46 on X11, on
   a private display on journel (HANDOFF.md, Open F): a copy arrives at the
   next change of focus, and `vedabase unicode` converts without one. Still
   untried: GNOME's Wayland session (nested on journel, GNOME Shell never
   started its on-demand Xwayland), a desktop someone logs in to, KDE, WSLg.
5. **Open 4's new items:** the port in the printed link; install.sh outside
   the viewer's lock.

## Hard rules

- Never commit the VedaBase files or anything an install produced.
- Never test against journel's live install (`/journel/s0/$USER/vedabase`).
- One verifier per question, never one per finding (harness ADR 0001); Codex
  review on diffs that matter.
- Every commit carries a `Fix:`/`Docs:`/`Chore:`/`Test:` or `Decided:` trailer.
- This repository is public: name roles, and put private context in the memory
  for this folder.

## Traps from this session

- **A shell that mentions a pattern is matched by `pgrep -f`:** a test run
  from a command that also ran `pgrep -f "Xtigervnc.*-auth …"` counted that
  shell as a display left running. `home_xvncs` no longer uses `pgrep -f`;
  keep such patterns out of the command that runs a test.
- **Checks that pass red.** Two of this session's first drafts did: a lock
  check that `stop` passed by being slow (21 s with Folio open), and an HTTP
  200 that a stranded websockify still answered. Time an idle command, and
  check the exit status and the specific thing, not a side effect.
- **websockify drops a silent connection after 3 s:** to keep a connection's
  copy alive, a test must complete the WebSocket upgrade.
- **Bash reads a running script as it goes, and install.sh re-reads `lib/`
  on each run:** editing `tests/`, `lib/` or `bin/` while the suite runs
  changes the run. Wait for it.
- **`linux-e2e.sh` now takes about 13 minutes,** over the 10-minute limit of a
  foreground command: run it in the background.
- **Killing `dbus-run-session` instead of `gnome-shell`** left 20 session
  processes and two FUSE mounts behind; the archive's `gnome/stop-gnome.sh`
  ends them by their `XDG_RUNTIME_DIR` and unmounts.
