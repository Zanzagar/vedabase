# Session handoffs

A handoff is the brief for one session: what to do next, in what order, and
what not to do. A new session starts with one sentence — *read the latest
handoff in `docs/handoffs/` and proceed* — instead of pasted context that goes
stale. Conventions from the Swords & Sandals II repository, as Tanks adopted
them.

## Naming

```
docs/handoffs/YYYY-MM-DD-HHMM--short-slug.md
```

Local date and time when the handoff was written (the end of its session),
then a slug naming what the session was about. No colons (Windows forbids
them). The names sort chronologically, so the newest is last.

## Frontmatter

```yaml
---
handoff:      2026-10-20-0300--example-slug
written:      2026-10-20 03:00 -0400
sessionStart: 2026-10-20 01:42 -0400
sessionId:    <the Claude Code session id>
agentRuns:    wf_xxxxxxxx-xxx (what it ran), ...
branch:       main
commits:      <first>..<last>
tests:        what ran, and what it showed
supersedes:   none
---
```

- `sessionId` and `agentRuns` make every subagent's brief and answer
  recoverable: transcripts live under
  `~/.claude/projects/<working directory, with / replaced by ->/<sessionId>/subagents/workflows/<runId>/`.
  Derive that path from the working directory; never copy it literally.
- `commits` is a RANGE: a tip written in the body is wrong by construction,
  because the handoff's own commit comes after it.

## The two documents

| | `HANDOFF.md` (repository root) | `docs/handoffs/<stamp>--<slug>.md` |
| --- | --- | --- |
| What it is | the project's living state | one session's brief |
| Answers | what is true, what was found | what to do now |
| Lifetime | corrected in place | frozen when its session ends |

A handoff points at `HANDOFF.md` for state and does not restate it. If they
disagree, `HANDOFF.md` is right: the handoff froze earlier. A correction goes
AT the wrong line in `HANDOFF.md` (old text struck through) and is named in
the next handoff's `supersedes:`.

## Shape of a handoff

1. **Where things stand**: branch, remote, what was tested. Two or three lines.
2. **Read first**, in order.
3. **Highest-value work**, ranked, with the reason for each rank.
4. **Hard rules**, verbatim.
5. **Traps from this session**: concrete, ideally the author's own mistakes.

## Index — newest first

| Handoff | Session | One line |
| --- | --- | --- |
| [2026-10-26 21:46 — the Unicode converter waits for the devotee](2026-10-26-2146--the-unicode-converter-waits-for-the-devotee.md) | `39638aaf` | NOTHING IN FLIGHT on `main`. The five files read (notes private). The maintainer chose a converter in all three installers: finished and tested on the LOCAL branch `unicode/converter`, unpushed until the devotee agrees to its table. Found: Folio's copy under Wine seldom reaches the X clipboard (Open F). Next: his yes, then merge; Open F; Windows and Mac runs. |
| [2026-10-26 19:25 — work moves to this folder; the Unicode files wait](2026-10-26-1925--work-moves-to-this-folder-and-the-unicode-files-wait.md) | `8f688260` | NOTHING IN FLIGHT. No code changed. Sessions now run from `~/projects/vedabase`; 7dc8950f archived. The devotee who shares the installers sent five files on converting VedaBase text to Unicode (archived, unread). Next: read them and settle with the maintainer what to build; the maintainer's call on the README's wording. |
| [2026-10-20 04:05 — the review is closed and the installers wait for Windows and Mac](2026-10-20-0405--the-review-is-closed-and-the-installers-wait-for-windows-and-mac.md) | `7dc8950f` | NOTHING IN FLIGHT. Review verdicts dispositioned, three Codex rounds acted on, `tests/` added and green, the launcher's 32-bit free-space refusal found and worked around, harness adopted, journel's install refreshed. Next: a real Windows run on Atman, a real Mac run, and Corey's sharing decision. |
