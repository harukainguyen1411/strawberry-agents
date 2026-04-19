# 2026-04-19 — PR #54 workflow hotfix review

## Context
Reviewed `chore/ci-release-preview-fixes` on `harukainguyen1411/strawberry-app` — two-line workflow-only fix (release.yml detached-HEAD + preview.yml turbo stale cache).

## Decision
Approved. Structural fixes are minimal and correct; `chore:` prefix is correct for workflow-only diff per Rule 5.

## Rule 13 ambiguity
Workflow-only infra bug fixes sit in a grey zone:
- Commit tagged `chore:` (not bug/bugfix/regression/hotfix) — pre-push hook likely doesn't trip.
- No product-code regression test makes sense; the "test" is the next CI run succeeding.
- Precedent: flag as drift note, suggest `Orianna-Bypass:` trailer only if the hook actually blocks.

## Pattern — turbo cache + secrets
`--force` is a valid stop-gap; the clean fix is `globalEnv` in `turbo.json` so secret values participate in the cache hash. Logged as a follow-up recommendation, not a blocker.

## Identity
`scripts/reviewer-auth.sh gh api user --jq .login` preflight returned `strawberry-reviewers` — approval accepted as non-self-review.
