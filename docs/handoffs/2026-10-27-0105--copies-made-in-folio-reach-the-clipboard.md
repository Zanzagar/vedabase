---
handoff:      2026-10-27-0105--copies-made-in-folio-reach-the-clipboard
written:      2026-10-27 01:05 -0400
sessionStart: 2026-10-26 22:21 -0400
sessionId:    4133d657-2db5-4198-943f-fb31b206014b
agentRuns:    no workflow (AGENTS.md: a wave is the last resort, and tests answered the questions); five pinned Codex adversarial reviews (gpt-6-astra): the branch, then each of its fixes but the last, which changed only tests
branch:       main
commits:      f2b5bb4.. (this brief's own commit last)
visibility:   public since 2026-10-20
tests:        on the merged code: unicode.sh 199 checks, nudge.sh 13, linux-e2e.sh 58 (Chromium included), mac-sim.sh 16, interrupt.sh 13, rollback.sh 9; static checks clean
supersedes:   the 2026-10-26-2215 brief: its first item is done, and its trap "Headless Chromium's Ctrl+C through noVNC did not reach Folio" was wrong (it did; the copy waited for Wine to flush, HANDOFF.md Open F)
---

# Copies made in Folio reach the clipboard

## Where things stand

`main` holds the fix for Open F and is pushed. Wine 11.0 leaves its claim on
the X clipboard for a copy unsent until an X event wakes it (fixed upstream in
11.14, not in the 11.0 the installers pin), so `vedabase unicode` wakes Wine
before it reads, and the browser viewer runs a nudger once a second. Tested on
journel: the browser viewer, and openbox on a private display; not on GNOME,
KDE, Wayland, WSLg, Windows or a real Mac. State: `HANDOFF.md`.

## Read first

1. The memory for this folder (its `MEMORY.md`): the correspondence with the
   devotee who shares the installers, and the questions waiting for him.
2. `HANDOFF.md`: State (session 4133d657), then Open H, G and B.
3. `docs/how-it-works.md`, "Text copied out of VedaBase", its *Wine 11.0 and
   the X clipboard* bullet.

## Highest-value work

1. **Windows and the Mac, for real:** check 8 of `docs/testing.md` (it now
   pastes once before converting) and the Windows checks still open. Most
   devotees use Windows, and nothing of the converter has run there; on the
   Mac, whether a copy leaves VedaBase at all is untried.
2. **Open H, the maintainer's call:** a Wine with a33000a6 (11.14 or later, or
   12.0 in about January 2027) makes the nudges unnecessary; moving the pin
   needs the whole suite re-run, the wizard driving included.
3. **È (Open G) and the thanks wording (Open B):** both wait on the devotee,
   who has not written since 2026-10-22 (the bridge was checked at 22:30 on
   2026-10-26).
4. **A report from a full Linux desktop** (GNOME or KDE, X11 or Wayland), and
   WSLg: copy, paste elsewhere, convert.

## Hard rules

- Never commit the VedaBase files or anything an install produced.
- Never test against journel's live install (`/journel/s0/$USER/vedabase`).
- One verifier per question, never one per finding (harness ADR 0001); Codex
  review on diffs that matter.
- Every commit carries a `Fix:`/`Docs:`/`Chore:`/`Test:` or `Decided:` trailer.
- This repository is public: name roles, and put private context in the memory
  for this folder.

## Traps from this session

- **Wine's clipboard connection ignores every X error**
  (`x11drv_main.c:212`): a silent Wine log proves nothing there. Watch the X
  server instead: XFixes selection events and CreateNotify under the root and
  the Wine desktop showed the claim never arrived (the tools are archived:
  `/journel/s1/$USER/archive/vedabase/session-4133d657-2026-10-26/`).
- **A clipboard test whose owner is xclip cannot see this bug**: xclip sends
  its claim at once. `tests/x11/lazy-owner.py` behaves like Wine 11.0.
- **xclip `-t UTF8_STRING` falls back to STRING without a word** when the
  owner refuses: Latin-1 bytes, and the converter says "Nothing to convert".
- **`pkill -f PATTERN` killed this session's shell too**, though the last brief
  warned: pick processes by `ps -o comm=`, by their environment, or by what
  owns their lifetime.
- **openbox exits at once without a theme** ("Unable to load a theme"):
  unpacked from its .deb, it needs `XDG_DATA_DIRS` pointing into it. Starting it
  sets root properties, which flushes Wine: start it before the copy under test.
- **A loop's last `grep` sets its exit status**: "failed with exit code 1" from
  a test loop meant only that no FAIL lines were found.
- **`tests/interrupt.sh` fails now and then on timing**: "a closed terminal
  leaves no wizard or display running" failed once in six runs with the code
  under test unchanged. Rerun it before suspecting a change (HANDOFF.md, Open 4).
- **Records of a process outlive it.** A pid file, a lock file per home and one
  per display each outlived the browser viewer's display in a Codex review; an
  X selection, which the X server frees with either, did not. And Xlib's
  `XFlush` reads events into its queue: drain it before waiting on the socket.
