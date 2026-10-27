---
handoff:      2026-10-26-2146--the-unicode-converter-waits-for-the-devotee
written:      2026-10-26 21:46 -0400
sessionStart: 2026-10-26 19:26 -0400
sessionId:    39638aaf-16e5-45b4-804f-0ea9a4936dda (the first run from ~/projects/vedabase)
agentRuns:    no workflow; three pinned Codex adversarial reviews (gpt-6-astra): main...unicode/converter, then each fix (9b303ab..5a4124e, 5a4124e..621cdbd)
branch:       main (pushed); unicode/converter (LOCAL, unpushed: see below)
commits:      29709be.. on main (this brief's own commit last); main..unicode/converter on the local branch
visibility:   public since 2026-10-20
tests:        on the branch tip: tests/unicode.sh 198 checks, mac-sim.sh 16; linux-e2e.sh 40 (browser checks included) on 9b303ab, before the two fixes; static checks clean
supersedes:   the 2026-10-26-1925 brief's "Highest-value work" 1 and 2 (done or decided); HANDOFF.md Open A, B, D (updated in place)
---

# The Unicode converter waits for the devotee's yes

## Where things stand

`main` is pushed and in sync with GitHub. The converter the maintainer chose
(all three installers) is built and tested on the branch `unicode/converter`, but
for its lock (below),
which exists only in journel's clone: it carries the 31-letter table, which
enters this public repository only once the devotee who shares the installers
agrees. A bundle of it sits beside the private notes in the archive. State:
`HANDOFF.md`.

## Read first

1. The memory for this folder (its `MEMORY.md`), above all the correspondence
   with the devotee: it lists the questions waiting for him.
2. `HANDOFF.md`: State (2026-10-26, this session), then Open A, B, F.
3. On the branch: `docs/how-it-works.md`, "Text copied out of VedaBase".

## Highest-value work

1. **The converter's lock, then the merge.** The third Codex review found the
   hand-made lock in `bin/vedabase-unicode` still unsound: a reclaim can delete a
   fresh lock, a killed reclaimer strands `.reclaim` for good, and after a crash
   and reboot a stale PID can belong to another live process, so every press says
   busy (`~/.cache` survives reboots). Proposal: on Linux an OS lock (`flock -w 5`
   on a file; util-linux is always there), released when the process dies; on the
   Mac, where LaunchServices runs one copy of an app at a time, the `mkdir` lock
   kept in `$TMPDIR`, which a restart clears, with dead owners removed. Test both
   paths (the Mac one under bash 3.2 with `uname`, `pbpaste` and `pbcopy`
   stand-ins). Then, once the devotee agrees to the table: `tests/unicode.sh`
   (with `VB_TEST_BASH32` and `VB_TEST_PWSH`), `linux-e2e.sh`, `mac-sim.sh`, a
   Codex review of the new lock, merge into `main`, push.
   First because it is done but for his yes, and the README's "What's next"
   has promised it.
2. **Copying text out of Folio under Wine** (HANDOFF.md, Open F): in the
   browser viewer it reached the X clipboard once in five sessions. Find out
   whether a Linux desktop with a window manager does better, and why Wine's
   selection never shows on the X side. Second because without it the
   converter has nothing to convert on Linux and, likely, the Mac.
3. **Windows:** the checks still open (HANDOFF.md, State), now with check 8,
   VedaBase Unicode, in `docs/testing.md`.
4. **A real Mac run**, then Open C and the rest.

## Hard rules

- Never commit the VedaBase files or anything an install produced.
- Push nothing derived from the devotee's five files (the table, his examples)
  until he and the maintainer agree; `unicode/converter` stays local until then.
- Never test against journel's live install (`/journel/s0/$USER/vedabase`).
- One verifier per question, never one per finding (harness ADR 0001); Codex
  review on diffs that matter.
- Every commit carries a `Fix:`/`Docs:`/`Chore:`/`Test:` or `Decided:` trailer.
- This repository is public: name roles, and put private context in the memory
  for this folder.

## Traps from this session

- **bash 3.2's `${var//x/y}` is quadratic.** A first converter built on it did
  not finish 260 KB in 300 seconds; sed does it at once. AGENTS.md now says so.
- **A `grep` count of 0 can be a broken pattern.** `grep -c $'[\x80-\xff]'`
  reported no non-ASCII bytes in a file full of them; `tr -d '\000-\177' | wc -c`
  told the truth. Likewise `cut -c` cuts bytes: it split a UTF-8 letter in a
  test description and made the whole log look binary to `grep`.
- **Windows PowerShell 5.1 reads a script without a BOM as ANSI**, so the
  converter's script is plain ASCII; PowerShell 7 on Linux never shows this.
- **Headless Chromium's Ctrl+C through noVNC did not reach Folio**; `xdotool
  key ctrl+c` on the display did. Neither made Wine's copy reach X reliably.
