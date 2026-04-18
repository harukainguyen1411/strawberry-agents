# Kayn — Portfolio v0 task breakdown

**Date:** 2026-04-19
**Output:** `plans/proposed/2026-04-19-portfolio-tracker-v0-tasks.md` (commit f2ec526)
**Source ADR:** `plans/approved/2026-04-19-portfolio-tracker.md` (b1abb28)
**Design spec:** `agents/neeko/learnings/2026-04-19-portfolio-v0-design.md`

## Shape of the breakdown

20 tasks (`V0.1`–`V0.20`). xfail-first per task (rule 12 — every impl
commit preceded on the same branch by an xfail commit referencing the
task ID, e.g. `Refs V0.4`). No implementer assignments (plan-writer
convention).

## Critical path

`V0.1 → V0.2 → V0.3 → (fan out) → V0.18 → V0.20`

After V0.3 (schema + rules), two parallel windows:
- **Window H** (handlers/CSV): V0.4 → V0.5 → V0.6 → V0.7 → V0.8.
- **Window U** (UI): V0.9 → (V0.10/V0.13/V0.14 parallel) → V0.11 → V0.12 → V0.15 → V0.16 → V0.17.

V0.19 (CI scoping for `tdd-gate.yml` + `e2e.yml` + pre-commit) is
independent — can land any time after V0.1. Joins at V0.18 (E2E).

## Key decisions

- **Per-user `baseCurrency` baked in from V0.3** — schema task makes it
  required at user-create time. `BaseCurrencyPicker` modal (V0.10) is
  undismissable per design spec §6.
- **`portfolio-tools/` ships as skeleton with stubs for v1+ tools** —
  every tool name from ADR §7 exports a function; non-v0 ones throw
  `NotImplementedError("v1")`. Surface-test (V0.4) enforces. This honors
  the tool-parity invariant from ADR §6.3 even at v0.
- **No adapter wiring at v0** — handlers imported directly. HTTPS callable
  / MCP / Gemini adapters are v1+ tasks per ADR §12. Only `importCsv`
  callable ships in v0 (V0.8).
- **Money native vs base** — Trade/Position storage is **native broker
  currency**; conversion happens at the handler layer (V0.5). Display
  follows design spec §6: avg cost native, market value + P/L base.
- **AccountSelector caveat** — flagged in V0.13 that v0 doesn't truly
  support cross-user view (Security Rules block it). If review pushes
  back, demote to "single-account v0" as `V0.13a`. Did not pre-decide.
- **CI scoping (V0.19)** — required to make rule 12 enforcement bite the
  new `apps/myapps/portfolio-tracker/**` path. Without it, xfail-first
  is honor-system for v0.

## Duong-blockers enumerated

DV0-1 firebase project ID, DV0-2 allowlist emails, DV0-3 T212 sample,
DV0-4 IB sample, DV0-7 exit sign-off. DV0-3/4 may slip without blocking
dev (synthetic fixtures OK during build) but must be replaced before
V0.20.

## Conventions reused from migration plan

- Task ID format `V0.<n>` (sub-letters allowed).
- Per-task fields: Goal / Inputs / Outputs / xfail-first / Acceptance.
- Strict spine + parallel windows + join point + final dispatch section.
- Out-of-scope confirmations section at the end (reviewer aid).

## What I would do differently next time

- Could have asked the team-lead whether the `mcp-portfolio` server stub
  (not the full server, just the package skeleton) belongs in v0 to lock
  the tool-parity scaffolding earlier. Punted to v2 per ADR §10. Worth
  confirming if Duong wants the stub in v0.
- The IB CSV format is gnarly enough that V0.7 could split into "parser"
  + "fixture & validation" if estimates blow past 1 day. Left as one
  task; flagging here as the most likely splitter.
