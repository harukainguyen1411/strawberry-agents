# Strawberry — Personal Agent System

## For Coordinator Sessions

**If you are Evelynn (the personal-concern coordinator — no greeting given), also read `agents/evelynn/CLAUDE.md` immediately after this file.**

**If you are Sona (the work-concern coordinator — greeted as "Hey Sona"), also read `agents/sona/CLAUDE.md` immediately after this file.**

### /compact workflow

Before running `/compact` on a coordinator session, run `/pre-compact-save` first. The PreCompact hook will block a bare `/compact` and prompt you to run the skill. To opt out for a specific session, `touch .no-precompact-save` in the repo root. Full mechanics: `architecture/compact-workflow.md`.

## Scope

This repo is the canonical home for BOTH concerns:

- **Personal concern** — coordinated by Evelynn. Operates on `~/Documents/Personal/strawberry-app/` and siblings.
- **Work concern** — coordinated by Sona. Operates on `~/Documents/Work/mmp/workspace/` (data/domain repo only; no agent infrastructure there).

Memory and learnings are shared across concerns (agents accumulate knowledge globally). Only `plans/`, `architecture/`, `assessments/` split into `work/` vs `personal/` subtrees.

## Caller Routing

- **"Hey Sona"** → you are Sona. Read `agents/sona/CLAUDE.md` then the Sona startup chain in `.claude/agents/sona.md`. Default `[concern: work]` for all subagents you spawn.
- **"Hey Evelynn"** → you are Evelynn. Read `agents/evelynn/CLAUDE.md` then the Evelynn startup chain. Default `[concern: personal]`.
- **"Hey <other-agent>"** → you are that agent; concern must have been injected by caller as `[concern: work]` or `[concern: personal]` on the first line of the task prompt.
- **No greeting given** → you are **Evelynn** by default (personal concern is the historical default of this repo).

See `agents/memory/agent-network.md` for the full roster.

## Critical Rules — Universal Invariants

<!-- #rule-no-uncommitted-work -->
1. **Never leave work uncommitted** — commit before any git operation that changes the working tree. (Other agents share this working directory — uncommitted work WILL be lost.)

<!-- #rule-no-secrets-in-commits -->
2. **Never write secrets into committed files** — use `secrets/` (gitignored) or env vars.

<!-- #rule-git-worktree -->
3. **Use `git worktree` for branches** — never raw `git checkout`. Use `scripts/safe-checkout.sh`.

<!-- #rule-plans-direct-to-main -->
4. **Plans go directly to main, never via PR** — Commit plan files directly to main. Only implementation work goes through a PR.

<!-- #rule-chore-commit-prefix -->
5. **Conventional commit prefixes — scoped by diff** —
   - **Touches `apps/**`?** Use one of: `feat:`, `fix:`, `perf:`, `refactor:`, `chore:`. Breaking changes use `feat!:` or a `BREAKING CHANGE:` footer. (These feed release-please versioning — see `plans/approved/2026-04-17-deployment-pipeline.md` §6.)
   - **Touches infra / ops only (deploys, GCP, CI)?** Use `ops:`.
   - **Everything else** (plans, agent definitions, scripts outside `apps/**`, docs)? Use `chore:`.
   - **Never** use `docs:` / `plan:` / other non-conventional prefixes.
   - The pre-push hook enforces diff-scope ↔ commit-type.

<!-- #rule-no-raw-age-d -->
6. **Never run raw `age -d` or read decrypted secret values into context** — Use `tools/decrypt.sh` exclusively; it keeps plaintext in the child process env only. Never `cat`/`type`/pipe `secrets/age-key.txt`. The pre-commit hook blocks violations.

<!-- #rule-plan-promote-sh -->
7. **Use `scripts/plan-promote.sh` to move plans out of `plans/proposed/`** — never raw `git mv` for plans leaving `proposed/`. `plan-promote.sh` runs the Orianna gate, moves the file, rewrites `status:`, commits, and pushes.

<!-- #rule-end-session-skill -->
8. **Always invoke `/end-session` before closing any session** — no agent may terminate a session by any other mechanism. Top-level sessions use `/end-session` (disable-model-invocation: true — Duong or Evelynn must explicitly trigger it). Sonnet subagent sessions use `/end-subagent-session`, which subagents invoke themselves at session end. Both skills produce the handoff note, memory refresh, learnings, and commit; `/end-session` additionally produces a cleaned-transcript archive.

<!-- #rule-agent-model-declaration -->
9. **Agent model selection is explicit or inherited** — every `.claude/agents/<name>.md` SHOULD declare a `model:` frontmatter field (`opus` for planners, `sonnet` for executors — short aliases, never pinned version IDs). Omitting `model:` is permitted and means the agent inherits the session's default model at spawn time. Haiku is retired; do not introduce new Haiku agents.

<!-- #rule-posix-portable-scripts -->
10. **Scripts in `scripts/` (outside `scripts/mac/` and `scripts/windows/`) MUST be POSIX-portable bash** — runnable on both macOS and Git Bash on Windows. Platform-specific affordances live under `scripts/mac/` or `scripts/windows/`.

<!-- #rule-never-rebase -->
11. **Never use `git rebase`** — always merge.

<!-- #rule-xfail-first -->
12. **No task starts without an xfail test committed first** — for TDD-enabled services,
    any implementation commit must be preceded on the same branch by a commit adding
    an xfail test referencing the plan or task. Enforced by pre-push hook and CI
    (`tdd-gate.yml`). Agents may never bypass.

<!-- #rule-regression-test -->
13. **No bug fix lands without a regression test** — commits tagged as bug/bugfix/
    regression/hotfix must include or be preceded by a regression test in the same
    branch. Enforced by pre-push hook, CI, and the PR template. Agents may never bypass.

<!-- #rule-pre-commit-unit-tests -->
14. **Pre-commit hook runs unit tests for changed packages; commit blocked on failure** —
    installed via `scripts/install-hooks.sh` alongside the secret-scanning and
    commit-prefix hooks. Agents may not pass `--no-verify`.

<!-- #rule-e2e-required -->
15. **PR creation triggers Playwright E2E; PR cannot merge red** — GitHub Actions
    `e2e.yml` runs on every PR to main; required check via branch protection.
    Agents may never merge a red PR.

<!-- #rule-qa-agent-pre-pr -->
16. **Before opening a UI PR, a QA agent must run the full Playwright flow with
    video + screenshots and diff against the Figma design** — report lives under
    `assessments/qa-reports/` and is linked in the PR body. Enforced by PR body
    linter. Non-UI PRs exempt.

<!-- #rule-smoke-tests -->
17. **Post-deploy smoke tests run on stg and prod; rollback on prod failure** —
    extends the deployment pipeline workflow. Prod smoke failures trigger auto-
    revert via `scripts/deploy/rollback.sh`. No bypass for prod.

<!-- #rule-no-admin-merge -->
18. **Agents must NOT use `gh pr merge --admin` or any branch-protection bypass**, and
    must NOT merge a PR they authored. Every merge requires (a) all required status
    checks green, (b) one approving review from an account other than the PR author,
    and (c) no red required check. Break-glass admin merges are a human-only Duong
    procedure (see `plans/approved/2026-04-17-branch-protection-enforcement.md` §3).

<!-- #rule-orianna-signature-required -->
19. **Plan promotions past `proposed → approved` require valid Orianna signatures on every transition** — `scripts/plan-promote.sh` invokes `scripts/orianna-verify-signature.sh` for the target phase plus carry-forward verification of all prior signatures. Plans authored under the v2 regime (`orianna_gate_version: 2`) are blocked from any transition without a valid signature; grandfathered plans (no `orianna_gate_version` field) fall back to legacy fact-check behavior. The only bypass is the `Orianna-Bypass: <reason>` commit trailer, valid only when the commit author is Duong's admin identity (`harukainguyen1411`); agent-identity bypass attempts are rejected by the pre-commit hook. See `architecture/plan-lifecycle.md` for the full lifecycle, `architecture/key-scripts.md` for the helper scripts, and `plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md` §D9.1 for the bypass rationale.

## File Structure

| Path | Purpose |
|------|---------|
| `architecture/` | System docs — source of truth for how the system works |
| `plans/` | Execution plans (`YYYY-MM-DD-<slug>.md`, YAML frontmatter). Subdirs: `proposed/`, `approved/`, `in-progress/`, `implemented/`, `archived/` |
| `assessments/` | Analyses, recommendations, evaluations |
| `agents/` | Profiles, memory, journals, learnings per agent |
| `scripts/` | POSIX-portable shell scripts — see `architecture/key-scripts.md` |
| `tools/` | Helper binaries (e.g. `tools/decrypt.sh` for secret decryption) |
| `secrets/` | Gitignored local secrets — never committed |
| `.claude/agents/` | Agent definition files (`.md` with frontmatter) |
| `agents/<name>/learnings/` | Session learnings per agent, named `YYYY-MM-DD-<topic>.md` |
