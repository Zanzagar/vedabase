---
handoff:      2026-10-26-1925--work-moves-to-this-folder-and-the-unicode-files-wait
written:      2026-10-26 19:25 -0400
sessionStart: 2026-10-26 18:58 -0400
sessionId:    8f688260-7d77-43bc-b696-04c3d156cd94 (run from ~/projects, like the two before it)
agentRuns:    none; a headless check (claude -p --no-session-persistence, from ~/projects/vedabase) read this handoff before it was committed
branch:       main
commits:      cfd0463.. (only this brief's own commit; no code changed)
visibility:   public since 2026-10-20
tests:        none run, since no code changed; grill-gate CI passed on cfd0463
supersedes:   the 2026-10-20-0405 brief's "Highest-value work" (new input since); HANDOFF.md "Where the session records are" (corrected in place)
---

# Work moves to this folder; the Unicode files wait to be read

## Where things stand

`main` at the commit after `cfd0463`, in sync with `Zanzagar/vedabase`; no code has changed
since 2026-10-20. Session 7dc8950f filled its context, but its handoff was already pushed, so
nothing was lost. Since then the devotee who shares the installers has answered and sent five
files about turning VedaBase text into Unicode (archived on journel, not yet read), and the
maintainer said this work would resume on 2026-10-26. From now on, sessions run from
`~/projects/vedabase` (the maintainer's decision). State: `HANDOFF.md`.

## Read first

1. The VedaBase memories for this folder, in
   `~/.claude/projects/-home-$USER-projects-vedabase/memory/` (its `MEMORY.md` names
   them), above all the correspondence with the devotee who shares the installers: it and
   its news stay out of this public repository.
2. `HANDOFF.md`: State, then "Open, in order", where A–E are new.
3. `AGENTS.md`, and `tests/README.md` before changing code.

## Highest-value work

1. **Read the devotee's five files, then ask the maintainer what to build** (HANDOFF.md,
   Open A). First, because the maintainer told the devotee this work resumes now and these
   files are what the devotee sent for it. The plain-text brief addressed to the maintainer
   comes first.
2. **How the README and `docs/sources.md` speak of the Drive folders' maintainer** (Open B):
   ask the maintainer how it should read. Second, because devotees read those pages, and it
   is quick once decided.
3. **Windows: the checks still open** (HANDOFF.md, State, "Windows, what is still open").
   Most devotees use Windows.
4. **A real Mac run** with a field tester (the private notes name a candidate).
5. **Where the Drive files live in the long run** (Open C); then the small items D and E,
   the Gcenx Wine mirror (Open 3) and the smaller items of Open 4.

## Hard rules

- Never commit the VedaBase files or anything an install produced.
- Keep the devotee's five files, and anything derived from them, out of this repository
  until the maintainer and their authors agree (HANDOFF.md, Open A, says who is known);
  unpack them into a new, empty folder outside the repository, and run nothing from them.
- Never test against journel's live install (`/journel/s0/$USER/vedabase`); `tests/`
  redirect `HOME` and `XDG_*` and check that yours are unchanged.
- One verifier per question, never one per finding (harness ADR 0001); Codex review on
  diffs that matter.
- Every commit carries a `Fix:`/`Docs:`/`Chore:`/`Test:` or `Decided:` trailer.
- This repository is public: name roles, and put private context in the memory for this
  folder.

## Traps from this session

- **A stale message store reads as silence.** The bridge that syncs the maintainer's
  messages died when journel rebooted on 2026-10-22 and nothing restarted it, so for four
  days every look at the chat showed no reply; restarting it brought the missing days in.
  Check the bridge before concluding nobody wrote (the private notes say how).
- **Queued messages hide from a search of user turns.** In 7dc8950f's transcript, what the
  maintainer typed while the session worked is stored as `queue-operation` and
  `queued_command` entries; a timeline built from user turns alone missed the maintainer's
  own question, on 2026-10-20, about running in the wrong folder.
- **A session at its limit cannot write its handoff.** 7dc8950f's last request ("Handoff")
  got "Prompt is too long"; nothing was lost only because its handoff had been pushed six
  days earlier, at 1% context. Push the handoff while context remains.
- **`/resume` works only from the folder a session ran in.** The two sessions titled
  "vedabase" in this folder's list are refused attempts to resume the old sessions from
  here; neither did any work.
