---
slug: coordinator-memory-improvement-v1
status: proposed
concern: personal
scope: [personal, work]
owner: duong
created: 2026-04-27
deadline: TBD
claude_budget: resourceful
tools_budget: limited
risk: medium
user: duong-only
focus_on:
  - boot cost reduction (memory layer)
  - canonical truth for status quo (no stale memory-based open-threads)
  - safe concurrent access from multiple parallel coordinator sessions
less_focus_on:
  - Lissandra retirement and /pre-compact-save / /end-session rework (separate ADR)
  - cross-coordinator (Evelynn ↔ Sona) shared brain (out of v1)
  - CLAUDE.md / rules-layer optimization (separate effort, may feed v2)
related_plans: []
---

# Project: coordinator-memory-improvement-v1

## Goal

Replace the current static-text-file coordinator memory model (giant `evelynn.md` / `sona.md`, hand-maintained `open-threads.md`, scattered shards) with a queryable local-database model so that:

1. Coordinator boot cost drops from >100k tokens to a target we'll set after measurement.
2. The "what's open right now" view is canonical and derived from ground truth (PRs, plans, projects, inbox, tasks) instead of a memory file that goes stale.
3. Multiple parallel sessions of the same coordinator (e.g. two Evelynn CLIs) can read and write coordinator state safely without lost updates or split-brain.

This is v1. We will iterate to v2 once we see how v1 behaves under real use.

## DoD

- A working local-database memory store that the coordinator boots from, with measured boot-cost reduction against the pre-project baseline.
- A canonical "open threads / status quo" view derived from the database, not from a hand-maintained text file. View is correct after PRs merge, plans archive, etc., without manual upkeep.
- Two parallel coordinator sessions of the same identity can run end-to-end without corrupting shared state, demonstrated by an explicit dual-session smoke test.
- Migration of existing static memory files into the new model (or formal archival of files that no longer feed live state).
- Old static memory files no longer read at boot.

## Constraints

- **Deadline:** TBD — Duong will set after the first sub-plan (measurement + ADR) lands.
- **Claude usage budget:** resourceful — boot cost is itself the metric this project is optimising, so iteration is expected.
- **Tools budget:** limited — prefer boring, free, well-supported primitives (e.g. SQLite). No new cloud services or paid SaaS.
- **Risk:** medium — touches the boot path of every coordinator session; a regression here costs every future session until rolled back. Migration is a hard cutover, accepted; old files remain in git history.

## Focus

- **Boot cost reduction** — measure first, then design. Lazy-load patterns where possible.
- **Canonical truth** — status-quo view is derived, not authored. PRs, plans, projects, inbox, tasks are the ground-truth sources.
- **Safe concurrent access** — assume two or more coordinator sessions of the same identity may run at the same time. OS-level file locking on the local DB is the baseline primitive.

## Less focus

- Lissandra retirement and the `/pre-compact-save` + `/end-session` rework — those are scheduled separately as their own ADR.
- Cross-coordinator shared brain (Evelynn and Sona seeing each other's state in the same DB) — explicitly out of v1; coordinators stay in separate stores.
- Rules-layer / CLAUDE.md size — measured as part of the baseline but not optimised here.

## User

duong-only — single human operator. The two coordinator identities (Evelynn for personal, Sona for work) are the live consumers.
