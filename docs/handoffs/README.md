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
| [2026-10-27 16:34 — the browser viewer's processes are found by what they are](2026-10-27-1634--the-browser-viewers-processes-are-found-by-what-they-are.md) | `68ae51a3` | NOTHING IN FLIGHT. Open 4's pid-file items held real bugs (`stop` could kill an unrelated process after a reboot): Xvnc and websockify are now found by their display's socket, one per display, kept while anything it names survives; `open`/`web`/`stop` run one at a time under `flock -o`. Five Codex reviews, the fifth approving; the whole suite passes on the merged code. Next: Windows and the Mac; Open H; È and the thanks, waiting on the devotee; check 8 under GNOME Shell. |
| [2026-10-27 01:05 — copies made in Folio reach the clipboard](2026-10-27-0105--copies-made-in-folio-reach-the-clipboard.md) | `4133d657` | NOTHING IN FLIGHT. Open F solved: Wine 11.0 sends its claim on the X clipboard only when an X event wakes it (fixed upstream in 11.14, not in the pinned 11.0); `vedabase unicode` nudges Wine before it reads, and the browser viewer runs a nudger the X server keeps single (a selection). Five Codex reviews, every finding fixed; the whole suite passes. Next: the converter on Windows and a real Mac; Open H (a Wine with the fix); È and the thanks, waiting on the devotee. |
| [2026-10-26 22:15 — the Unicode converter is published](2026-10-26-2215--the-unicode-converter-is-published.md) | `39638aaf` | NOTHING IN FLIGHT. VedaBase Unicode is on `main` in all three installers (lock: flock on Linux, a mutex on Windows, none on the Mac), after four Codex reviews; the thanks to Ekanatha is worded (provisional). Next: Folio's copy under Wine (Open F), the converter on Windows and a real Mac, È (Open G). |
| [2026-10-26 21:46 — the Unicode converter waits for the devotee](2026-10-26-2146--the-unicode-converter-waits-for-the-devotee.md) | `39638aaf` | NOTHING IN FLIGHT on `main`. The five files read (notes private). The maintainer chose a converter in all three installers: finished and tested on the LOCAL branch `unicode/converter`, unpushed until the devotee agrees to its table. Found: Folio's copy under Wine seldom reaches the X clipboard (Open F). Next: his yes, then merge; Open F; Windows and Mac runs. |
| [2026-10-26 19:25 — work moves to this folder; the Unicode files wait](2026-10-26-1925--work-moves-to-this-folder-and-the-unicode-files-wait.md) | `8f688260` | NOTHING IN FLIGHT. No code changed. Sessions now run from `~/projects/vedabase`; 7dc8950f archived. The devotee who shares the installers sent five files on converting VedaBase text to Unicode (archived, unread). Next: read them and settle with the maintainer what to build; the maintainer's call on the README's wording. |
| [2026-10-20 04:05 — the review is closed and the installers wait for Windows and Mac](2026-10-20-0405--the-review-is-closed-and-the-installers-wait-for-windows-and-mac.md) | `7dc8950f` | NOTHING IN FLIGHT. Review verdicts dispositioned, three Codex rounds acted on, `tests/` added and green, the launcher's 32-bit free-space refusal found and worked around, harness adopted, journel's install refreshed. Next: a real Windows run on Atman, a real Mac run, and Corey's sharing decision. |
