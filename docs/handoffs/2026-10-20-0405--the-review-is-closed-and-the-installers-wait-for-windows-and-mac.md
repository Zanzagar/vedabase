---
handoff:      2026-10-20-0405--the-review-is-closed-and-the-installers-wait-for-windows-and-mac
written:      2026-10-20 04:05 -0400
sessionStart: 2026-10-20 01:42 -0400
sessionId:    7dc8950f-ca3e-4233-be0f-553ad6a93b38
agentRuns:    none of its own; wf_efcb88f5-f2e (session 7f53bfb5's review) finished during it, in that session's process; three Codex adversarial reviews (gpt-6-astra) of 58fcf94.., f69c896.., f77bd79..; the Windows test handed to the Atman session atman-linked-torvalds (Remote Control)
branch:       main
commits:      040e7ec..003bc40 (and claude-harness d1acdc2)
visibility:   public since 2026-10-20 (Corey's decision, so Tāraka can see it)
tests:        tests/linux-e2e.sh 34/34, tests/interrupt.sh 13/13, tests/rollback.sh 9/9, tests/mac-sim.sh 9/9 on 58eec55; ShellCheck, bash 3.2 -n, PowerShell parse clean
supersedes:   none
---

# The review is closed; the installers wait for a real Windows PC and a real Mac

## Where things stand

`main` at the commit after `003bc40`, pushed to `Zanzagar/vedabase`, which Corey made
public on 2026-10-20 so that Tāraka can see it (the README's opening and the GitHub
"About" were rewritten for visitors first). The review that session 7f53bfb5 started is
closed: every verdict was checked against the code, the open ones fixed, then three Codex
rounds, each acted on. The repository has adopted the claude-harness rules and commit
gate. journel's own install runs the merged code. The first real Windows run was handed
to the Atman session (`atman-linked-torvalds`, over Remote Control) at the end of this
session; its result is not in this brief. State: `HANDOFF.md`.

## Read first

1. `HANDOFF.md`, the living state.
2. `AGENTS.md`: the rules, how to test, the pitfalls this code has hit.
3. `tests/README.md`, then `docs/testing.md` for the first real Windows and Mac runs.

## Highest-value work

1. **A real Windows run** (Atman), with `docs/testing.md`; in progress in the Atman
   session when this brief was written: read its report, or ask Corey for it. The whole Windows path (the
   elevated phase, Active Setup, the notes kept across a restart, the free-space filler,
   `-NoCompatMode`) has only been parsed, and two functions unit-tested, on Linux. It is
   the platform most devotees will use.
2. **A real Mac run**, Apple Silicon if possible (Corey suggests Anandini Lalita, who
   has a new MacBook, through Tāraka): Gatekeeper, Rosetta, the Fonts-window
   wait (which depends on `wine tasklist` behaving as it does on Linux), bug 60494.
3. **Corey's decisions**: ~~how to share (HANDOFF.md, Open 2)~~ decided, public; the Wine
   mirror (Open 3); whether the LICENSE should carry his name.
4. Optional refinements in HANDOFF.md, Open 4.

## Hard rules

- Never commit the VedaBase files or anything an install produced.
- Never test against journel's live install (`/journel/s0/cjh5690/vedabase`); `tests/`
  redirect `HOME` and `XDG_*` and check that yours are unchanged.
- One verifier per question, never one per finding (harness ADR 0001); Codex review on
  diffs that matter.
- Every commit carries a `Fix:`/`Docs:`/`Chore:`/`Test:` or `Decided:` trailer.

## Traps from this session

- `x=$(du ... | awk ...)` under `set -euo pipefail` ended every fresh install without a
  word, because du fails on folders that do not exist yet. The Mac simulation caught it.
- Bash's EXIT trap runs on Ctrl-C with `$? = 0`, so a trap that returns early on status 0
  does nothing; INT/HUP/TERM traps must `exit` with the signal's status.
- A background job of a non-interactive shell ignores SIGINT, so a "Ctrl-C test" built that
  way tests nothing (`tests/interrupt.sh` resets the disposition); `setsid` forks under job
  control, so `$!` is not the server's PID there.
- The Install.exe stall ("Setup" and a Temp-folder window, then nothing for ten minutes)
  was the launcher's 32-bit free-space check, not concurrency. Reproduce it by moving the
  free space to just above a multiple of 4 GiB.
- A Python helper named `typing.py` shadowed the standard module for its whole folder.
- Codex runs found what the verifiers had not, three times; the verifiers' "REFUTED" often
  meant "already fixed by 6942798", which landed while they ran.
