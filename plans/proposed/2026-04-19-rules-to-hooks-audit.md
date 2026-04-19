---
title: Rules-to-hooks audit — which CLAUDE.md invariants can be mechanically enforced
status: proposed
owner: swain
created: 2026-04-19
tags: [governance, hooks, ci, enforcement, claude-md]
---

# Rules-to-hooks audit

Audit of the 18 Universal Invariants in `CLAUDE.md` against current enforcement
surface (git hooks in `scripts/hooks/`, Claude Code hooks in `.claude/settings.json`,
GitHub Actions in `.github/workflows/`, scripts under `scripts/`). Thesis from
Duong (operationalising `agents/evelynn/learnings/2026-04-11-rules-need-hooks.md`):
written rules are guidance, not enforcement. Where a mechanical gate is possible,
prefer a hook. Rules should be reserved for things that genuinely can't be
hook-enforced.

Advisor output. Proposes migrations, does not implement them. No implementer
assignment — Duong decides if/when to approve, Evelynn routes execution.

Cross-reference: `agents/evelynn/learnings/2026-04-19-hooks-cannot-invoke-tools.md`
(ceiling on Claude Code hooks: `additionalContext` string injection, not forced
tool calls — relevant for rules that require in-session action).

## 1. Methodology

For each rule I checked:

- **Git hooks**: `scripts/hooks/pre-commit-*.sh`, `scripts/hooks/pre-push-*.sh`
  (installed via `scripts/install-hooks.sh`).
- **Claude Code hooks**: `.claude/settings.json` — `PreToolUse`, `PostToolUse`,
  `SessionStart`, `SubagentStart`, `SubagentStop`.
- **CI**: `.github/workflows/*.yml` in strawberry-agents (no access to
  strawberry-app from this session; CI there inferred from plan references).
- **Scripts**: `scripts/plan-promote.sh`, `scripts/safe-checkout.sh`,
  `scripts/lint-subagent-rules.sh`, `tools/decrypt.sh`,
  `scripts/setup-branch-protection.sh`.

Enforcement levels used:

- **HARD** — violation is blocked at the harness / git / CI layer. Agent cannot
  proceed without explicit bypass trailer.
- **SOFT** — guard exists but relies on procedure (e.g. `safe-checkout.sh`) that
  an agent may simply not invoke; raw `git checkout` still works.
- **CI-ONLY** — enforced at PR / push time but not at commit time. Agent can
  push bad commits and only learn about it from GitHub.
- **WRITTEN-ONLY** — no mechanical gate. Compliance depends on the agent
  reading and following the rule.
- **PARTIAL** — some failure modes caught, others not. Detailed per row.

## 2. Audit table

| # | Rule (short) | Current enforcement | Hookable? | Proposed hook | Effort | Risk |
|---|---|---|---|---|---|---|
| 1 | Never leave work uncommitted before git ops | SOFT (`safe-checkout.sh` exists, raw `git checkout` unguarded) | Yes | PreToolUse `Bash` matcher: grep command for `git (checkout\|switch\|reset --hard\|clean -fd)` and block with actionable error if `git status --porcelain` is non-empty | S | Low FP if scoped to destructive verbs; slight latency on every Bash tool call (add early exit for non-git commands) |
| 2 | Never write secrets into committed files | HARD (`pre-commit-secrets-guard.sh` — 4 guards incl. armor header, raw `age -d`, token shapes, decrypted-value scan) | Already hook-enforced — keep rule as context doc | n/a | n/a | — |
| 3 | Use `git worktree` — never raw `git checkout` | SOFT (`safe-checkout.sh` is a helper, not a gate) | Yes | Same PreToolUse `Bash` hook as rule 1: block raw `git checkout <branch>` and `git switch <branch>`, direct caller to `scripts/safe-checkout.sh`. Allow `git checkout -- <file>` and `git checkout HEAD` (no branch change) | S | Medium FP — many legitimate `git checkout <file>` uses; hook must whitelist by arg shape |
| 4 | Plans go directly to main, never via PR | PARTIAL — `scripts/plan-promote.sh` enforces Drive mirror flow; nothing stops an agent from opening a PR that *contains* a plan file | Yes | Pre-commit hook: if staged tree touches `plans/` AND current branch is not `main`, block unless commit msg has `Plans-In-PR-Waiver:` trailer. Complements the existing promote-guard | S | Very low — narrow diff predicate |
| 5 | Conventional commit prefixes — scoped by diff | WRITTEN-ONLY (CLAUDE.md says "the pre-push hook enforces diff-scope ↔ commit-type" but no such hook exists in `scripts/hooks/`) | Yes | Pre-commit (or commit-msg) hook: parse first line of `COMMIT_EDITMSG`, validate prefix is in `feat/fix/perf/refactor/chore/ops` (+ optional `!`), cross-check diff scope — if `apps/**` touched, require code-prefix; else require `chore:`/`ops:` | M | Medium FP on mixed-diff commits; needs override trailer `Commit-Prefix-Override:` for genuinely mixed changes. Stale CLAUDE.md claim is the bigger risk — agents assume enforcement that doesn't exist |
| 6 | Never run raw `age -d` — use `tools/decrypt.sh` | HARD at commit-time (pre-commit secrets guard scans for `age -d` in staged files). PARTIAL at run-time — an agent can still shell `age -d` live in a session | Runtime enforcement possible | Add PreToolUse `Bash` matcher that greps the command for `\bage\s+-d\b` (excluding `tools/decrypt.sh` path), exit 2 | S | Low — very specific pattern, few false positives |
| 7 | Use `scripts/plan-promote.sh` to move plans out of `proposed/` | HARD (`pre-commit-plan-promote-guard.sh` blocks D/A/R diffs that promote plans without fact-check report or `Orianna-Bypass:` trailer) | Already hook-enforced — keep rule as context doc | n/a | n/a | — |
| 8 | Always invoke `/end-session` / `/end-subagent-session` before closing | PARTIAL — `SubagentStop` hook in `.claude/settings.json` emits a **post-hoc warning** if `/tmp/claude-subagent-<sid>-closed` sentinel is missing, but the session has already ended. No pre-close block exists | No hard gate possible (Claude Code exposes no pre-close intercept) — keep as WRITTEN, already hook-adjacent | Improve the warning: include agent name + last-session path so Evelynn can notice and run the closing protocol manually | S (enhancement) | n/a |
| 9 | Agent model selection — `.claude/agents/*.md` SHOULD declare `model:` | WRITTEN-ONLY (no lint check for frontmatter `model:` field) | Yes | CI check (`pr-lint.yml` add-job) and/or pre-commit hook: parse YAML frontmatter of each `.claude/agents/*.md`, warn (not block) if `model:` missing. Rule 9 says "SHOULD" + inheritance permitted, so warn is the right level | S | Very low — limited to advisory output |
| 10 | Scripts in `scripts/` must be POSIX-portable bash | WRITTEN-ONLY | Partially | Pre-commit hook: for any staged `scripts/*.sh` (outside `scripts/mac/` and `scripts/windows/`), run `shellcheck -s sh` OR at minimum `bash -n` with `#!/bin/sh` shebang check. Cannot catch all non-portable constructs automatically but will catch the common ones (`[[`, arrays in `/bin/sh` scripts, `-e` in echo) | M | Medium FP if `#!/usr/bin/env bash` is allowed but uses bash-isms — need clear scope. shellcheck dependency on dev machines |
| 11 | Never use `git rebase` — always merge | WRITTEN-ONLY | Yes | PreToolUse `Bash` matcher: block commands matching `\bgit\s+rebase\b`, exit 2 with "use merge instead" message. Allow `git pull --no-rebase` and similar | S | Very low — tight pattern match |
| 12 | No task starts without an xfail test committed first | HARD in CI (`tdd-gate.yml`) + PARTIAL at push (`pre-push-tdd.sh` enforces on TDD-enabled packages only) | Already partially hook-enforced — keep rule; consider extending pre-commit to warn (not block) when impl-files staged without preceding xfail commit on branch | Already largely enforced; optional pre-commit warning | S (optional) | — |
| 13 | No bug fix lands without a regression test | HARD in CI (`tdd-gate.yml` regression-test job) + PARTIAL at push (`pre-push-tdd.sh` rule 2) | Already hook-enforced | n/a | n/a | — |
| 14 | Pre-commit runs unit tests for changed packages; blocked on failure | HARD (`pre-commit-unit-tests.sh`) | Already hook-enforced — the rule IS the hook | n/a | n/a | — |
| 15 | PR creation triggers Playwright E2E; PR cannot merge red | HARD (branch protection + `e2e.yml`, required check) | Already CI-enforced at merge gate | n/a | n/a | — |
| 16 | Before opening a UI PR, QA agent must run Playwright + Figma diff | HARD in CI (`pr-lint.yml` verifies `QA-Report:` URL in PR body when UI files touched, with `QA-Waiver:` bypass trailer) | Already CI-enforced | n/a | n/a | — |
| 17 | Post-deploy smoke tests on stg/prod; rollback on prod failure | PARTIAL — deploy workflows referenced in plan but not verified in-session against prod rollback step. Assumed HARD at prod deploy layer | Already deploy-layer enforced (to be verified by Heimerdinger) | n/a (verify-only) | S (audit) | — |
| 18 | Agents must NOT `gh pr merge --admin` or self-merge own PR | WRITTEN-ONLY (no tool-level block; branch protection prevents the unauthorized-merge outcome server-side, but the agent can still *try* the command) | Yes | PreToolUse `Bash` matcher: block commands matching `gh\s+pr\s+merge.*--admin` AND block `gh pr merge` on PRs authored by `Duongntd` agent account (lookup via `gh pr view --json author`). Combined with existing server-side branch protection, this becomes defense-in-depth | M | Medium — the self-merge check requires a `gh pr view` call inside the hook, which adds latency and a network failure mode. Could start with just the `--admin` block (simpler) and defer self-merge to CI |

## 3. Top 5 to migrate first

Ranked by (drift risk × blast radius) / effort. Highest-value migrations first.

### 3.1 Rule 5 — Conventional commit prefixes (SHIP FIRST)

**Why urgent:** CLAUDE.md claims "the pre-push hook enforces diff-scope ↔
commit-type" but no such hook exists. This is a *stale promise* — agents and
reviewers may assume enforcement that isn't there. High drift risk (commit
prefixes are every-commit behaviour) and the gap is actively misleading.

**Proposed hook:** `scripts/hooks/commit-msg-prefix.sh` + pre-push mirror.
Parse first line of commit message, validate prefix ∈ `{feat, fix, perf,
refactor, chore, ops}` (with optional `!` for breaking). Cross-check diff
scope: `apps/**` requires code prefix; everything else requires `chore:` or
`ops:`. Override via `Commit-Prefix-Override:` trailer with reason ≥ 10 chars.

**Effort:** M. **Risk:** Medium FP on legitimately mixed-diff commits (e.g. a
chore commit that happens to touch one apps/ file) — mitigated by override
trailer.

### 3.2 Rule 11 — Never `git rebase`

**Why urgent:** Lowest-effort high-value win. Tight regex match, near-zero FP
surface, closes a known footgun (agents reaching for rebase to "clean up
history" can corrupt shared branches). One line in `.claude/settings.json`
under PreToolUse→Bash.

**Proposed hook:** PreToolUse `Bash` matcher, regex `\bgit\s+rebase\b`, exit 2
with error `"git rebase is banned — use git merge. See CLAUDE.md rule 11."`

**Effort:** S. **Risk:** Very low.

### 3.3 Rule 3 — Raw `git checkout` blocked (enforce `safe-checkout.sh`)

**Why urgent:** Currently SOFT — `safe-checkout.sh` is just a script, nothing
stops an agent from running `git checkout other-branch` directly and losing
another agent's uncommitted work. This failure mode is exactly why Rule 1
exists. Pairs naturally with Rule 1 enforcement (both live in the same
PreToolUse Bash hook).

**Proposed hook:** PreToolUse `Bash` matcher detects `git checkout <branch>`
or `git switch <branch>` (allowing file-scoped checkouts `git checkout --
path`). Block unless `scripts/safe-checkout.sh` is the invoking command or a
`Safe-Checkout-Override:` env var is set.

**Effort:** S. **Risk:** Medium FP on file-scoped checkouts — needs careful arg
parsing. Worth the effort because the underlying invariant (Rule 1) is a
data-loss risk.

### 3.4 Rule 1 — Never leave work uncommitted (PreToolUse)

**Why urgent:** Data-loss invariant. Currently SOFT. Shares a hook file with
Rule 3 — once the PreToolUse `Bash` hook is in place for checkout/switch, the
uncommitted-work check is `git status --porcelain` on the same trigger.
Different from Rule 3 because it also catches `git reset --hard`,
`git clean -fd`, `git stash drop`, etc.

**Proposed hook:** Extend the same PreToolUse Bash hook. Destructive verbs
(`checkout`, `switch`, `reset --hard`, `clean -fd`) trigger a
`git status --porcelain` check; non-empty → block.

**Effort:** S (additive to 3.3). **Risk:** Low.

### 3.5 Rule 18 — `gh pr merge --admin` block

**Why urgent:** Branch protection already blocks the *outcome* server-side,
but agents can still *attempt* the command and either burn audit-log noise
or, if branch protection is misconfigured, actually bypass. Tool-level block
turns this into defense-in-depth.

**Proposed hook:** PreToolUse `Bash` matcher, regex `gh\s+pr\s+merge.*--admin`,
exit 2. Defer the self-merge check (harder — requires `gh pr view` lookup)
to a CI job that runs on PR `ready_for_review`.

**Effort:** S (for `--admin` block alone). **Risk:** Very low.

## 4. Stays as rule — genuinely not hook-enforceable

These rules require context or judgement that hooks can't supply.

### 4.1 Rule 8 — Always invoke `/end-session` before closing

Already hook-adjacent: `SubagentStop` emits a post-hoc warning when the
sentinel is missing. A **pre-close** intercept is not exposed by Claude Code
— the session has already ended by the time the hook fires. Best available
enforcement is the post-hoc warning, which is already in place. Enhancement
suggestion: include agent name and last-session file path in the warning so
Evelynn can run the closing protocol manually on the next session start.

### 4.2 Rule 9 — Agent model declaration (advisory, not enforced)

Rule explicitly says `SHOULD` and permits inheritance. A CI warning is the
appropriate level. Not a hard gate.

### 4.3 Rule 10 — POSIX-portable bash

Partially hookable via `shellcheck -s sh`, but shellcheck doesn't catch every
non-portable construct (subtle ones like process substitution or printf
variants slip through). A hook + written rule combo is the right answer: hook
catches the common cases, written rule covers the tail. Listed as SHOULD-
migrate-partial (effort M), not in the top 5 because drift risk is lower
(scripts are written infrequently and reviewed).

### 4.4 Rule 17 — Post-deploy smoke tests / prod rollback

Enforced at the deploy workflow layer, not at the agent-action layer. Agents
don't deploy; workflows do. The rule exists to document the CI contract for
humans. No tool-level hook applies.

### 4.5 Rules 2, 7, 12, 13, 14, 15, 16 — Already hook-enforced

These already have mechanical enforcement and the written rule serves as
context/documentation. No migration needed, but a passing mention in §6
("already well-enforced") so Duong doesn't re-migrate them by mistake.

## 5. Gating questions for Duong

Questions the audit cannot resolve without Duong's intent:

**Q1 — Commit prefix hook strictness.** Rule 5 migration proposes a
`Commit-Prefix-Override:` trailer for mixed diffs. Do you want:
 - (a) Hard block + override trailer (proposed);
 - (b) Warn-only during an adoption period;
 - (c) Hard block + **no** override trailer (every mixed diff must be split
   into two commits)?

Option (c) is the cleanest but forces more commits; (a) is pragmatic.

**Q2 — Raw `git checkout` block scope.** Rule 3 migration proposes blocking
`git checkout <branch>` and `git switch <branch>` but allowing
`git checkout -- <path>` (file revert). Some developers use
`git checkout <tag>` or `git checkout <sha>` for archaeology. Should the hook
also block detached-HEAD checkouts, or allow them? I recommend **allow**
(detached-HEAD is read-only in practice and doesn't risk the uncommitted-work
invariant), but it's a judgment call.

**Q3 — Self-merge block enforcement surface.** Rule 18 migration could block
`gh pr merge` on self-authored PRs via a PreToolUse hook (adds latency from
`gh pr view` lookup) or via a CI job on `ready_for_review`. CI job is simpler
but catches the violation after the fact. Which do you prefer?

**Q4 — Written rules you want to keep even if hookable.** Sometimes a written
rule is *valuable as written rule* because the statement itself teaches the
principle. Examples:
 - Rule 1 ("never leave work uncommitted") — even if hooked, the rule text
   explains *why* (shared workdir, other agents).
 - Rule 11 ("never rebase") — the hook blocks, but the rule explains the
   merge-over-rebase philosophy.

Proposal: keep the rule text for all migrated rules, but add
`Enforced by: <hook-path>` footnotes so readers know mechanical enforcement
exists. Do you agree?

**Q5 — Stale enforcement claim in Rule 5.** CLAUDE.md currently says "The
pre-push hook enforces diff-scope ↔ commit-type" but no such hook exists.
Should the hook land *first* and then the claim become true, or should we
immediately weaken the claim to "(hook planned)" while the migration is in
flight?

Recommendation: fix the claim first (a tiny chore commit) so the doc isn't
lying, then land the hook after.

## 6. Already well-enforced (don't re-migrate)

Duong may assume these are under-enforced; they are not.

| Rule | What's protecting it |
|---|---|
| 2 (secrets) | `pre-commit-secrets-guard.sh` — 4-layer guard, incl. armor-header, raw `age -d`, token shapes, AND decrypted-value scan that mounts real plaintext briefly to scrub-detect |
| 7 (plan-promote) | `pre-commit-plan-promote-guard.sh` — detects D/A/R diffs, requires fact-check report OR `Orianna-Bypass:` trailer |
| 12, 13 (xfail-first, regression test) | `pre-push-tdd.sh` + `tdd-gate.yml` (CI required check) |
| 14 (pre-commit unit tests) | `pre-commit-unit-tests.sh` — uses `tdd.enabled:true` package.json flag for opt-in |
| 15 (E2E required) | `e2e.yml` required via branch protection |
| 16 (QA report) | `pr-lint.yml` — requires `QA-Report:` URL in PR body on UI diffs |

## 7. Surprising findings

1. **Rule 5 claims enforcement that doesn't exist.** "The pre-push hook
   enforces diff-scope ↔ commit-type" is written into CLAUDE.md, but no
   prefix-validating hook is present in `scripts/hooks/` or
   `.git/hooks/`. This is the single biggest doc-vs-reality gap in the
   invariants. It's also the one agents encounter most often (every
   commit).

2. **`safe-checkout.sh` is a helper, not a gate.** The script exists and is
   recommended, but nothing prevents an agent from typing `git checkout
   other-branch` directly. For a rule sold as a data-loss invariant
   (shared workdir), the current enforcement level is surprisingly soft.

3. **The SubagentStop sentinel is post-hoc only.** The hook fires *after*
   the subagent session ends — it can warn but not block. This is a
   deliberate design choice documented in `agents/evelynn/CLAUDE.md`, but
   it means Rule 8 is, effectively, an honor-system rule with a safety net.

4. **The secrets guard is overkill-in-a-good-way.** Guard 4 actually
   decrypts all `secrets/encrypted/*.age` blobs into a scratch directory
   and grep-scans staged files for the plaintext values. This is
   substantially stronger than most repos' secret scanners. Worth
   mentioning because one might assume Rule 2 is "just gitleaks" — it's
   not.

5. **Hook ceiling is `additionalContext`, not forced tool calls.** Per
   `agents/evelynn/learnings/2026-04-19-hooks-cannot-invoke-tools.md`, any
   "the model should do X next" behaviour must be shaped as an
   `additionalContext` string injection, not a forced tool call. This
   limits Rules 8, 9 (agent-model field) to advisory-reminder territory
   rather than block-at-write territory.

6. **Claude Code PreToolUse hooks are global.** Per the 2026-04-11 learning,
   they apply to Evelynn as well as subagents. Migrating Rules 1, 3, 11, 18
   via PreToolUse will affect Evelynn too. For Rule 3 this is fine (Evelynn
   also shouldn't raw-checkout). For a hypothetical asymmetric rule
   (subagents only), hook-level enforcement would require session-context
   detection that isn't exposed. None of the top-5 migrations here are
   asymmetric, so this is not a blocker — just a thing to remember.

## 8. Out of scope

- **Implementing any of the proposed hooks.** This is an audit + plan.
  Evelynn routes execution after Duong approves.
- **Revising the CLAUDE.md text itself.** Suggested in passing (Rule 5 stale
  claim) but the edits should come with the hook migrations, not before.
- **strawberry-app repo hooks.** CI references point to
  `harukainguyen1411/strawberry-app` but this session has no checkout of
  that repo; enforcement there may differ.

## 9. Next steps (for Duong / Evelynn, not prescribed)

- Duong reviews gating questions in §5.
- If approved, the migrations in §3 break into two follow-up tasks:
  - **Fix the stale claim in CLAUDE.md** (tiny chore, can land same-day).
  - **Ship the top-5 hook migrations**: a single plan that Evelynn commissions
    from Camille (git/security-focused) or Heimerdinger (CI-focused), then
    delegates to Ekko for execution. TDD required for the hook bodies under
    `scripts/hooks/` (they are testable shell scripts — see
    `scripts/hooks/test-plan-promote-guard.sh` for the pattern).
