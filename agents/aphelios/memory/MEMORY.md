# aphelios Memory

## 2026-04-19 — three-repo migration companion breakdown

Parallel partner to Kayn. Kayn owns strawberry-app (public code) task breakdown; I own strawberry-agents (private agent-infra). Azir's companion ADR at `plans/approved/2026-04-19-strawberry-agents-companion-migration.md` with D1-D10 decided.

My deliverables this session:
- `plans/in-progress/2026-04-19-strawberry-agents-companion-tasks.md` — 26 tasks, phases A0-A7 + A6 at T+90d.
- Amended `assessments/2026-04-18-migration-acceptance-gates.md` with 33 new AG-series / AGM-G gates.

Task-file shape I converged on (borrowed from Kayn to keep sibling plans isomorphic):
- Team composition section naming executors and explicit no-concurrent-repo discipline.
- D-prefix Duong-blocker table (used `D-agents-N` to avoid collision with Kayn's D1-D10).
- Per-task fields: Owner / Inputs / Outputs / Acceptance gate / Rollback / Blockers / Duong-in-loop.
- Dispatch-order section with critical-path diagram, parallel windows, hard-serial points, owner-concurrent schedule table.
- Acceptance-gate cross-reference table (task ID → gate IDs satisfied/fed).
- Rollback summary + open-items section.

Gate-numbering convention that keeps sibling plans clean: Kayn uses `P<phase>-G<n>` + `M-G<n>`; I used `A<phase>-G<n>` + `AGM-G<n>`. AGM-G10 (orphan sentinel) is the final cross-plan correctness gate.

Key coordination notes carried forward:
- `scripts/hooks/pre-commit-secrets-guard.sh` — strawberry-agents is source of truth; strawberry-app copies on hook refresh.
- `architecture/cross-repo-workflow.md` — canonical copy in strawberry-agents (three-repo version); may supersede a two-repo draft Kayn's P5.3 puts on strawberry first.
- Orphan-sentinel (A7) depends on Kayn's P6.1 purge landing first; realistic clock is cutover + 7-14 days.

Preferred cwd path (post-migration): agents run from `~/Documents/Personal/strawberry-agents/` once Phase A4 lands.
