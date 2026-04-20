# PR #7 fidelity review — orianna work-concern repo routing

**Date:** 2026-04-21
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/7
**Plan:** `plans/in-progress/personal/2026-04-21-orianna-work-repo-routing.md`
**Verdict:** Approve with drift notes.

## Key observations

- All 4 plan tasks addressed with DoD met. TDD order verified at SHA level: xfail stub commit `7c233d4` touches only the new test file (23 LOC), then `ec3bdde` flips xfail → full 5-case runner in the same commit that adds impl. Clean Rule 12.
- `contract-version: 1` held steady per plan §Task 4 — correct; this is a compatible extension, not a breaking change.
- `route_path()` was refactored from two case arms (one for `apps/|dashboards/` and one for `.github/workflows/`, both hard-coding STRAWBERRY_APP) into one collapsed arm that toggles on `PLAN_CONCERN`. Semantically identical for non-work plans; cleaner than adding a second branch.
- LLM prompt (`plan-check.md`) and bash fallback now describe the same 2-branch routing with matching fetch / `test -e` / warn-finding shapes. The plan called this out explicitly (Task 3 DoD: "LLM and bash describe identical routing") and the implementation honors it.

## Drift observations (non-blocking)

The PR bundled two drive-by commits not named in the plan:

- `ops:` workflow `paths:` filters on ci.yml + preview.yml — defensive, prevents npm ci failures on infra-only PRs.
- `chore:` agents-table.md whitespace reformat — pure cosmetic.

Neither disclosed in PR body. Flagged as drift notes rather than blocking because neither touches the routing contract. Pattern to watch: agents bundling "while I'm here" fixes into feature PRs without splitting or disclosing. Future reviews should continue to surface this explicitly.

## Mechanics

- `scripts/reviewer-auth.sh gh api user --jq .login` → `strawberry-reviewers` ✓ (default lane, not Senna's `-2`).
- Review posted as APPROVED under `strawberry-reviewers` identity.
- Signed `— Lucian`.
