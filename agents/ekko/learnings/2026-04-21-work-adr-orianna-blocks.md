# Learnings: Work ADR Orianna Signing — 2026-04-21

## Context

Task: sign the 4 work ADRs in `plans/proposed/work/` at phase `approved` using `scripts/orianna-sign.sh`.

## Outcome: All 4 blocked by Orianna

All 4 ADRs have `orianna_gate_version: 2` and `status: proposed`. The correct signing call
is `bash scripts/orianna-sign.sh <plan.md> approved` — the `approved` phase gate governs the
`proposed → approved` transition, and the script accepts `plans/proposed/work/` as the source
directory for that phase.

All 4 blocked at Step C (claim contract path verification). None had Step A/B/D failures.

### Common failure pattern

The work ADRs reference paths under `tools/demo-studio-v3/`, `company-os/…`, and
sibling plans without the `proposed/work/` prefix. Per contract §5, the `tools/` prefix
routes to the strawberry-agents repo — those paths fail `test -e` because the actual code
lives in `missmp/company-os` (the work workspace), not this repo.

### Per-ADR block counts

| File | Block findings |
|------|---------------|
| 2026-04-20-managed-agent-dashboard-tab.md | 7 |
| 2026-04-20-managed-agent-lifecycle.md | 20 |
| 2026-04-20-s1-s2-service-boundary.md | 21 |
| 2026-04-20-session-state-encapsulation.md | 29 |

### Fix options Orianna suggested (consistent across all 4)

1. Add `<!-- orianna: ok -->` suppression markers on lines citing cross-repo paths
   (`tools/demo-studio-v3/*`, `company-os/*`).
2. Correct companion-plan paths from bare `plans/2026-04-20-*.md` to
   `plans/proposed/work/2026-04-20-*.md`.
3. Extend `agents/orianna/claim-contract.md` §5 routing table to include a
   `company-os/` / `tools/demo-studio-v3/` → work-repo checkout entry.

Option 3 is the cleanest systemic fix — but it requires updating the contract (Orianna's
own definition) which is Sona/Orianna's lane, not Ekko's.

## Gate reports

All 4 gate reports written to `assessments/plan-fact-checks/`:
- `2026-04-20-managed-agent-dashboard-tab-2026-04-21T02-30-13Z.md`
- `2026-04-20-managed-agent-lifecycle-2026-04-21T02-35-23Z.md`
- `2026-04-20-s1-s2-service-boundary-2026-04-21T02-37-42Z.md`
- `2026-04-20-session-state-encapsulation-2026-04-21T02-41-02Z.md`

## PR merge blocker

PR #10 was authored by `Duongntd` (same identity as current gh session). Per Rule 18,
I cannot merge it. PR #7 depends on #10 merging first (its unit-tests failure was from
the workflow that #10 deletes; also has CONFLICTING merge state due to diverged main).
Duong must merge both via web UI as `harukainguyen1411`.

## Key learning

Work-concern ADRs that reference paths in `missmp/company-os` will always block Orianna's
`test -e` path checks until either:
(a) the claim contract is updated to route `company-os/` to a work-repo checkout, or
(b) cross-repo citations are suppressed with `<!-- orianna: ok -->`.

This is a systemic gap between how the work ADRs were authored (citing work-repo paths)
and how Orianna's contract was written (routing by path prefix to local checkouts).
