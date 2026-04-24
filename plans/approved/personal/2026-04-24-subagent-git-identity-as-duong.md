---
status: approved
concern: personal
owner: karma
created: 2026-04-24
tests_required: true
complexity: quick
orianna_gate_version: 2
tags: [identity, subagent, worktree, git-author, co-authored-by, universal-invariant]
related:
  - agents/evelynn/inbox/archive/20260424-0922-022528.md
  - plans/approved/personal/2026-04-24-subagent-identity-leak-fix.md
  - scripts/hooks/pretooluse-work-scope-identity.sh
  - scripts/hooks/agent-identity-default.sh
  - scripts/hooks/_lib_reviewer_anonymity.sh
  - scripts/hooks/pre-commit-reviewer-anonymity.sh
---

# Subagent git identity as Duong (universal, forward-only)

## 1. Context

Sona flagged (inbox archive `agents/evelynn/inbox/archive/20260424-0922-022528.md`) that three recent squash-merges to `missmp/company-os` main now carry `Co-authored-by: Viktor <viktor@strawberry.local>` in the extended commit description: d7241b0e (#114), 9c9b0f2e (#115), f83d4b5e (#117). GitHub's squash-merge UI auto-derives `Co-authored-by:` trailers from any PR commit whose author differs from the PR author and prefills them into the squash body. Our subagent worktrees currently author commits under persona identities like `Viktor <viktor@strawberry.local>` and `Jayce <jayce@strawberry.local>`, so every PR that contains a subagent commit leaks a persona co-author on squash. This violates the global rule "never include AI authoring references in commits" (CLAUDE.md). <!-- orianna: ok -->

The existing approved plan `plans/approved/personal/2026-04-24-subagent-identity-leak-fix.md` addresses the work-scope author line via a PreToolUse guard keyed to `[:/]missmp/` origins, but: (a) it only covers work-scope, not personal-concern worktrees — and squash-merge co-author prefill is a universal leak surface, not a work-scope-only one; (b) it is still in `approved/` and has not shipped, which is why #114/#115/#117 exhibited the leak; (c) `scripts/hooks/agent-identity-default.sh` merges neutral env vars with a precedence that lets existing env override them (`{**neutral_env, **existing_env}`), which silently no-ops whenever a caller pre-populated an agent email. This plan is the universal, forward-only structural fix: rewire the git author for every subagent commit across both concerns to `Duongntd <103487096+Duongntd@users.noreply.github.com>`, so no `*@strawberry.local` identity ever appears as commit author and the squash-merge UI has no non-Duong author to prefill. <!-- orianna: ok -->

Forward-only. The 3 dirty commits on `missmp/company-os` main (d7241b0e, 9c9b0f2e, f83d4b5e) stay as-is — Rule 11 (never rebase) + the no-force-push invariant on protected branches means retroactive cleanup is off the table. Persona attribution continues to live in inboxes, learnings, memory, and the `owner:` field of plan frontmatter — git author becomes Duong, committer may remain agent-named for local audit, and the squash UI sees only one author on the PR. Scope is universal (both concerns); classification as a personal-concern plan reflects authorship location, not scope.

## 2. Decision

Generalize the existing work-scope PreToolUse identity guard to **all** subagent-dispatched git commits, regardless of origin. Concrete shape:

- Rename `scripts/hooks/pretooluse-work-scope-identity.sh` to `scripts/hooks/pretooluse-subagent-identity.sh` (or extend in place with a `SCOPE=universal` mode; T2 decides based on call-site grep). Drop the `[:/]missmp/` origin gate. Keep the fail-closed `git -C <cwd> config --local user.name/user.email` writes using the Duong noreply identity. Personal-concern worktrees (e.g. `~/Documents/Personal/strawberry-app/...` and sibling worktrees) become covered. <!-- orianna: ok -->
- Fix `scripts/hooks/agent-identity-default.sh` env-merge precedence: change `{**neutral_env, **existing_env}` to `{**existing_env, **neutral_env}` so neutral identity wins unless the caller explicitly sets `GIT_AUTHOR_*` / `GIT_COMMITTER_*` in the dispatch. Drop the origin gate (currently `[:/]missmp/`) so personal-concern Agent dispatches get the env too. <!-- orianna: ok -->
- Committer identity: leave `GIT_COMMITTER_NAME`/`GIT_COMMITTER_EMAIL` set to Duong as well. GitHub's squash UI keys co-author prefill off the **author** line, so setting committer=Duong is strictly additional defence; local audit of "who ran the commit" remains visible via the agent-persona shell prompts, inbox, and plan owner fields. <!-- orianna: ok -->
- Keep the existing `scripts/hooks/pre-commit-reviewer-anonymity.sh` author-line scan (from the prior plan's T2) as defence-in-depth. It already fails on denylist tokens in `GIT_AUTHOR_IDENT`; universalizing the PreToolUse hook means this becomes a belt-and-braces layer rather than the primary guard. <!-- orianna: ok -->
- Orianna is the one deliberate exception: `.claude/agents/orianna.md` line 21 sets `user.email=orianna@strawberry.local` for the plan-promotion commit trailer, enforced by `scripts/orianna-bypass-audit.sh`. Orianna never opens PRs to work-repos — her commits land on `strawberry-agents` main only. The PreToolUse hook must exempt Orianna via `agent_type=orianna` or `CLAUDE_AGENT_NAME=Orianna` resolution (same identity chain used by the plan-lifecycle guard). Document the carve-out in the hook header.

Why quick lane: one domain (PreToolUse hook library + one Python env-merge line), no schema, no new external integration, ≤ 90 AI-min, ≤ 4 tasks. Touches the same files as the prior approved plan's T1, so this plan effectively supersedes that T1 by widening its scope — T1 of the prior plan should be marked obsolete on promotion.

## 3. Non-goals

- No history rewrite on `missmp/company-os` main. d7241b0e / 9c9b0f2e / f83d4b5e stay dirty; external viewers have already seen them.
- No change to the reviewer-pipeline fallback (that's T3 of the prior approved plan `2026-04-24-subagent-identity-leak-fix.md`).
- No change to Orianna's self-authored plan-promotion commits. Her `orianna@strawberry.local` identity remains inside `strawberry-agents` and never reaches an MMP-visible PR.
- No change to coordinator commits (Sona/Evelynn) — they already commit as Duong per current configuration; the hook is a no-op when `user.email` is already `*@users.noreply.github.com`.
- No attempt to anonymise the committer line in locally-audited history — persona attribution continues to live in inbox + learnings + plan frontmatter.

## 4. Tasks

### T1. Xfail: subagent worktree commit must author as Duong
- kind: test
- estimate_minutes: 20
- files: `scripts/hooks/tests/test-subagent-identity-universal.sh` (new). <!-- orianna: ok -->
- detail: Shell test that (1) creates a temp git repo simulating a personal-concern worktree (no `missmp/` origin), (2) pre-configures `user.name=Viktor` / `user.email=viktor@strawberry.local` in that worktree to simulate the leak, (3) synthesizes a PreToolUse Bash tool_input JSON payload with `command="git commit -m 'test'"` and `cwd=<tempdir>`, (4) pipes it to `scripts/hooks/pretooluse-subagent-identity.sh`, (5) asserts the hook writes `user.email=103487096+Duongntd@users.noreply.github.com` into the worktree's local config. Also asserts the hook exempts Orianna when `CLAUDE_AGENT_NAME=Orianna` is set. Commit this BEFORE T2 per Rule 12. Must xfail on the current codebase (hook is named `pretooluse-work-scope-identity.sh` and gates on `missmp/`). Reference this plan in the commit body.
- DoD: test file exists, executable, xfails against current main; a separate test-hooks.sh entry or standalone runner picks it up.

### T2. Universalise the PreToolUse identity hook
- kind: script
- estimate_minutes: 30
- files: `scripts/hooks/pretooluse-work-scope-identity.sh` (rename/rewrite), `scripts/hooks/pretooluse-subagent-identity.sh` (new target path), `.claude/settings.json`, `scripts/hooks/agent-identity-default.sh`.
- detail: Decide via single `git grep pretooluse-work-scope-identity` whether to rename the file or keep the filename and widen behaviour. Preferred: rename to `pretooluse-subagent-identity.sh` and update `.claude/settings.json` reference (atomic diff, avoids stale name). Drop the `[:/]missmp/` origin gate so the hook fires on every `git commit` Bash dispatch. Add Orianna exemption: if `CLAUDE_AGENT_NAME=Orianna` OR resolved `agent_type` is `orianna`, exit 0 silently. Mirror the exemption in `scripts/hooks/agent-identity-default.sh` and flip the env-merge precedence (`{**existing_env, **neutral_env}`) so neutral identity wins. Document the carve-out in both hook headers with a pointer to `.claude/agents/orianna.md` line 21. POSIX-portable bash per Rule 10.
- DoD: T1 flips green; `scripts/hooks/test-hooks.sh` full run remains green; `git grep -n 'missmp/' scripts/hooks/pretooluse-*identity*.sh` returns no matches.

### T3. Smoke test on a personal-concern worktree + work-scope regression
- kind: test
- estimate_minutes: 15
- files: `scripts/hooks/tests/test-subagent-identity-universal.sh` (extend), `scripts/hooks/tests/test-identity-leak-fix.sh` (touch if existing assertions hard-code missmp-only behaviour).
- detail: Add a second test case: a work-scope worktree (simulated `origin=git@github.com:missmp/company-os.git`) with `user.email=viktor@strawberry.local` — assert the hook still rewrites to Duong (regression for the original work-scope path). Add a third case: cwd with no git origin at all (hook must exit 0 silently, not block). Re-run `scripts/hooks/test-hooks.sh` and the new test; both must pass.
- DoD: three-case test matrix passes; any test in `test-identity-leak-fix.sh` that asserted "no rewrite outside missmp" is updated or removed with a pointer to this plan.

### T4. Document universal identity discipline + close the approved-plan loop
- kind: doc-edit
- estimate_minutes: 15
- files: `architecture/agent-system.md`, `plans/approved/personal/2026-04-24-subagent-identity-leak-fix.md`.
- detail: In `architecture/agent-system.md`, add a "Git identity discipline" subsection (under the existing agent-infrastructure section, or create it): explain that all subagent commits author as `Duongntd <103487096+Duongntd@users.noreply.github.com>` across both concerns, Orianna is the sole carve-out, and persona attribution lives in inbox/learnings/memory/plan-frontmatter — never in git metadata. Reference the hook path and this plan. In `plans/approved/personal/2026-04-24-subagent-identity-leak-fix.md`, append a "Superseded-by" line at the top of §4 T1 pointing to this plan (the broader universal fix replaces the work-scope-only T1); leave T2/T3/T4 of that plan intact — they cover the commit-msg author-scan, reviewer-comment wrapper, and verdict template, which are orthogonal.
- DoD: architecture doc updated; prior plan T1 annotated; `grep -n 'strawberry.local' architecture/agent-system.md` returns no hits (other than inside code-fenced illustrative counter-examples explicitly labelled as the failure mode).

## 5. Test plan

Invariants protected:

1. **No subagent commit authors as `*@strawberry.local`** on any worktree, work-scope or personal-concern (T1 primary + T3 work-scope regression).
2. **Orianna's plan-promotion commits retain `orianna@strawberry.local`** (T1 exemption case).
3. **Non-commit Bash dispatches are unaffected** — hook only touches worktree config when the command contains `git commit` (existing behaviour; T3 third case asserts no-origin cwd exits 0).
4. **`agent-identity-default.sh` env-merge now prefers neutral identity** over caller-supplied `GIT_AUTHOR_*` unless the caller explicitly overrides — behaviour change must be visible in a unit-style assertion (can piggyback on T1's JSON-payload test).

Execution:
- `bash scripts/hooks/tests/test-subagent-identity-universal.sh` — three-case matrix (personal-concern, work-scope, no-origin), plus Orianna exemption.
- `bash scripts/hooks/test-hooks.sh` — full hook suite regression.
- Manual smoke: dispatch a no-op Talon subagent in `~/Documents/Personal/strawberry-app` worktree, make a trivial `git commit --allow-empty -m 'smoke'`, verify `git log -1 --format='%ae %ce'` returns `103487096+Duongntd@users.noreply.github.com` for both author and committer.

## 6. References

- Inbox: `agents/evelynn/inbox/archive/20260424-0922-022528.md` (Sona's report)
- Prior plan: `plans/approved/personal/2026-04-24-subagent-identity-leak-fix.md` (this plan supersedes T1, leaves T2-T4 intact)
- Existing hook: `scripts/hooks/pretooluse-work-scope-identity.sh`
- Existing env-injector: `scripts/hooks/agent-identity-default.sh`
- Orianna identity carve-out: `.claude/agents/orianna.md` line 21
- Dirty commits (forward-only, not remediated): `missmp/company-os` d7241b0e (#114), 9c9b0f2e (#115), f83d4b5e (#117)

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** Plan has a clear owner (karma), four concrete tasks with explicit files and DoDs, T1 xfail-first per Rule 12, and an unambiguous Orianna carve-out with the exemption path documented. Non-goals are crisp (no history rewrite, no coordinator-commit change, no committer-line anonymisation). Scope is well-motivated by the three observed leak commits and the existing approved plan's gap. No unresolved TBD/TODO/Decision-pending in gating sections.
