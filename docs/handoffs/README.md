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
