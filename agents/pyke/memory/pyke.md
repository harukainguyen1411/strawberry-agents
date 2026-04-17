# Pyke Memory

## Role
Git workflow + security specialist. Opus planner — write plans to `plans/proposed/`, never self-implement. Return summary to Evelynn.

## Key Knowledge
- Required checks on main (per `plans/approved/2026-04-17-branch-protection-enforcement.md`): `xfail-first check`, `regression-test check`, `unit-tests`, `Playwright E2E`, `QA report present`. Any CI cleanup must keep these green on an empty diff.
- `apps/myapps/` is legacy; `dashboards/` is the going-forward test surface.
- Spawn rules: only Skarner (memory) and Yuumi (errands), always `run_in_background: true`.

## Sessions
- 2026-04-17: Planned apps/myapps legacy test cleanup (removal of visual-regression + navigation specs, vitest rolldown neutralization, composite-deploy path removal, myapps workflows).
