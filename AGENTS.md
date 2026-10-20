# AGENTS.md — VedaBase installers

Installers for the Bhaktivedanta VedaBase desktop program (Folio Views 4.3, with
the VedaBase 25 and VaniBase 25 infobases) on Linux and WSL, macOS, and Windows
10/11. Corey gives this repository to Tāraka dāsa, who shares it with devotees,
many of them not technical. `README.md` and `docs/` are written for them. This
file, `CLAUDE.md`, `HANDOFF.md`, `docs/handoffs/`, `.claude/`, `.githooks/` and
`.github/` are for agents and stay out of GitHub's "Download ZIP"
(`.gitattributes`, export-ignore).

## Ground truth

- **Never commit the VedaBase files.** The program, the infobases and the fonts
  belong to the Bhaktivedanta Archives and the BBT. The installers download
  them from Ekanatha dāsa's public Google Drive folders and check each against
  `manifest/drive-files.tsv` (size and SHA-256); `.gitignore` keeps them, and
  anything an install produced, out.
- **The 2003 licence** allows one host computer, one user at a time and an
  archival copy, and forbids "on-line system" use (`docs/how-it-works.md`,
  "The license you accept"). Write nothing that implies wider rights.
- **Say what was tested, no more.** Linux is tested end to end. macOS has run
  only as a simulation under bash 3.2. Windows has never run on Windows. The
  README and the docs must not claim more than that.

## Start here

Read the newest file in `docs/handoffs/`, then the living head of `HANDOFF.md`.
Correct a wrong instruction AT its line, in `HANDOFF.md` or in this file, with
the old text struck through: a handoff freezes when its session ends, so a
correction made only there never reaches the next reader.

## Testing

`tests/README.md` lists the suite and its settings. Run it after any change that
matters, with the static checks before every commit:

- **Static:** ShellCheck (`-x`, SC2034 aside: library variables look unused
  alone); `bash -n` with a real bash 3.2 for `lib/common.sh`, `lib/fetch.sh`,
  `lib/setup.sh`, `mac/install.sh` and `Install-VedaBase-Mac.command`; a
  PowerShell parse of `windows/install-vedabase.ps1`. The bash 3.2, ShellCheck
  and PowerShell builds used on 2026-10-20 are archived in
  `/journel/s1/cjh5690/archive/vedabase/session-7f53bfb5-2026-10-19/scratchpad/`
  (`bash32/`, `sc/`, `pwsh/`).
- **`tests/linux-e2e.sh`, `tests/interrupt.sh`, `tests/rollback.sh`,
  `tests/mac-sim.sh`:** scratch installs with `HOME` and `XDG_*` redirected, so
  the real launcher and `~/.config/vedabase` are never touched (each test checks
  that). On journel, `VB_TEST_SOURCE=/journel/s1/cjh5690/archive/vedabase/drive-files-2026-10-19`
  avoids Google Drive's download limits, and `VB_TEST_WORK` belongs on
  `/journel/s1`, which has room.
- `tests/mac-sim.sh` proves the shell logic, not macOS; nothing here runs the
  Windows installer: only a real Windows PC can (`docs/testing.md`).
- **journel's own install** (`/journel/s0/cjh5690/vedabase`, launcher
  `~/.local/bin/vedabase`) is Corey's working copy. Never test against it.

## Pitfalls this code has already hit

- Shared code runs under macOS's bash 3.2 and BSD tools: no GNU-only flags, no
  bash 4 features.
- Under `set -euo pipefail`, an assignment from a pipeline that can fail ends
  the script without a word: guard it (`|| true`, `|| x=''`). Do not test
  `cmd | grep -q` where the writer can die of SIGPIPE; read into a variable.
- Every account on a shared server can read command lines and connect to
  localhost ports. Keep `-rfbport -1`, the 0600 unix sockets, the X cookie fed
  on stdin and `-displayfd`; never put a secret in argv.
- A step that can lose the user's notes (the `.sdw` shadow files) needs a test
  that proves they survive; a restore must be checked in staging before the old
  prefix is touched (`tests/rollback.sh`, the damaged backups in `linux-e2e.sh`).
- Install.exe's launcher checks free space in 32-bit arithmetic: the installers
  write a filler when the free space sits just above a multiple of 4 GiB. Do not
  remove it as dead code.

## Multi-agent runs

Harness ADR 0001 (`~/projects/claude-harness/docs/adr/0001-verification-precedence.md`,
as restored on the evening of 2026-10-12): Pocock's skills are the default
spine; Codex review checks every diff that matters; a fan-out wave is the last
resort after both, ONE wave at a time, never concurrent. A wave may ask any
number of questions, with ONE verifier per question on its top-ranked claim
(never one per claim; the entry point gets its own, first); every other claim
is returned as unverified, never relayed as fact, and re-checked against the
source by whoever acts on it. Before launching one, say in the reply what it
will spawn; `Workflow` is in `permissions.ask`, so Corey approves each launch.
Count started against returned afterwards: a run whose verifiers died is
UNVERIFIED, never "0 findings". Verifiers write nothing. The review of
2026-10-19/20 (`wf_efcb88f5-f2e`, five lenses, one verifier per finding: 68)
ran before this file existed; do not repeat its shape.

**Every agent runs the session's own model.** No `model:` override to a
cheaper tier, in a Workflow script or an Agent call, unless Corey explicitly
asks for one.

## If you are a subagent

- Write only the files your brief assigns.
- Run no state-mutating git (commit, checkout, reset, stash, branch, push):
  the main session owns commits.
- Treat every fact in your brief as a hypothesis, counts and quoted file
  contents included. A premise that turns out wrong is a finding that outranks
  the task: report it first.
- Re-derive every number you report and hand over its source (file:line or
  the command), not just the conclusion.

## Code review (Codex)

`/adversarial-review [--base <ref>] [--scope working-tree|branch] [focus]`:
flag-only and on demand; its model is pinned in
`~/.claude/commands/adversarial-review.md`, and the plugin stays unedited. Use
it on diffs that matter here: anything that can lose notes or delete files,
the elevated Windows phase, and what other accounts on a shared server can
reach. Its findings are claims to verify before acting on them. The stop-time
review gate stays disabled.

## Git and GitHub

- Follow claude-harness `docs/git-hygiene.md`, the floor: commit as work
  completes and push after every commit, `main` included; take a
  `<track>/<subject>` branch when work might be abandoned or wants Codex review
  first; keep published history recoverable (no force-push, no deleting
  `main`, no rewriting pushed commits; `git revert` fixes a goof). Stage
  explicit paths and check `git status --porcelain` before each commit.
  `.claude/settings.json` carries the deny/ask rules.
- **The repository is public** since 2026-10-20, so that Tāraka dāsa can see it;
  Corey will make it private again (and share it with Tāraka's GitHub account)
  or remove it at Tāraka's request. Write nothing in it that should not be
  public, and keep the agent and test files export-ignored.
- **Grilling gate:** every commit ends with a `Decided: <path>#<anchor>` trailer (the recorded decision it implements) or a `Fix:`/`Docs:`/`Chore:`/`Test:` trailer saying why; rule 14 of claude-harness `docs/git-hygiene.md`. `.githooks/commit-msg` refuses anything else once a clone has run `git config core.hooksPath .githooks` (once per clone), and `.github/workflows/grill-gate.yml` re-checks every new commit, and a pull request's description, in CI. <!-- grill-gate:pointer -->
