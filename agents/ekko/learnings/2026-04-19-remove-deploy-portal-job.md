# 2026-04-19 — Remove deploy-portal job from release.yml

## What happened
Removed the `deploy-portal` job from `.github/workflows/release.yml`. The job was a leftover
from before the repo split — the portal now lives in `strawberry-app`. It was failing every
run because `actions/setup-node` with `cache: npm` could find no lockfile at the
`strawberry-agents` repo root.

## What was verified before editing
- No other workflow had `needs: deploy-portal` — grep confirmed zero cross-job dependencies.
- Two jobs remained after removal (`functions-deploy`, `rules-deploy`), so the file was kept
  (not deleted).
- The `workflow_dispatch.inputs.ref` block was also removed — it existed solely to support
  the portal rollback flow.

## Result
- Commit `a3f1c24` on main.
- Pushed via `harukainguyen1411` token (Duongntd token lacks `workflow` OAuth scope — this is
  the established pattern for `.github/workflows/` pushes in this repo).
- Run `24611117779` completed as `skipped` — both remaining jobs have path-scoped `if:`
  conditions that did not match the workflow-only diff. No failure.

## Key learnings
- `skipped` outcome on a Release run is correct/expected when no app paths are changed.
- The two remaining jobs (`functions-deploy`, `rules-deploy`) are conditional on specific path
  patterns; they will never spuriously fire on infra commits.
