# Lissandra pre-compact ADR — breakdown + OQ resolution (2026-04-20)

## Context

Azir shipped `plans/proposed/personal/2026-04-20-lissandra-precompact-consolidator.md` (commit 741b22f). Kayn task: validate the §6 T1–T11 breakdown, resolve all 8 OQs (Duong authorized: "you decide all of them"), assign owners, and promote proposed → approved.

## What I changed

- Rewrote §6 as a tables-plus-prose structure: owner/depends/TDD columns, wave diagram, per-task detail paragraphs. Replaced Azir's bullet list.
- Renumbered task order to reflect true dependency graph (T10 "since-last-compact cleaner" deferred to phase 2 per Q3; T6/T7/T8 scaffolding moved earlier since they're all Yuumi and independent).
- Resolved all 8 OQs inline in §7 with `**Resolved: <decision>.**` preambles + 2–5 line rationale each.
- Updated §4.2 to record the Sona sharded-memory check (both `last-sessions/` and `sessions/` dirs confirmed to exist).
- Rewrote the §9 handoff footer.

## OQ resolutions (summary)

- Q1 budget: **6000** (Azir's rec).
- Q2 Sona sharding: **use sharded paths for both coordinators** — verified live.
- Q3 transcript excerpt: **defer to phase 2**, T10 retired from phase 1.
- Q4 opt-out sentinel: **repo root `.no-precompact-save`**.
- Q5 auto-compact: **Option A (allow silently)**.
- Q6 Lissandra memory: **stateless** (profile only, like Skarner).
- Q7 `/clear` hook: **out of scope** — follow-up ADR.
- Q8 block-and-prompt friction: **ship as-is**, revisit only on friction report.

## Owner assignments

| Task | Owner | Why |
|------|-------|-----|
| T1 (hook slot + xfail) | Ekko | Hook/devops-exec slot owner |
| T2 (agent def, .claude/agents/*.md) | Evelynn (top-level) | Subagent harness blocks that path |
| T3 (skill) | Jayce | New code under `.claude/skills/` |
| T4 (gate script + xfail) | Jayce | New script under `scripts/hooks/` |
| T5 (settings wiring) | Jayce | Connective tissue between T3/T4 |
| T6–T9 (scaffold, taxonomy, network, docs) | Yuumi | Errand-runner scope |
| T11 (E2E) | Vi | Test-executor scope |

## Promotion blocker

`bash scripts/plan-promote.sh ... approved` refused at the Orianna gate: `orianna_signature_approved` missing. Per §D6.1 of the Orianna-gated-lifecycle ADR and `architecture/plan-lifecycle.md`, only Orianna can sign (separate `claude` CLI invocation, Orianna's git identity, NO mechanical fallback). Kayn cannot substitute.

Evelynn must dispatch Orianna next with:
```
bash scripts/orianna-sign.sh plans/proposed/personal/2026-04-20-lissandra-precompact-consolidator.md approved
```
then re-run the promote.

## Patterns (re-usable)

- **Owner-column pattern**: when Azir's ADR lists tasks in §6 without owners, Kayn adds a one-row-per-task table (ID / task / owner / depends / TDD) before the per-task detail. Cuts dispatch friction.
- **Dependency wave diagram**: ASCII arrow diagram + named waves (Wave 1–4) beats prose ordering — the dispatcher can map waves to parallel spawns directly.
- **OQ resolution preamble**: every resolved OQ gets `**Resolved: <decision>.**` as the first phrase, then rationale. Scannable.
- **Promotion-blocked-on-signing handoff**: when Kayn can't complete the promote step because the Orianna gate needs a separate agent, hand off cleanly — don't try to mechanical-override the gate. Rule 19 forbids it anyway.
