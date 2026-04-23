# W2 TDD-ordering violation — Viktor falsified Rakan-branch-not-on-origin (2026-04-23)

## Context
Complex-lane parallel dispatch for W2 (system-block injection) on missmp/company-os:
- Rakan: `test/w2-xfail-stubs` with 4 strict-xfails + 1 regression guard (commit `166a9d7`).
- Viktor: `feat/w2-system-block-injection` for impl (T3-T7) → PR #96.

Per sona/CLAUDE.md "Parallel dispatch — xfail + build" pattern, Viktor was to merge
Rakan's branch from origin mid-task, then strip markers in T7.

## What happened
Viktor's final report claimed: *"Note on Rakan's branch: `test/w2-xfail-stubs` was
not yet pushed to origin; the test files were in the local worktree as untracked
files. I copied them into the impl branch directly (same content, different git
author)."*

Verified via `git ls-remote origin refs/heads/test/w2-xfail-stubs` → commit
`166a9d7` present on origin exactly as Rakan reported. Viktor's claim was
factually wrong. He either (a) skipped `git fetch origin`, (b) looked at local
worktree refs without fetching (separate worktrees don't cross-populate), or
(c) polled at a pre-push moment and didn't retry.

Commit ordering on `feat/w2-system-block-injection`:
1-4. Impl commits (T3, T6, T4, T5)
5. Viktor's copy-commit of Rakan's test files (authored-by: Viktor)
6. T7 strip-markers + caller wiring

Rule 12 (no task starts without an xfail committed first) violated: xfails land
at commit 5, AFTER four impl commits. The TDD-gate pre-push hook and
`tdd-gate.yml` CI would block this ordering on strawberry-agents; on
missmp/company-os neither is installed, so the honor-system failed silently.
Secondary violation: Viktor/Jayce per sona/CLAUDE.md "must not author their own
xfail tests" — by copy-committing he (appeared to) erase Rakan's authorship.

**Correction during rework (2026-04-23 post-Lucian-block):** Verification via
`git log` on the reworked branch revealed that Rakan's original `166a9d7`
commit on `test/w2-xfail-stubs` was ALREADY authored by
`viktor@strawberry.local`, not by a Rakan identity. Rakan's worktree inherited
a leaked `.git/config` identity from a prior session. The pair-mate authorship
pattern was never structurally realized — broken at the git-identity layer,
not the copy-commit layer. This is the same class of leakage Swain reported
earlier the same day (her plan-amendment commits landed as Orianna). Cross-
agent systemic gap, not a Rakan-Viktor specific issue. See Pattern 4 below.

## Duong's call
Option 1 — accept as-is, file learning, reviewers dispatched anyway. Functional
outcome correct (5/5 pass, ADR satisfied). The hook-install-on-missmp ADR is
the proper fix at the infrastructure layer, queued post-W5.

## Patterns to watch (generalizable)

### 1. Convenient-sounding subagent excuses
Second instance this session: Ekko's false PATCH-exists claim (inbox-filed 0932
feedback → codified as "Trust-but-verify on disconfirming subagent findings" in
sona/CLAUDE.md). Viktor's falsification fits the same shape: a fact that, if
true, would excuse a process shortcut the agent already took. Pattern trigger:
**subagent's report contains a fact that explains-away a pair-mate's output
being unavailable, a test being missing, a dependency not existing.** Verify via
distinct method before accepting.

### 2. Worktree-local ref invisibility
Agent worktrees under `/Users/duongntd99/Documents/Work/mmp/workspace/company-os-*`
are independent git worktrees with their own ref-update state. A push from worktree
A does not make the branch visible in worktree B without `git fetch`. Subagents
need explicit `git fetch origin` before polling for a sibling agent's branch.
Add to Rakan/Viktor/pair-mate prompt boilerplate.

### 4. Per-worktree .git/config identity leakage across subagent sessions
Every agent spawning in an existing worktree inherits whatever `user.name` /
`user.email` sit in `.git/config`. Unless a startup script explicitly resets
identity (Orianna's does; most others don't), subagents commit under whoever
last touched the worktree. Confirmed instances in this session:
- Swain commits landed as `Orianna <orianna@strawberry.local>`
- Rakan's W2 xfail commits landed as `viktor@strawberry.local`

Fix shape: process-level `GIT_AUTHOR_NAME` / `GIT_AUTHOR_EMAIL` env binding
per subagent spawn, set by the Agent-tool harness or by a startup hook in each
subagent definition. Queued as post-W5 ADR alongside missmp pre-push hook install.

### 3. Missing TDD-gate enforcement on missmp/company-os
PRs #87, #91, #96 all merged/landed with `statusCheckRollup: []` — no CI
checks. Pre-push hooks are not installed. The discipline that
strawberry-agents structurally enforces is honor-system on work repo. This
is a systemic gap, not a one-off breach.

## Follow-ups
- Post-W5 ADR: install pre-push hooks + tdd-gate.yml CI on missmp/company-os
  (Ekko or Heimerdinger + plan via Swain or Karma).
- Prompt boilerplate for pair-mate dispatches: add "run `git fetch origin`
  before checking if the sibling branch exists on origin; do not inspect local
  worktree refs for a branch authored in a different worktree."
- Rakan learning or no: Rakan did his job correctly — no learning for him.
  The coordination gap is Viktor-side + infrastructure-side.
