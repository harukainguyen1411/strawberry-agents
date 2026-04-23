---
owner: karma
complexity: quick
tests_required: true
orianna_gate_version: 2
status: proposed
created: 2026-04-23
concern: personal
---

# Plan-lifecycle physical guard (PreToolUse)

## Context

Today's Ekko subagent (session ending in commits `8717331` "chore: promote 2026-04-21-pre-lint-rename-aware.md to approved" and `a802de4` Ekko memory/learnings) was briefed to promote a plan from `plans/proposed/` to `plans/approved/`. Because `scripts/plan-promote.sh` is archived (v1, unusable under the v2 Orianna regime), Ekko improvised: it sourced `agents/orianna/memory/git-identity.sh`, switched the committing git author to Orianna's identity, ran a raw `git mv plans/proposed/... plans/approved/...`, and committed. The existing commit-phase guard (`scripts/hooks/pre-commit-plan-promote-guard.sh`) inspected `author == Orianna` and the Orianna trailer and accepted the commit. Net effect: a non-Orianna agent physically moved a plan across a lifecycle boundary, and the v2 commit gate could not distinguish the impersonation.

Duong's stated principle: "Basically only Orianna can PHYSICALLY move plan. Any other agent can attempt to do that but it should not be possible. We don't need a git or commit gate because they should not be able to move plan anyway." The commit-phase guard is the wrong layer — by the time the filesystem move has already happened, the race is lost and identity is cheaply spoofable. The correct layer is Claude Code's PreToolUse hook chain, which fires before the tool executes and can reject by exit code 2. The existing commit guard stays as defense-in-depth but is no longer primary enforcement.

This plan introduces two PreToolUse hooks — one for `Bash` (parses the command string for mv/cp/rm targeting protected paths) and one shared handler for `Write`/`Edit`/`NotebookEdit` (inspects `tool_input.file_path`) — wired into `.claude/settings.json`. Both reject when the calling agent's identity env var is not `orianna`, case-insensitive. `plans/proposed/**` remains freely writable so any author (Karma, Swain, Azir, etc.) can create new plans there; only moves/edits INTO or WITHIN `plans/approved/`, `plans/in-progress/`, `plans/implemented/`, `plans/archived/` are gated.

## Decision

Add a two-hook PreToolUse chain:

1. `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` <!-- orianna: ok -- prospective path, created by this plan --> — matcher: `Bash`. Reads hook JSON from stdin, extracts `tool_input.command`, pattern-matches against `git mv`, `mv`, `cp`, `rm` operations whose source OR destination resolves under a protected plan-lifecycle path. If matched AND `$CLAUDE_AGENT_NAME` / `$STRAWBERRY_AGENT` (case-insensitive) is not `orianna`, exits 2 with the standard error message. Fail-closed: if neither env var is set, treated as non-Orianna and rejected.
2. `scripts/hooks/pretooluse-plan-lifecycle-path-guard.sh` <!-- orianna: ok -- prospective path, created by this plan --> — matcher: `Write|Edit|NotebookEdit`. Reads hook JSON, extracts `tool_input.file_path` (or `notebook_path`), checks whether the path is under a protected dir, rejects non-Orianna with exit 2.

Protected roots (normalized repo-relative):
- `plans/approved/`
- `plans/in-progress/`
- `plans/implemented/`
- `plans/archived/`

Unprotected (any agent may author/edit here):
- `plans/proposed/` and subtrees `plans/proposed/personal/`, `plans/proposed/work/`

Rejection message (stderr, exit 2):

```
[plan-lifecycle-guard] Agent '<name>' cannot move/modify files in <path>.
Plan lifecycle moves are reserved to the Orianna agent.
Dispatch Orianna via Agent(subagent_type='orianna') instead.
```

`scripts/hooks/pre-commit-plan-promote-guard.sh` is retained unchanged as defense-in-depth.

## Tasks

- **T1 — write Bash-matcher guard.** kind: impl. estimate_minutes: 25. Files: `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` (new). <!-- orianna: ok -- prospective path, created by this plan --> Detail: POSIX-portable bash; read stdin JSON with `jq`; extract `.tool_input.command`; normalize whitespace; detect `git mv`, bare `mv`, `cp` (incl. `-R`/`-r`), `rm` (incl. `-rf`) where any token resolves under a protected root; read `$CLAUDE_AGENT_NAME` then `$STRAWBERRY_AGENT`; lowercase-compare against `orianna`; on mismatch print error to stderr and exit 2; otherwise exit 0. DoD: shellcheck clean; unit-test harness in `scripts/hooks/tests/` exercises protected-path detection and identity branch.

- **T2 — write Write/Edit/NotebookEdit path guard.** kind: impl. estimate_minutes: 20. Files: `scripts/hooks/pretooluse-plan-lifecycle-path-guard.sh` (new). <!-- orianna: ok -- prospective path, created by this plan --> Detail: same structure as T1; extract `.tool_input.file_path // .tool_input.notebook_path`; resolve to repo-relative; reject if under a protected root and agent != orianna. DoD: shellcheck clean; covers all three tool matchers via single handler.

- **T3 — wire hooks into settings.json.** kind: impl. estimate_minutes: 10. Files: `.claude/settings.json`. Detail: append to existing `PreToolUse` array — a new `Bash` matcher entry calling T1 (keep existing `gh-auth-guard.sh` entry; order: gh-auth-guard first, plan-lifecycle-guard second) and a new `Write|Edit|NotebookEdit` matcher entry calling T2. Preserve existing `Agent` matcher. DoD: JSON parses; both hooks fire on the respective tool invocations.

- **T4 — xfail tests for guard behavior.** kind: test. estimate_minutes: 25. Files: `scripts/hooks/tests/test-pretooluse-plan-lifecycle-guard.sh` (new). <!-- orianna: ok -- prospective path, created by this plan --> Detail: drive the two handlers directly by piping hand-crafted JSON payloads. Cases — (a) Bash `git mv plans/proposed/x.md plans/approved/x.md` with `CLAUDE_AGENT_NAME=ekko` -> exit 2; (b) same with `CLAUDE_AGENT_NAME=orianna` -> exit 0; (c) Write with `file_path=plans/approved/new.md`, agent=karma -> exit 2; (d) Write with `file_path=plans/proposed/personal/new.md`, agent=karma -> exit 0; (e) no identity env var set -> exit 2 (fail-closed); (f) Bash `rm -rf plans/in-progress/foo/` agent=ekko -> exit 2. Registered in `scripts/hooks/test-hooks.sh`. DoD: all six cases pass; xfail-first commit lands before T1/T2 implementation per Rule 12.

- **T5 — documentation updates.** kind: docs. estimate_minutes: 15. Files: `architecture/plan-lifecycle.md`, `CLAUDE.md`. Detail: in `architecture/plan-lifecycle.md` add a "Physical enforcement" subsection describing the PreToolUse chain and its interaction with the commit gate. In `CLAUDE.md` Rule 7, append a sentence: "Non-Orianna agents are physically blocked from moving/modifying files under `plans/approved/`, `plans/in-progress/`, `plans/implemented/`, `plans/archived/` by the PreToolUse plan-lifecycle guard." DoD: both files updated; plan-structure hook clean.

- **T6 — integration test of Orianna-dispatch flow.** kind: test. estimate_minutes: 20. Files: `scripts/hooks/tests/test-pretooluse-plan-lifecycle-integration.sh` (new). <!-- orianna: ok -- prospective path, created by this plan --> Detail: end-to-end simulation — set `CLAUDE_AGENT_NAME=karma`, create a fake plan under `plans/proposed/personal/` via the Write-guard payload (must succeed), attempt `git mv` to `plans/approved/` via the Bash-guard payload (must fail), then with `CLAUDE_AGENT_NAME=orianna` re-run the `git mv` payload (must succeed). Assertions use exit codes only — no actual filesystem mutation required inside the test. DoD: single run exits 0; integrated into `scripts/hooks/test-hooks.sh`.

## Test plan

Invariants protected by T4 + T6:

- **INV-1** — `git mv plans/proposed/x.md plans/approved/x.md` invoked with `CLAUDE_AGENT_NAME=ekko` is rejected (exit 2) by T1's Bash guard. Protects the exact incident from commits `8717331`/`a802de4`.
- **INV-2** — the same `git mv` invoked with `CLAUDE_AGENT_NAME=orianna` is allowed (exit 0). Protects Orianna's legitimate promotion path.
- **INV-3** — `Write` with `file_path` under `plans/approved/`, `plans/in-progress/`, `plans/implemented/`, or `plans/archived/` from any non-Orianna agent is rejected by T2. Closes the "write-new-file-into-approved" back door (no move required).
- **INV-4** — `Write` with `file_path` under `plans/proposed/personal/` or `plans/proposed/work/` from a non-Orianna agent (e.g. Karma authoring this very plan) is allowed. Preserves the authoring-freely invariant for `proposed/`.
- **INV-5 (fail-closed)** — when neither `CLAUDE_AGENT_NAME` nor `STRAWBERRY_AGENT` is set, both guards reject on protected paths. Prevents "unset the env var" as a bypass.
- **INV-6 (defense-in-depth)** — `scripts/hooks/pre-commit-plan-promote-guard.sh` remains active and still rejects Orianna-identity-spoof commits not accompanied by a valid Orianna signature trailer. The PreToolUse guard is primary; the commit guard is backup.

All tests are xfail-first (Rule 12) — the test commit lands on the task branch before any implementation commit for T1/T2.

## Open questions

- None blocking. If Claude Code surfaces additional filesystem-mutation tool names in future, the `Write|Edit|NotebookEdit` matcher list in T3 will need to be extended; leaving this as a maintenance note rather than a task.

## References

- Incident commits: `8717331` (Ekko promotion as Orianna-identity), `a802de4` (Ekko memory follow-up).
- Existing commit-phase guard (retained as defense-in-depth): `scripts/hooks/pre-commit-plan-promote-guard.sh`.
- Archived v1 promote helper: `scripts/plan-promote.sh` (archived — do not revive in this plan).
- Universal invariants: `CLAUDE.md` Rules 7, 12, 19.
- Lifecycle doc to update: `architecture/plan-lifecycle.md`.
