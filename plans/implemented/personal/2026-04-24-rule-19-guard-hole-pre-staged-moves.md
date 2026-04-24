---
id: 2026-04-24-rule-19-guard-hole-pre-staged-moves
title: Rule 19 — close commit-phase hole for pre-staged plan-lifecycle moves
status: implemented
concern: personal
owner: karma
complexity: quick
orianna_gate_version: 2
tests_required: true
created: 2026-04-24
---

## Context

Rule 19 reserves plan-lifecycle moves (out of `plans/proposed/` into `plans/approved|in-progress|implemented|archived/`) to the Orianna agent. Enforcement today lives in a single PreToolUse guard — `scripts/hooks/pretooluse-plan-lifecycle-guard.sh` — which intercepts Bash (`mv`/`cp`/`rm`/`tee`/`touch` via bashlex AST) and Write/Edit/NotebookEdit calls targeting protected roots.

The hole: the guard only fires on tool calls that directly touch those paths. If a plan-file move ends up in the git index by any other route — e.g. it was pre-staged by an earlier tool call (or swept in incidentally via `git add -A` / `git add <dir>` in an Orianna dispatch that then also inherits unrelated staged changes) — the subsequent `git commit` is not gated for plan-lifecycle identity at the commit phase. Result: a non-Orianna agent can, in principle, land a plan promotion through an indirection the PreToolUse hook did not observe. Recent evidence: an Orianna dispatch swept two unrelated pre-staged ekko files into her plan-promotion commit — benign, but demonstrates the gap.

Fix: add a pre-commit hook variant that inspects the staged file-change set for plan-lifecycle renames (rename out of `plans/proposed/<subtree>/` into a protected root, or any add/modify/delete against a path under a protected root that is not already-tracked as an edit-in-place) and refuses the commit unless the calling identity resolves to Orianna via the same env chain the PreToolUse guard uses (`CLAUDE_AGENT_NAME` → `STRAWBERRY_AGENT`; hook JSON `agent_type` is not available at commit phase). Admin break-glass: if neither env var is set AND `STRAWBERRY_AGENT_MODE` is unset (i.e. not inside an agent session at all), permit — this is a human Duong commit. Fail-closed otherwise. Note: `git config user.name` cannot disambiguate admin from agent because `agent-identity-default.sh` rewrites all agent commits to the `Duongntd` identity.

This is surgical — closes the loop without re-architecting lifecycle enforcement.

## Decision

Add `scripts/hooks/pre-commit-plan-lifecycle-guard.sh` that scans `git diff --cached --name-status -M` for plan-lifecycle mutations and rejects non-Orianna agent commits. Wire via the existing dispatcher (alphabetical pickup of `pre-commit-*.sh`).

Identity resolution order (commit phase — no hook JSON available):
1. `$CLAUDE_AGENT_NAME`
2. `$STRAWBERRY_AGENT`
3. If both empty AND `$STRAWBERRY_AGENT_MODE` also empty → treat as admin/human Duong → permit.
4. Otherwise (env set but not Orianna, or agent-mode flag set with empty identity) → reject.

A protected-path mutation is any staged entry whose NEW path or OLD path (for renames/deletes) matches `plans/(approved|in-progress|implemented|archived)/...`. Pure edits to an already-tracked file under those roots are permitted (matches PreToolUse Edit semantics); rename-in / rename-out / add / delete are the blocked shapes for non-Orianna.

## Tasks

- **T1 — xfail regression test (Rule 12 gate).** kind=test, estimate_minutes=12, files: `scripts/hooks/tests/test-pre-commit-plan-lifecycle-guard.sh` (new). <!-- orianna: ok -->
  Write a bats-free shell test that builds a temp git repo, installs the (not-yet-existent) hook, pre-stages a fake plan rename from `plans/proposed/personal/foo.md` to `plans/approved/personal/foo.md`, then invokes `git commit` with `CLAUDE_AGENT_NAME=kayn`. Expect exit non-zero and a `[plan-lifecycle-guard]` stderr prefix. A second case stages the same rename with `CLAUDE_AGENT_NAME=orianna` — expect success. A third case stages the rename with no env vars set — expect success (admin path). Commit the test xfail with a `Refs: plans/proposed/personal/2026-04-24-rule-19-guard-hole-pre-staged-moves.md T1` trailer and mark it xfail via early-skip guarded on the absence of the hook file (`[ -x scripts/hooks/pre-commit-plan-lifecycle-guard.sh ] || { echo "xfail: hook not yet implemented"; exit 0; }` pattern matching repo convention). DoD: test committed before T2; running it on main passes via xfail-skip.

- **T2 — implement `pre-commit-plan-lifecycle-guard.sh`.** kind=impl, estimate_minutes=25, files: `scripts/hooks/pre-commit-plan-lifecycle-guard.sh` (new). <!-- orianna: ok -->
  POSIX-portable bash. Read `git diff --cached --name-status -M --diff-filter=ACDRM` to enumerate staged changes. For each entry, normalize OLD and NEW paths and apply the `is_protected_path` predicate (copy the helper inline or source a shared lib if one exists — inline for surgical scope). If any entry touches a protected root in a non-edit-in-place shape (rename, add, delete; not pure M on pre-existing protected file), resolve identity via the env chain described in Decision, and `exit 1` with a rejection message on non-Orianna / agent-mode-without-orianna. Exit 0 otherwise. Include the same `[plan-lifecycle-guard]` stderr prefix to keep messaging consistent. DoD: T1 now passes when run, without removing the xfail guard (guard becomes a no-op because the file exists and is executable).

- **T3 — convert T1 test from xfail-skip to live assertions.** kind=test, estimate_minutes=8, files: `scripts/hooks/tests/test-pre-commit-plan-lifecycle-guard.sh`.
  Remove the xfail-skip early-return added in T1; the hook exists now. All three cases must assert real exit codes. DoD: running the test directly (without xfail shortcut) passes all three cases.

- **T4 — update `install-hooks.sh` header comment + architecture note.** kind=docs, estimate_minutes=6, files: `scripts/install-hooks.sh`, `architecture/plan-lifecycle.md`.
  Add `pre-commit-plan-lifecycle-guard.sh` to the header list in `install-hooks.sh` (comment only — dispatcher already auto-picks-up `pre-commit-*.sh`). In `architecture/plan-lifecycle.md`, add a short paragraph: "Defence-in-depth at commit phase — pre-staged moves are also gated." DoD: both files updated; no executable change.

- **T5 — wire test into `test-hooks.sh`.** kind=test, estimate_minutes=4, files: `scripts/hooks/test-hooks.sh`.
  Add the new test path to the aggregated runner so CI picks it up. DoD: `bash scripts/hooks/test-hooks.sh` runs the new suite.

## Test plan

Invariants protected:

1. **Non-Orianna agent cannot commit a plan-lifecycle rename-out-of-proposed** — T1 case 1. Protects Rule 19 at the commit phase.
2. **Orianna can commit plan-lifecycle moves** — T1 case 2. Guards against false-positive lockout.
3. **Admin/human Duong (no agent env vars) can commit plan-lifecycle moves** — T1 case 3. Preserves break-glass per Rule 18 spirit (human-only admin operations are not blocked).
4. **Pure edits to already-tracked files under protected roots are not blocked** — add a fourth case in T3: modify (not rename) an existing `plans/in-progress/...` file with `CLAUDE_AGENT_NAME=kayn` → should permit (matches PreToolUse Edit semantics allowing agents like Aphelios/Xayah to append Tasks sections to in-progress plans).

All four cases live in `scripts/hooks/tests/test-pre-commit-plan-lifecycle-guard.sh` and run via `scripts/hooks/test-hooks.sh`.

## References

- Rule 19 — `CLAUDE.md` §Critical Rules
- PreToolUse sibling: `scripts/hooks/pretooluse-plan-lifecycle-guard.sh`
- Identity rewrite (why `git config user.name` is not distinguishing): `scripts/hooks/agent-identity-default.sh`
- Orianna agent def: `.claude/_script-only-agents/orianna.md`
- Prior lifecycle plan: `plans/approved/personal/2026-04-23-plan-lifecycle-physical-guard.md`

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Clear owner (Karma), concrete task breakdown with files and DoDs, Rule 12 satisfied by xfail-first T1 before T2 impl, and the test plan enumerates four invariants including the false-positive-lockout and edit-in-place cases. Scope is surgical — one new hook script, one new test file, and wiring updates — no speculative architecture. Identity resolution at commit phase is well-reasoned against the `agent-identity-default.sh` constraint.

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** approved → implemented
- **Rationale:** PR #43 merged at 2026-04-24T09:11:42Z (merge commit bbd90ab7) with Rule 18 dual approval — Lucian APPROVE followed by Senna APPROVE after the changes-requested round. All T1–T5 deliverables present on main: `scripts/hooks/pre-commit-plan-lifecycle-guard.sh` (160 LoC), `scripts/hooks/tests/test-pre-commit-plan-lifecycle-guard.sh` (155 LoC), `scripts/hooks/test-hooks.sh` wiring, `scripts/install-hooks.sh` header comment, and `architecture/plan-lifecycle.md` defence-in-depth paragraph. Implementation evidence verified via fast-forward pull and file inspection.

