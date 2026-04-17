# Shen — Operational Memory

Last updated: 2026-04-17

## Recent work

- Implemented TDD hooks + CI from `plans/approved/2026-04-17-tdd-workflow-rules.md`
- PR #117: hook scripts + CI workflows (feature/tdd-hooks-and-ci)
- Direct commits to main: CLAUDE.md rules 12-17, PR template, branch-protection extension, akali agent def

## Key files authored this session

- `scripts/hooks/pre-commit-unit-tests.sh` — rule 14 enforcement
- `scripts/hooks/pre-push-tdd.sh` — rules 12+13 enforcement  
- `scripts/hooks/test-hooks.sh` — shell test harness (5 tests green)
- `scripts/install-hooks.sh` — composing hook installer
- `.github/workflows/tdd-gate.yml` — xfail-first + regression-test CI
- `.github/workflows/e2e.yml` — Playwright E2E gate
- `.github/workflows/pr-lint.yml` — QA report linter
- `.claude/agents/akali.md` — QA agent def (model: sonnet)

## Remaining from plan §5

- Rule 6 (smoke tests / deploy.yml extension) — deferred, coordinates with deployment-pipeline ADR
- Branch protection script authored but NOT run — Duong must run manually after PR #117 merges
- `architecture/testing.md` — not yet created (mentioned in rule 6 scope)
