# HANDOFF — the living state of the VedaBase installers

Corrected in place (old text struck through). The newest file in `docs/handoffs/` is the
latest session's brief; this file is what is true. It is for agents and Corey, not for the
devotees the installers go to: `.gitattributes` keeps it out of GitHub's "Download ZIP"
(a clone or a collaborator still sees it).

## What this is

- Installers for the Bhaktivedanta VedaBase desktop program (Folio Views 4.3, a 2003
  32-bit Windows program) with the VedaBase 25 and VaniBase 25 infobases, fetched from
  Ekanatha dāsa's public Google Drive folders and checked by SHA-256
  (`manifest/drive-files.tsv`): Linux and WSL (portable Wine 11.0, unattended), macOS
  (Gcenx Wine 11.0_1; the user clicks the wizard) and Windows 10/11 (native,
  PowerShell 5.1).
- Corey asked for it on 2026-10-19, after Tāraka dāsa offered him the program. Corey
  will give the repository and its documentation to Tāraka, who shares it with other
  devotees, many of them not technical. `README.md` and `docs/` are written for them.
- Never commit the program, the infobases, the fonts or anything an install produced
  (`.gitignore`). They belong to the Bhaktivedanta Archives and the BBT; the 2003
  licence allows one host computer and one user at a time plus an archival copy, and
  forbids "on-line system" use (`docs/how-it-works.md`, "The license you accept").

## State (2026-10-20)

- `main` holds `5e1dd70..6942798`, pushed to the private GitHub repository
  `Zanzagar/vedabase`.
- **Linux and WSL**, tested on Ubuntu 24.04 (journel): three clean unattended installs
  with `vedabase doctor` passing; VedaBase and VaniBase open with correct diacritics;
  search works; `vedabase web` works end to end, typing included; a `--no-vanibase`
  install on 6942798's code. Not tried: a real WSL2, Debian 12, a desktop session.
- **macOS**, simulated only: `mac/install.sh` ran to completion under a real bash
  3.2.57 with `uname`, `sw_vers`, `open` and `sips` shimmed and Linux Wine standing in
  for Gcenx Wine (all 15 wizard screens, VaniBase, both app bundles, exit 0), last on
  6942798's code. Never run on a Mac.
- **Windows**: parsed by PowerShell 7 on Linux, and its pure-logic functions
  unit-tested; PowerShell 7.6 crashes under Wine, so the script has never run. Never
  run on Windows. Atman, Corey's Windows PC, can test it with `docs/testing.md`.
- **journel's own install**: home `/journel/s0/cjh5690/vedabase` (the NFS home has a
  40 GiB quota), launcher `~/.local/bin/vedabase`, and `~/.config/vedabase/home`
  remembers the home. A from-scratch reinstall needs
  `./install.sh --home /journel/s0/cjh5690/vedabase`. Run `vedabase doctor` before
  assuming it is broken. Never test against it: use a scratch `--home`.
- **Archive** on journel: `/journel/s1/cjh5690/archive/vedabase/` holds the Drive files
  (with Tāraka's `VedaBase_CrossOver_Installation.pdf` and Ekanatha's `README.docx`), a
  backup of the working prefix, and both Wine builds.
- **Review**: workflow `wf_efcb88f5-f2e` reviewed the repository through five lenses
  (Linux, Windows, macOS, security, docs), 68 findings, one verifier per finding. That
  is more verifiers than harness ADR 0001 allows; later runs follow it. Commit 6942798
  acted on the raw findings while the verifiers were still running, so a REFUTED verdict
  can mean "already fixed" rather than "never real".

## Open, in order

1. Triage the review's 68 verdicts against `HEAD`; fix what is still open, using each
   verdict's `better_fix`.
2. Codex adversarial review of `58fcf94..HEAD`; fix what it confirms.
3. After any change, the test battery: ShellCheck, `bash -n`, a PowerShell parse, the
   bash 3.2 Mac simulation, and one clean unattended Linux install into a scratch
   `--home`.
4. Adopt the claude-harness standard (AGENTS.md, CLAUDE.md, the grilling gate,
   `.claude/settings.json`, `docs/handoffs/`), recorded in the harness adoption matrix.
5. Fit to send: no journel or account details in what devotees read; a cover note for
   Corey to send Tāraka.
6. **Corey decides how to share it.** The repository is private, so the README's
   "Code → Download ZIP" and `git clone` fail for anyone else. Options: make it public,
   send a ZIP, or add collaborators. It carries Ekanatha's Drive file IDs.
7. One real run each on Windows (Atman) and on a Mac, following `docs/testing.md`.

## Where the session records are

Both sessions so far ran from `~/projects`, not from this folder, so their transcripts are
under `~/.claude/projects/-home-cjh5690-projects/`: `7f53bfb5-c5f0-4cc2-ab2c-f894b3a323d4`
built everything (workflows `wf_f94b032d-525`, Wine research; `wf_fdb69b90-1be`,
cross-platform research; `wf_efcb88f5-f2e`, the review), and
`7dc8950f-ca3e-4233-be0f-553ad6a93b38` picked up after it ran out of context. The test
tools that session built (ShellCheck, bash 3.2.57, PowerShell 7 for Linux, the Mac
simulation) are in its `/tmp` scratch directory, which a reboot wipes.
