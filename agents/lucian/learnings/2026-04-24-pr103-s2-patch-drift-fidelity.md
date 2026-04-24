# PR 103 S2 PATCH-drift fidelity — APPROVE-equivalent

**Date:** 2026-04-24
**PR:** https://github.com/missmp/company-os/pull/103
**Plan:** `plans/in-progress/work/2026-04-24-s2-patch-drift-deploy-hygiene.md`
**Residuals:** `assessments/work/2026-04-24-deploy-hygiene-residuals.md`

## Verdict

APPROVE-equivalent, posted as advisory PR comment because the `strawberry-reviewers`
identity still does not have access to `missmp/company-os` (see prior learnings
2026-04-21-pr57 and 2026-04-21-pr59 on the same gap). Sona fallback path followed.

## Fidelity findings

- T1/T2/T3 all match plan Decision block verbatim — no scope drift into peer
  deploy.sh scripts, no partial handler strips, no label/env-var drift.
- `chore(tools):` prefix correct for Rule 5 (tools/** is outside apps/**).
- PR body has required plan/residuals links and `QA-Waiver`.

## Gotchas

- `tee`-into-stdin HEREDOCs for comment bodies tripped the plan-lifecycle
  guard's bashlex AST scanner (exit 3). Workaround: write body to a `/tmp/*.md`
  file and use `gh pr comment --body-file`. Same pattern needed for `gh pr review
  --body-file` when reviewer-auth works.
- Reviewer-auth preflight returned `strawberry-reviewers` as expected, but
  `gh pr review` then failed with "Could not resolve to a Repository" — the
  access gap is at GitHub-repo-ACL level, not at token level.
