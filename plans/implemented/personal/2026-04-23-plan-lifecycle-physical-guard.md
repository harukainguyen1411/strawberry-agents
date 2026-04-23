---
owner: karma
complexity: quick
tests_required: true
orianna_gate_version: 2
status: implemented
created: 2026-04-23
updated: 2026-04-23
concern: personal
---

# Plan-lifecycle physical guard (PreToolUse)

## Context

Today's Ekko subagent (session ending in commits `8717331` "chore: promote 2026-04-21-pre-lint-rename-aware.md to approved" and `a802de4` Ekko memory/learnings) was briefed to promote a plan from `plans/proposed/` to `plans/approved/`. Because `scripts/plan-promote.sh` is archived (v1, unusable under the v2 Orianna regime), Ekko improvised: it sourced `agents/orianna/memory/git-identity.sh`, switched the committing git author to Orianna's identity, ran a raw `git mv plans/proposed/... plans/approved/...`, and committed. The existing commit-phase guard (`scripts/hooks/pre-commit-plan-promote-guard.sh`) inspected `author == Orianna` and the Orianna trailer and accepted the commit. Net effect: a non-Orianna agent physically moved a plan across a lifecycle boundary, and the v2 commit gate could not distinguish the impersonation. <!-- orianna: ok -- directory/glob path tokens, not files -->

Duong's stated principle: "Basically only Orianna can PHYSICALLY move plan. Any other agent can attempt to do that but it should not be possible. We don't need a git or commit gate because they should not be able to move plan anyway." The commit-phase guard is the wrong layer — by the time the filesystem move has already happened, the race is lost and identity is cheaply spoofable. The correct layer is Claude Code's PreToolUse hook chain, which fires before the tool executes and can reject by exit code 2. The PreToolUse hook replaces the commit-phase gates entirely; the v2 commit-phase plan-promote guards are archived as part of this plan — one layer, one responsibility.

This plan introduces a single PreToolUse guard script that dispatches on tool name — handling `Bash` (parses the command string for mv/cp/rm targeting protected paths) and `Write`/`Edit`/`NotebookEdit` (inspects `tool_input.file_path`/`notebook_path`) in one file. `.claude/settings.json` registers two matcher entries (one for `Bash`, one for `Write|Edit|NotebookEdit`), both pointing at the same script — single source of truth, no second file to drift. The guard rejects when the calling agent's identity env var is not `orianna`, case-insensitive. `plans/proposed/**` remains freely writable so any author (Karma, Swain, Azir, etc.) can create new plans there; only moves/edits INTO or WITHIN `plans/approved/`, `plans/in-progress/`, `plans/implemented/`, `plans/archived/` are gated. <!-- orianna: ok -- directory/glob path tokens, not files -->

## Decision

Add a unified PreToolUse guard:

1. `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` <!-- orianna: ok -- prospective path, created by this plan --> — single script, dispatches on `.tool_name` from the hook JSON. For `Bash`, extracts `.tool_input.command` and pattern-matches against `git mv`, `mv`, `cp`, `rm` operations whose source OR destination resolves under a protected plan-lifecycle path. For `Write`/`Edit`/`NotebookEdit`, extracts `.tool_input.file_path // .tool_input.notebook_path` and checks against protected roots. Shared tail: if a protected path is involved AND `$CLAUDE_AGENT_NAME` / `$STRAWBERRY_AGENT` (case-insensitive) is not `orianna`, exits 2 with the standard error message. Fail-closed: if neither env var is set, treated as non-Orianna and rejected. `.claude/settings.json` registers TWO matcher entries (`Bash` and `Write|Edit|NotebookEdit`) both pointing at this same script — one source of truth, no second file to drift.

Protected roots (normalized repo-relative):
- `plans/approved/` <!-- orianna: ok -- directory/glob path tokens, not files -->
- `plans/in-progress/` <!-- orianna: ok -- directory/glob path tokens, not files -->
- `plans/implemented/` <!-- orianna: ok -- directory/glob path tokens, not files -->
- `plans/archived/` <!-- orianna: ok -- directory/glob path tokens, not files -->

Unprotected (any agent may author/edit here):
- `plans/proposed/` and subtrees `plans/proposed/personal/`, `plans/proposed/work/` <!-- orianna: ok -- directory/glob path tokens, not files -->

Rejection message (stderr, exit 2):

```
[plan-lifecycle-guard] Agent '<name>' cannot move/modify files in <path>.
Plan lifecycle moves are reserved to the Orianna agent.
Dispatch Orianna via Agent(subagent_type='orianna') instead.
```

The v2 commit-phase gates (`pre-commit-plan-promote-guard.sh`, `commit-msg-plan-promote-guard.sh`) are archived to `scripts/hooks/_archive/v2-commit-phase-plan-guards/` by this plan. Rationale: at the commit layer, identity is cheaply spoofable; the physical-prevention layer obsoletes the need for a backup check. <!-- orianna: ok -- paths archived by this plan -->

Detection is intentionally post-hoc — it logs loudly, never blocks. A blocking audit would re-introduce a second layer that could be spoofed; the single-gate principle (Duong 2026-04-23) rejects that shape. If the PreToolUse hook somehow fails to prevent a move, we let the bypass through, detect it after the fact via T7's audit, and fix the gate — we do not paper over a broken gate with a secondary block that could itself be spoofed into looking green.

## Tasks

- **T1 — write unified PreToolUse guard.** kind: impl. estimate_minutes: 30. Files: `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` (new). <!-- orianna: ok -- prospective path, created by this plan --> Detail: POSIX-portable bash; read stdin JSON with `jq`; branch on `.tool_name`. For `Bash`: extract `.tool_input.command`, normalize whitespace, detect `git mv`, bare `mv`, `cp` (incl. `-R`/`-r`), `rm` (incl. `-rf`) where any token resolves under a protected root. For `Write` / `Edit` / `NotebookEdit`: extract `.tool_input.file_path // .tool_input.notebook_path`, resolve to repo-relative, check against protected roots. Shared tail: read `$CLAUDE_AGENT_NAME` then `$STRAWBERRY_AGENT`; lowercase-compare against `orianna`; on mismatch print standard error to stderr and exit 2; otherwise exit 0. Fail-closed when neither env var is set. DoD: shellcheck clean; single file handles all four tool names via dispatch; unit-test harness in `scripts/hooks/tests/` exercises both JSON input shapes (Bash command vs file_path) and the identity branch.

- **T2 — wire hook into settings.json.** kind: impl. estimate_minutes: 10. Files: `.claude/settings.json`. Detail: append to existing `PreToolUse` array — a new `Bash` matcher entry calling T1 (keep existing `gh-auth-guard.sh` entry; order: gh-auth-guard first, plan-lifecycle-guard second) and a new `Write|Edit|NotebookEdit` matcher entry also calling T1. Preserve existing `Agent` matcher. DoD: JSON parses; both matcher entries point at the same script `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` — single source of truth, no second file to drift; both hooks fire on the respective tool invocations. <!-- orianna: ok -- archived/bare-filename path, not at repo root -->

- **T3 — archive commit-phase plan-promote guards.** kind: refactor. estimate_minutes: 15. Files: `scripts/hooks/pre-commit-plan-promote-guard.sh` (move), `scripts/hooks/commit-msg-plan-promote-guard.sh` (move), `scripts/install-hooks.sh` (update), `scripts/hooks/test-plan-promote-guard.sh` (move), `scripts/hooks/test-commit-msg-plan-promote-guard.sh` (move). Destination: `scripts/hooks/_archive/v2-commit-phase-plan-guards/`. <!-- orianna: ok -- prospective path, created by this plan --> Detail: `git mv` all four files to the archive directory; update `scripts/install-hooks.sh` to drop the `commit-msg-plan-promote-guard.sh` symlink installation and the plan-promote pre-commit entry; grep the tree to confirm no remaining references to the archived script names outside `_archive/`. DoD: new archive path exists; `scripts/install-hooks.sh` does not reference the archived names; pre-existing `scripts/hooks/test-hooks.sh` runs clean.

- **T4 — xfail tests for guard behavior.** kind: test. estimate_minutes: 25. Files: `scripts/hooks/tests/test-pretooluse-plan-lifecycle-guard.sh` (new). <!-- orianna: ok -- prospective path, created by this plan --> Detail: drive the single guard script directly by piping hand-crafted JSON payloads of two different shapes (Bash tool_input.command vs Write/Edit/NotebookEdit tool_input.file_path). Cases — (a) Bash `git mv plans/proposed/x.md plans/approved/x.md` with `CLAUDE_AGENT_NAME=ekko` -> exit 2; (b) same with `CLAUDE_AGENT_NAME=orianna` -> exit 0; (c) Write with `file_path=plans/approved/new.md`, agent=karma -> exit 2; (d) Write with `file_path=plans/proposed/personal/new.md`, agent=karma -> exit 0; (e) no identity env var set -> exit 2 (fail-closed); (f) Bash `rm -rf plans/in-progress/foo/` agent=ekko -> exit 2. Registered in `scripts/hooks/test-hooks.sh`. DoD: all six cases pass; xfail-first commit lands before T1 implementation per Rule 12.

- **T5 — documentation updates.** kind: docs. estimate_minutes: 15. Files: `architecture/plan-lifecycle.md`, `CLAUDE.md`. Detail: in `architecture/plan-lifecycle.md` add a "Physical enforcement" subsection describing the PreToolUse guard as the sole enforcement mechanism and noting the archival of the v2 commit-phase guards. In `CLAUDE.md` Rule 7, append a sentence: "Non-Orianna agents are physically blocked from moving/modifying files under `plans/approved/`, `plans/in-progress/`, `plans/implemented/`, `plans/archived/` by the PreToolUse plan-lifecycle guard." DoD: both files updated; plan-structure hook clean. <!-- orianna: ok -- directory/glob path tokens, not files -->

- **T6 — integration test of Orianna-dispatch flow.** kind: test. estimate_minutes: 20. Files: `scripts/hooks/tests/test-pretooluse-plan-lifecycle-integration.sh` (new). <!-- orianna: ok -- prospective path, created by this plan --> Detail: end-to-end simulation — set `CLAUDE_AGENT_NAME=karma`, create a fake plan under `plans/proposed/personal/` via the Write-shaped payload (must succeed), attempt `git mv` to `plans/approved/` via the Bash-shaped payload (must fail), then with `CLAUDE_AGENT_NAME=orianna` re-run the `git mv` payload (must succeed). Assertions use exit codes only — no actual filesystem mutation required inside the test. DoD: single run exits 0; integrated into `scripts/hooks/test-hooks.sh`.

- **T7 — bypass-detection audit.** kind: impl. estimate_minutes: 25. Files: `scripts/orianna-bypass-audit.sh` (new). <!-- orianna: ok -- prospective path, created by this plan --> Detail: POSIX-portable bash script that (1) walks `plans/approved/`, `plans/in-progress/`, `plans/implemented/`, `plans/archived/` (recursive into `personal/` and `work/` subtrees); (2) for each plan file runs `git log --follow --format='%H|%ae|%s' --diff-filter=AR -- <path>` to get the commit that introduced the file at its current lifecycle location; (3) checks that the most recent commit moving the file into a protected lifecycle path was authored by the canonical Orianna identity (sourced from `agents/orianna/memory/git-identity.sh`); (4) reports orphan files (arrived via non-Orianna commit) to stdout with commit SHA, author email, and plan path; (5) never blocks, never auto-fixes, never reverts — exit 0 always (finding count may be mirrored as an advisory number only if it does not cause CI to fail; this is detection, not enforcement); (6) runs in ≤5s on a full clone. Script header MUST document the gotcha: audit is only as strong as `git log` author metadata — an agent that impersonated Orianna's git identity (the exact Ekko incident shape) will appear as Orianna in the audit and pass. The audit catches the broader class where bypass didn't bother to spoof identity; identity-spoofing bypasses are the reason the PreToolUse hook is the sole prevention layer. DoD: shellcheck clean; running against current main produces a report (listing any genuinely non-Orianna-authored protected-path plans); cron-able invocation pattern documented in this plan's References. Non-blocking by design — this is NOT a second gate.

## Test plan

Invariants protected by T4 + T6 + T7:

- **INV-1** — `git mv plans/proposed/x.md plans/approved/x.md` invoked with `CLAUDE_AGENT_NAME=ekko` is rejected (exit 2) by T1's Bash dispatch branch. Protects the exact incident from commits `8717331`/`a802de4`.
- **INV-2** — the same `git mv` invoked with `CLAUDE_AGENT_NAME=orianna` is allowed (exit 0). Protects Orianna's legitimate promotion path.
- **INV-3** — `Write` with `file_path` under `plans/approved/`, `plans/in-progress/`, `plans/implemented/`, or `plans/archived/` from any non-Orianna agent is rejected by T1's Write/Edit/NotebookEdit dispatch branch. Closes the "write-new-file-into-approved" back door (no move required). <!-- orianna: ok -- directory/glob path tokens, not files -->
- **INV-4** — `Write` with `file_path` under `plans/proposed/personal/` or `plans/proposed/work/` from a non-Orianna agent (e.g. Karma authoring this very plan) is allowed. Preserves the authoring-freely invariant for `proposed/`. <!-- orianna: ok -- directory/glob path tokens, not files -->
- **INV-5 (fail-closed)** — when neither `CLAUDE_AGENT_NAME` nor `STRAWBERRY_AGENT` is set, the guard rejects on protected paths regardless of tool name. Prevents "unset the env var" as a bypass.
- **INV-6 (clean replacement)** — after this plan lands, the archived commit-phase guards are not installed by `scripts/install-hooks.sh`; a fresh `install-hooks.sh` run on a clean clone does not create `.git/hooks/commit-msg` referencing the archived guard, and `.git/hooks/pre-commit` contains no entry for the archived plan-promote guard. Verified by dry-run mode or direct file inspection of the generated hook scripts. <!-- orianna: ok -- bare filename alias for scripts/install-hooks.sh -->
- **INV-7 (bypass detection)** — given a test-fixture plan file committed into `plans/approved/` by a non-Orianna identity (e.g. `duongntd99`), `scripts/orianna-bypass-audit.sh` reports that file as a bypass orphan (stdout line containing the commit SHA, author email, and plan path) and exits 0. Covered by a fresh unit test `scripts/tests/test-orianna-bypass-audit.sh` (new). <!-- orianna: ok -- prospective path, created by this plan --> xfail-first per Rule 12.

All tests are xfail-first (Rule 12) — the test commit lands on the task branch before any implementation commit for T1/T7.

## Open questions

- None blocking. If Claude Code surfaces additional filesystem-mutation tool names in future, the `Write|Edit|NotebookEdit` matcher list in T2 will need to be extended and the dispatch branch in T1's script will need a new case; leaving this as a maintenance note rather than a task.

## References

- Incident commits: `8717331` (Ekko promotion as Orianna-identity), `a802de4` (Ekko memory follow-up).
- Archived by this plan: `scripts/hooks/pre-commit-plan-promote-guard.sh`, `scripts/hooks/commit-msg-plan-promote-guard.sh` → `scripts/hooks/_archive/v2-commit-phase-plan-guards/`. <!-- orianna: ok -- paths archived by this plan -->
- Archived v1 promote helper: `scripts/plan-promote.sh` (archived — do not revive in this plan). <!-- orianna: ok -- archived/bare-filename path, not at repo root -->
- Universal invariants: `CLAUDE.md` Rules 7, 12, 19.
- Lifecycle doc to update: `architecture/plan-lifecycle.md`.
- Bypass-detection audit — `scripts/orianna-bypass-audit.sh` (post-hoc, non-blocking). Suggested cron wiring: nightly CI job (`.github/workflows/`) that runs the script and posts findings to a reporting channel without failing the build; local invocation `bash scripts/orianna-bypass-audit.sh` from repo root. Single-gate principle (Duong 2026-04-23): prevention is the PreToolUse hook; detection is this audit; they are separate layers with separate responsibilities, and the audit never blocks. <!-- orianna: ok -- directory glob reference, not a file path -->
- Follow-up plan: filesystem-layer ACLs (chflags/chattr) or dedicated PlanMove tool (allowlist) to close entire bypass family. B8–B10 + any future AST gaps to be addressed under that plan. Filed as future work, not this PR. (Senna structural recommendation, 2026-04-23.)

---

<!-- orianna: approved 2026-04-23 -->

## Orianna approval record

- **verdict:** APPROVE
- **reviewed-by:** Orianna (fact-checker gate)
- **date:** 2026-04-23
- **findings:** blocks: 0, warns: 0, infos: 0

All load-bearing claims confirmed against repo state:
- Incident commits `8717331` and `a802de4` exist and match the described behavior.
- `scripts/hooks/pre-commit-plan-promote-guard.sh` and `commit-msg-plan-promote-guard.sh` exist at the paths named in T3. <!-- orianna: ok -- paths archived by this plan -->
- `scripts/hooks/test-plan-promote-guard.sh` and `test-commit-msg-plan-promote-guard.sh` exist at the paths named in T3. <!-- orianna: ok -- paths archived by this plan -->
- `agents/orianna/memory/git-identity.sh` exists at the path referenced in T7.
- `.claude/settings.json` has a `PreToolUse` array with an existing `Bash` matcher (`gh-auth-guard.sh`); T2 wiring path is clear. <!-- orianna: ok -- archived/bare-filename path, not at repo root -->
- `architecture/plan-lifecycle.md` exists for T5 update.
- `scripts/hooks/test-hooks.sh` exists for test registration per T4/T6.
- `scripts/plan-promote.sh` is absent (correctly described as archived). <!-- orianna: ok -- archived/bare-filename path, not at repo root -->
- All new file paths carry `<!-- orianna: ok -- prospective path, created by this plan -->` markers; exempt from current-state verification per operating discipline.

---

<!-- orianna: promoted 2026-04-23 -->

## Orianna promotion record

- **verdict:** APPROVE — promoted to implemented
- **promoted-by:** Orianna
- **date:** 2026-04-23
- **evidence:** PR #31 merged at `34fed4b`, PR #32 follow-up at `fc96916`. 36/36 guard tests green. `scripts/orianna-bypass-audit.sh` and `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` confirmed present.
