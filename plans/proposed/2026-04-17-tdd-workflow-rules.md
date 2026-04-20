---
status: proposed
owner: pyke
date: 2026-04-17
title: TDD Workflow Rules — codified in CLAUDE.md and git hooks
---

# TDD Workflow Rules

Codify strict Test-Driven Development for the new test-dashboard service and all new services going forward. This plan specifies the **rules, enforcement mechanisms, file locations, bypass policies, and interactions** with existing strawberry invariants. Implementation (hook scripts, workflow YAML, PR template wording, branch protection config) is **out of scope** — that is Ekko's job once this plan is approved.

---

## 1. Scope

**In scope:**

- Six TDD rules covering test-first authoring, regression tests, pre-commit unit tests, PR-gated E2E, pre-PR QA agent verification, and post-deploy smoke tests with auto-rollback.
- The enforcement surface for each rule: git hook, GitHub Actions check, CLAUDE.md invariant, PR template section, or branch protection rule.
- Bypass policy for each rule — when a human (never an agent) may override, and the audit trail that must accompany it.
- Interaction with the existing strawberry invariants in `CLAUDE.md` (chore: prefix, no rebase, plan-promote.sh, `tools/decrypt.sh`, git worktree, plans-direct-to-main).

**Out of scope:**

- Writing the hook scripts or CI workflows (Ekko).
- Choosing the unit test framework, Playwright config, or design-diff tooling (separate plan; this one references them abstractly).
- Retrofitting existing services — rules apply to **new services** starting with the test-dashboard. Existing services are grandfathered until a separate migration plan lands.

---

## 2. Definitions

- **New service** — any app/package introduced after this plan is implemented. Detected by presence of a `tdd.enabled: true` marker in the package's `package.json` (or equivalent manifest). Services without the marker are exempt until migrated.
- **xfail test** — a test authored before implementation that asserts the desired behavior and is expected to fail on HEAD. Marked with the framework-native expected-failure annotation (e.g. `test.fail` in Playwright, `it.failing` in Vitest, `@pytest.mark.xfail` in pytest). Required to carry a comment `# xfail: <task-id-or-plan-path>` so auditors can trace it back.
- **Regression test** — a test that fails on the commit immediately before the bug fix and passes on the fix commit. Must name the bug in its description.
- **QA agent** — a Sonnet-tier agent (Akali or a successor) whose job is to run the full Playwright suite with video + screenshots and diff against the Figma design reference before PR open.
- **Smoke test** — a small, fast, read-only Playwright flow tagged `@smoke` that exercises the critical user journey of a surface.

---

## 3. The Six Rules

### Rule 1 — No task starts without an xfail test committed first

**Statement.** Any commit that introduces implementation for a new feature or task in a TDD-enabled service MUST be preceded on the same branch by an earlier commit that adds an xfail test for that task. The xfail test commit's message body must reference the plan path or task id.

**Enforcement mechanism.**
- **Pre-push hook** (client-side, in `scripts/hooks/pre-push-tdd.sh`) — for each TDD-enabled package touched on the branch, walks the commits being pushed and verifies that at least one commit in the branch's history contains an xfail test for the touched area. Blocks push on violation.
- **CI check** (`.github/workflows/tdd-gate.yml`, job `xfail-first`) — re-runs the same walk server-side so the rule cannot be skipped by `--no-verify`. This is the authoritative gate.
- **CLAUDE.md invariant** (new rule 12) — agents may not write implementation without first committing an xfail test.

**File/location.**
- Hook: `scripts/hooks/pre-push-tdd.sh` (wired via `core.hooksPath` or `scripts/install-hooks.sh`).
- CI: `.github/workflows/tdd-gate.yml`.
- Rule text: `CLAUDE.md` under **Critical Rules — Universal Invariants**, new item 12.

**Bypass policy.**
- Agents: **never**. No bypass flag in the hook, no `--no-verify` tolerance.
- Humans: only Duong, only by adding a top-level commit trailer `TDD-Waiver: <reason>` on the offending commit AND pushing with the branch-protection rule temporarily relaxed. Every waiver must be mentioned in the PR body. Waivers are CI-logged.
- Grandfathered packages (no `tdd.enabled: true` marker) are skipped entirely.

**Interaction with existing invariants.**
- Commits still use `chore:` / `ops:` prefix (rule 5). The xfail test commit is a `chore:` commit.
- No rebase (rule 11) — the branch retains the xfail-before-impl ordering naturally. If history needs to be cleaned up, use merge commits, not rebase.
- Plan files stay on `main` via `plan-promote.sh` (rule 7); the xfail-first rule applies only to implementation branches, not to plan-directory commits.

---

### Rule 2 — No bug fix lands without a regression test

**Statement.** Any commit whose message contains `bug` / `bugfix` / `regression` / `hotfix` tokens, or that closes a GitHub issue labelled `bug`, must include or be preceded by a commit that adds a regression test in the same branch.

**Enforcement mechanism.**
- **Pre-push hook** — same script as rule 1 extends with a `regression-test` check: classifies commits by message, and for each classified commit verifies a test file under the package's test tree was modified in the same branch.
- **CI check** (`tdd-gate.yml`, job `regression-test`) — authoritative server-side re-run.
- **PR template** — adds a checkbox **"Regression test linked: <path>"** that must be filled for any PR labelled `bug`.
- **CLAUDE.md invariant** (new rule 13).

**File/location.**
- Hook: shared `scripts/hooks/pre-push-tdd.sh`.
- CI: `.github/workflows/tdd-gate.yml`, `regression-test` job.
- PR template: `.github/pull_request_template.md`, new **Testing** section.
- Rule text: `CLAUDE.md` rule 13.

**Bypass policy.**
- Agents: never.
- Humans: Duong-only, same `TDD-Waiver:` trailer mechanism as rule 1. Waivers must cite why a regression test is infeasible (e.g. fix is a config-only change with no runtime branch).
- Trivial doc-only or typo-in-log-string fixes may use a `TDD-Trivial:` trailer that the hook recognises for `docs/` and `**/*.md` paths only.

**Interaction.**
- Still `chore:` prefix — the regression test does not change the commit prefix discipline.
- No rebase — regression test and fix stay as separate commits on the branch.

---

### Rule 3 — Pre-commit hook runs unit tests; blocks commit on failure

**Statement.** On every `git commit`, the pre-commit hook runs the **changed-package** unit test suite. Commit is blocked on failure.

**Enforcement mechanism.**
- **Pre-commit hook** (`scripts/hooks/pre-commit-unit-tests.sh`) — determines which TDD-enabled packages have staged changes (via `git diff --cached --name-only`), runs each package's unit test command (`package.json#scripts.test:unit` or equivalent), blocks on non-zero exit. Unchanged packages are not run — speed matters.
- Hooks are installed by `scripts/install-hooks.sh` (extend the existing installer). The hook is a **client-side** defence; the CI unit-test job is the authoritative gate (see rule 4 pipeline below).
- **CLAUDE.md invariant** (new rule 14).

**File/location.**
- Hook: `scripts/hooks/pre-commit-unit-tests.sh`.
- Installer: extend `scripts/install-hooks.sh` (which already installs the existing `age -d` / `chore:` enforcement hooks — rules 5, 6).
- Rule text: `CLAUDE.md` rule 14.

**Bypass policy.**
- Agents: never. Agents must not pass `--no-verify`. If the unit tests fail, the agent fixes the failure; agents never skip it.
- Humans: `--no-verify` is available but the corresponding CI job will still run on push and block the merge. The only way to land failing unit tests is a Duong-authored `TDD-Waiver:` trailer.
- WIP commits on non-TDD-enabled packages are unaffected (hook no-ops).

**Interaction.**
- Existing pre-commit hook already enforces rule 6 (no raw `age -d`, no plaintext secret reads) — the TDD hook is added **alongside**, not replacing it, and both must pass. The installer composes them.
- `chore:` prefix (rule 5) is unaffected — TDD hook does not care about commit messages.
- `git worktree` (rule 3 of CLAUDE.md) is compatible — the hook reads the staged diff of the current worktree.

---

### Rule 4 — PR creation triggers Playwright E2E via GitHub Actions; PR cannot merge red

**Statement.** Every PR to `main` runs the full Playwright E2E suite as a required GitHub Actions check. A red E2E check blocks merge via branch protection.

**Enforcement mechanism.**
- **GitHub Actions workflow** `.github/workflows/e2e.yml` — triggers on `pull_request` to `main`, runs Playwright against a preview deploy (or ephemeral Firebase emulator, depending on surface). Uploads traces, videos, and the HTML report as workflow artifacts.
- **Branch protection on `main`** — requires the `e2e` check to pass before merge. Configured via `gh api` in `scripts/setup-branch-protection.sh` (Ekko to author).
- **PR template** — links to artifact upload location and reminds the author to inspect before requesting review.
- **CLAUDE.md invariant** (new rule 15).

**File/location.**
- Workflow: `.github/workflows/e2e.yml`.
- Branch protection setup: `scripts/setup-branch-protection.sh`.
- Rule text: `CLAUDE.md` rule 15.

**Bypass policy.**
- Agents: never. Agents may not merge a PR with a red E2E check.
- Humans: Duong-only, admin override via GitHub's "merge without passing status" — which is logged in the repo audit log. No silent bypass.
- Flake policy: Playwright is configured with `retries: 2` on CI; a flake that needs a third retry is treated as a red build. Flake triage is a separate follow-up item, not a bypass.

**Interaction.**
- Plans-direct-to-main (rule 4 of CLAUDE.md) means **plan PRs do not exist** — plan commits go straight to main and the E2E workflow does not run for paths-under `plans/**`. The workflow `paths-ignore: [plans/**, architecture/**, assessments/**, agents/**]` keeps the rule scoped to code changes.
- `chore:` prefix (rule 5) is unaffected — E2E runs regardless of prefix.
- No rebase (rule 11) — merge commits preserve the green E2E SHA.

---

### Rule 5 — Before opening a PR, a QA agent must run full Playwright flow with video + screenshots and compare against design

**Statement.** For any PR touching UI surfaces of a TDD-enabled service, the author (human or agent) must have a QA agent run the full Playwright flow with **video and screenshots captured**, and produce a design-comparison report against the Figma reference. The report is posted as the first PR comment and linked in the PR body.

**Enforcement mechanism.**
- **PR template** — required section **"QA agent report"** with a link field. CI's `pr-body-linter` job (`.github/workflows/pr-lint.yml`) parses the PR body and blocks merge if the section is empty on UI-touching PRs.
- **CI job `qa-report-present`** — greps the PR body for the `QA-Report:` marker + a URL. Required for merge via branch protection.
- **QA agent contract** — the QA agent (Akali or successor) writes the report to `assessments/qa-reports/<pr-number>-<slug>.md`, including video artifact URLs (from the E2E workflow run), screenshot links, and a per-screen pass/fail table against the Figma frame IDs. The report is committed to `main` directly (like a plan) via `chore:` commit after the PR merges, or attached as a gist during review.
- **CLAUDE.md invariant** (new rule 16).

**File/location.**
- PR template: `.github/pull_request_template.md` (**QA Report** section).
- CI: `.github/workflows/pr-lint.yml`, job `qa-report-present`.
- Report storage: `assessments/qa-reports/`.
- Rule text: `CLAUDE.md` rule 16.

**Bypass policy.**
- Non-UI PRs (no changes under a service's UI path, e.g. `apps/*/src/**` for frontends): skipped automatically by the `paths` filter in `pr-lint.yml`.
- Backend-only PRs: skipped.
- Agents: never bypass on UI PRs.
- Humans: Duong-only, `QA-Waiver: <reason>` in PR body recognised by the linter.

**Interaction.**
- `plan-promote.sh` (rule 7) is unaffected — plan lifecycle changes are not PRs.
- Assessments directory (already used per CLAUDE.md file structure) is the correct home for these reports — consistent with existing conventions.
- QA agent model declaration (rule 9): the QA agent's `.claude/agents/<qa>.md` must declare `model: sonnet`.

---

### Rule 6 — Post-deploy smoke tests run on stg and prod; rollback on failure

**Statement.** After every deploy to staging and production, a `@smoke`-tagged Playwright subset runs against the live environment. On failure, the deploy workflow auto-reverts to the previous release.

**Enforcement mechanism.**
- **GitHub Actions workflow** — extend the deploy workflow (`.github/workflows/deploy.yml`, already specified by the deployment-pipeline ADR at `plans/proposed/2026-04-17-deployment-pipeline.md`) with two post-deploy steps:
  - `smoke-stg` — runs `@smoke` Playwright subset against the staging URL after the staging deploy step. Failure aborts promotion to prod.
  - `smoke-prod` — runs `@smoke` against prod after promotion. Failure triggers the rollback step (`scripts/deploy/rollback.sh` — to be authored per the deployment ADR's auto-revert requirement).
- **Alerting** — failure posts to the team's notification channel (mechanism TBD — follow-up plan).
- **CLAUDE.md invariant** (new rule 17).

**File/location.**
- Workflow: `.github/workflows/deploy.yml` (extends the deployment-pipeline ADR's spec — coordinate with Azir's plan at `plans/proposed/2026-04-17-deployment-pipeline.md`).
- Rollback script: `scripts/deploy/rollback.sh`.
- Smoke test tagging convention: documented in `architecture/testing.md` (to be created by Ekko).
- Rule text: `CLAUDE.md` rule 17.

**Bypass policy.**
- Never bypassed for production deploys. A prod deploy without a smoke check is, by definition, not a deploy.
- Staging smoke failures can be overridden by Duong with a `SMOKE-WAIVER:` environment variable passed into the workflow dispatch, but prod smoke failures always trigger rollback.

**Interaction.**
- Directly extends the deployment-pipeline ADR (`2026-04-17-deployment-pipeline.md`) — this rule is the TDD-side contract for the auto-revert requirement that ADR already specifies. The two plans must be implemented together; Ekko should read both before touching `deploy.yml`.
- `chore:` / `ops:` prefix (rule 5) unaffected — smoke runs on already-merged commits.
- No rebase (rule 11) — rollback is a new commit on main (a `ops:` revert commit), not a history rewrite.

---

## 4. CLAUDE.md Updates

Add the following to `CLAUDE.md` under **Critical Rules — Universal Invariants**, as items 12–17, without renumbering existing items:

```
12. **No task starts without an xfail test committed first** — for TDD-enabled services,
    any implementation commit must be preceded on the same branch by a commit adding
    an xfail test referencing the plan or task. Enforced by pre-push hook and CI
    (`tdd-gate.yml`). Agents may never bypass.

13. **No bug fix lands without a regression test** — commits tagged as bug/bugfix/
    regression/hotfix must include or be preceded by a regression test in the same
    branch. Enforced by pre-push hook, CI, and the PR template. Agents may never bypass.

14. **Pre-commit hook runs unit tests for changed packages; commit blocked on failure** —
    installed via `scripts/install-hooks.sh` alongside the secret-scanning and
    commit-prefix hooks. Agents may not pass `--no-verify`.

15. **PR creation triggers Playwright E2E; PR cannot merge red** — GitHub Actions
    `e2e.yml` runs on every PR to main; required check via branch protection.
    Agents may never merge a red PR.

16. **Before opening a UI PR, a QA agent must run the full Playwright flow with
    video + screenshots and diff against the Figma design** — report lives under
    `assessments/qa-reports/` and is linked in the PR body. Enforced by PR body
    linter. Non-UI PRs exempt.

17. **Post-deploy smoke tests run on stg and prod; rollback on prod failure** —
    extends the deployment pipeline workflow. Prod smoke failures trigger auto-
    revert via `scripts/deploy/rollback.sh`. No bypass for prod.
```

These additions leave rules 1–11 unchanged and preserve their numbering.

---

## 5. Implementation Order (for Ekko)

This plan does not assign implementers, but notes the natural ordering so Evelynn can sequence the follow-up work:

1. **Hook scripts first** — `pre-commit-unit-tests.sh`, `pre-push-tdd.sh`, `install-hooks.sh` extension. These have no external dependencies and can be built + dry-run locally.
2. **CLAUDE.md update** — land the new rules 12–17 after hooks exist but before CI is wired, so agents know the rules are in force.
3. **CI workflows** — `tdd-gate.yml`, `e2e.yml`, `pr-lint.yml`. Dependent on Playwright config existing in the test-dashboard repo.
4. **Branch protection** — `setup-branch-protection.sh` runs last and makes the CI checks actually blocking.
5. **Deploy-workflow extension (rule 6)** — coordinates with the deployment-pipeline ADR; lands together with that ADR's implementation.
6. **PR template** — `.github/pull_request_template.md` updated once the CI linter exists.
7. **QA agent definition** — `.claude/agents/<qa>.md` with `model: sonnet` and the full report-writing contract.

---

## 6. Open Questions

- **Unit test framework.** The test-dashboard service does not yet exist. This plan assumes Vitest for TS and the package-level `test:unit` script convention. If another framework is chosen, hook commands change but the rules do not.
- **Playwright preview environment.** E2E against preview Hosting deploys vs. ephemeral emulators — decision belongs to the deployment ADR (`2026-04-17-deployment-pipeline.md`). Rule 4 is agnostic.
- **Design diff tooling.** Rule 5's "diff against Figma" — pixel diff via Chromatic-style tooling, or agent-narrated comparison? Proposed default: agent-narrated, with raw screenshots attached; pixel tooling as a later upgrade.
- **Flake triage process.** Rule 4 explicitly declines to define this. Tracked as a follow-up plan.
- **Grandfathering marker.** `tdd.enabled: true` in `package.json` is the proposed marker. If a different registry is preferred (e.g. `architecture/tdd-enabled-services.md` list), the rules are unchanged; only the hook's detection function differs.

---

## 7. Non-goals

- Retrofitting existing services.
- Specifying coverage thresholds (a separate quality-metrics plan).
- Mutation testing, property testing, contract testing — future scope.
- Performance / load testing — not part of TDD gate.
