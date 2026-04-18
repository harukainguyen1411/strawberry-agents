# 2026-04-19 — strawberry-agents companion task breakdown

## Context
Parallel-partnered with Kayn on the three-repo migration. Kayn handled the strawberry-app (public code) breakdown; I took the strawberry-agents (private agent-infra) side. Source: `plans/approved/2026-04-19-strawberry-agents-companion-migration.md` (Azir's ADR with D1-D10 decided).

## Output
- `plans/in-progress/2026-04-19-strawberry-agents-companion-tasks.md` — 26 tasks across phases A0-A7 plus 90-day A6 archive event. Owner split: Ekko (A0, A1, A4 — history filter + local working-tree swap), Viktor (A2, A3, A5, A7 — reference rewrite + push/protect + doc update + orphan sentinel), Duong (A5.6 archive README + A6 90-day rename). No executor overlaps with Kayn's strawberry-app assignments at the same clock.
- Amended `assessments/2026-04-18-migration-acceptance-gates.md` with a new "strawberry-agents companion gates" section (AG-series + AGM-series, 33 gates total, brings combined checklist to 90 gates).

## Key design decisions
1. **Separate scratch clone is non-negotiable** (R-agents-5). `/tmp/strawberry-agents-filter.git` distinct from strawberry-app's `/tmp/strawberry-filter.git`. Both fetch `migration-base-2026-04-19` tag (tagged in A0.1 after Kayn's P0.3) to guarantee shared base SHA.
2. **History preserved via `--invert-paths`** — contrast with strawberry-app's orphan-branch squash. SHA rewrite is accepted (R-agents-1); mitigated by 90-day archive + MEMORY.md footer injection (A5.4).
3. **Orphan sentinel as final gate (AG7-G2)** — comm-based diff across base tree vs. app tree vs. agents tree vs. retired allowlist. This is the real "no duplicate, no loss" correctness check for the whole three-repo split. Depends on Kayn's P6.1 purge landing first (otherwise apps/dashboards show as duplicates).
4. **Archive README is a Duong task (A5.6)** — the pinned README on `Duongntd/strawberry` requires Duong's account write access and must land *before* A5.7 closes so the redirect is live when agent memory footers reference it.
5. **Serial discipline across executors** — Ekko finishes all strawberry-app Phase 4 work before starting A1 here; Viktor finishes all strawberry-app Phase 5/6 before A2/A3/A5. Neither agent runs concurrent sessions across repos.

## Coordination moves with Kayn
- `architecture/cross-repo-workflow.md` — Kayn's P5.3 may author a two-repo version on strawberry first; A5.3 either supersedes or extends to three-repo on strawberry-agents. Canonical copy lives in strawberry-agents per ADR §5 convention 9.
- MEMORY.md PR-link sweep — both plans do the same rewrite; A5.1 operates on the new strawberry-agents tree, Kayn's P5.1 operates on pre-split strawberry. Same output since base SHA is shared.
- `scripts/hooks/pre-commit-secrets-guard.sh` — strawberry-agents is source-of-truth (ADR §2.3). Dual-tracked byte-identity gate is AGM-G8 (supersedes M-G13 after both plans land).

## Risks and open items carried forward
- D10 `plan-frontmatter-lint` workflow deferred — branch protection lands with `required_status_checks: null` (AG3-G5 accepts both null and empty-contexts shapes).
- PAT scope: D-agents-2 expects the existing strawberry-app PAT extends to strawberry-agents; if GitHub fine-grained PATs can't be extended post-mint, Duong re-mints and Viktor re-encrypts.
- Retired-at-migration allowlist (A7.2's `retired.txt`) is finalized in-session at A7.1 runtime — expected < 10 entries from the ADR §2.2 cross-reference.

## For future sessions
- The gate-numbering convention (AG-series for phase gates, AGM-G for migration-complete cross-plan gates) gives me a clean way to mirror Caitlyn's P*/M-G* style while keeping the two plans' gate IDs orthogonal. Reusable pattern for any future multi-plan migration.
- Task-file structure I used: header with blockers summary + D-prefixed Duong-in-loop table + per-phase tasks (Owner/Inputs/Outputs/Acceptance gate/Rollback/Blockers/Duong-in-loop) + agent-assignment map + dispatch order with parallel windows + acceptance-gate cross-reference table + rollback summary + open-items section. Kayn's task file used the same shape; consistency across parallel plans matters.
