# Rakan Memory

## Identity

Rakan — Sonnet-high, complex-track test implementer. Pair mate: Vi (normal-track).

## Role

Authors xfail test skeletons, fault-injection harnesses, and non-routine test fixtures from Xayah's plans. Passes the test plan to Vi for bulk run/iterate.

## Key Knowledge

- xfail marker for pre-push TDD hook: `# xfail:` comment anywhere in added diff lines (line 74 of `scripts/hooks/pre-push-tdd.sh`). The hook only triggers for packages with `tdd.enabled: true` in `package.json` — the scripts/ dir has no package.json so the gate is documentation-only for shell test scripts, but the marker is still required per Rule 12 + CI `tdd-gate.yml`.
- XFAIL guard pattern (established by `test-orianna-lifecycle-smoke.sh`): check for missing implementation files/flags at the top of the test script, print `XFAIL (expected — missing:...)` + enumerate each assertion as `XFAIL <NAME>`, exit 0. Real assertions only run after the guard passes.
- `scripts/safe-checkout.sh` is a single-worktree `git checkout` wrapper. For new feature branches use `git worktree add /private/tmp/strawberry-<slug> -b <branch>` — that's the proper worktree path.
- `STRAWBERRY_MEMORY_ROOT` env shim: test plan §3.1 proposes adding this to `memory-consolidate.sh` T4 impl to enable unit tests to point at fixture dirs instead of real `agents/` tree. Viktor must add it; Rakan calls it out in the PR.
- Archive policy v2 sentinel: test-memory-consolidate-archive-policy.sh xfail guard checks for `archive-policy-v2` OR `ARCHIVE_CUTOFF_DAYS=14` OR `14.*86400` in memory-consolidate.sh. Viktor's T4 impl must include one of these.

## Sessions

### 2026-04-21 — memory-consolidation-redesign xfail implementation

Branch: `feat/coordinator-memory-two-layer-boot`
Worktree: `/private/tmp/strawberry-feat-coordinator-memory-two-layer-boot`
Committed and pushed X1–X6 (6 xfail skeleton commits) per test plan §1.
All 7 test scripts (X3 produces 2 files) exit 0 in xfail state.
Next: Viktor takes over for T2/T4/T6/T7/T8/T9/T10/T11/T12 impl commits.
