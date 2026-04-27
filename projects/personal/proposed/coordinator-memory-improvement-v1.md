---
slug: coordinator-memory-improvement-v1
status: proposed
concern: personal
scope: [personal, work]
owner: duong
created: 2026-04-27
deadline: 2026-04-28
claude_budget: resourceful
tools_budget: limited
risk: medium
user: duong-only
focus_on:
  - reducing coordinator boot cost
  - canonical truth for status quo (no stale open-threads)
  - safe concurrent operation across multiple parallel coordinator sessions
less_focus_on:
  - Lissandra retirement and /pre-compact-save / /end-session rework (separate ADR)
  - cross-coordinator (Evelynn ↔ Sona) shared brain
  - CLAUDE.md / rules-layer optimization
related_plans: []
---

# Project: coordinator-memory-improvement-v1

## Goal

Improve how a coordinator (Evelynn, Sona) holds and recovers its working state so that:

1. Starting a coordinator session is cheap. Today it costs more than 100k tokens before any real work begins.
2. The view of "what is currently open" is always correct without anyone having to maintain it by hand.
3. Two or more sessions of the same coordinator can run at the same time without losing each other's writes or operating on stale state.

This is v1. We will iterate to v2 once we see how v1 behaves under real use.

## DoD

- A measured reduction in coordinator boot cost against a documented pre-project baseline.
- A canonical "open threads / status quo" view that stays correct after PRs merge, plans archive, and inbox messages land — without manual upkeep.
- Two parallel sessions of the same coordinator identity can run end-to-end without corrupting shared state.
- Existing static memory artifacts are either migrated into the new model or formally archived.
- The new model is the source of truth at boot.

## Constraints

- **Deadline:** Tuesday 2026-04-28.
- **Claude usage budget:** resourceful — boot cost is itself the metric this project is optimising.
- **Tools budget:** limited — prefer boring, free, well-supported primitives. No new cloud services or paid SaaS.
- **Risk:** medium — touches the boot path of every coordinator session; a regression here costs every future session until rolled back.

## Focus

- Boot cost reduction.
- Canonical truth for status quo.
- Safe concurrent operation.

## Less focus

- Lissandra retirement and the `/pre-compact-save` + `/end-session` rework — scheduled separately as their own ADR.
- Cross-coordinator shared brain (Evelynn and Sona seeing each other's state) — out of v1.
- Rules-layer / CLAUDE.md size — not optimised here.

## User

duong-only — single human operator. The two coordinator identities (Evelynn for personal, Sona for work) are the live consumers.
