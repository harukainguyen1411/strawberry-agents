---
slug: remove-memory-system-runbook-canonical
captured: 2026-04-27
captured_by: evelynn (relayed from Duong)
target_version: agent-network-v2
related_project: TBD
status: parked
---

# Idea: remove the memory + learnings system entirely; runbooks + system docs become the sole canonical truth

## Duong's framing (verbatim intent, lightly tidied)

> Make a major change to our system. Remove the memory system entirely. No memory, no
> learnings — for anyone, not even for the coordinator. Any learnings or feedback
> should go straight into an actionable plan if needed. The system and runbook is the
> canonical truth. We don't rely on memory/learnings to run, we rely on the system and
> runbook. The only thing we keep is: whenever a subagent finishes its job (or mid-task),
> they write a summary of what's done and a hand-off note, which gets appended into the
> plan itself so others can view it when they pick the work up.

## What this would replace

- `agents/<name>/memory/<name>.md` (per-agent persistent memory)
- `agents/<name>/memory/last-sessions/` (per-session handoff shards)
- `agents/<name>/memory/sessions/archive/` (rolled-up archives)
- `agents/<name>/learnings/YYYY-MM-DD-*.md` (per-session lessons)
- `agents/<name>/inbox/` (fire-and-forget cross-agent messages)
- `agents/memory/agent-network.md` and `agents/memory/duong.md` (shared memory shards)
- The memory-consolidation pipeline (`scripts/memory-consolidate.sh`,
  `Lissandra` agent, `/end-session` and `/end-subagent-session` skills' memory-write
  steps, `/pre-compact-save` skill, the PreCompact hook gate)
- The state-DB write helpers added in coordinator-memory-v1
  (`scripts/state/db-write-session.sh`, `db-write-learning.sh`,
  `capture-decision.sh`, `refresh-prs.sh` and siblings) — and by extension the
  whole `coordinator-memory-v1` ADR + downstream tasks T1-T12

## What stays

- `architecture/` — system docs, doctrine, contracts. **Sole canonical truth.**
- `runbooks/` — operational procedures. **Sole canonical truth.**
- `plans/` — actionable execution plans. The thing that **catches** "learnings" by
  way of becoming a new plan when a learning is actionable.
- Per-task **handoff notes appended to the plan itself** — written by each subagent
  at task completion (or mid-task pause). Future agents picking up the plan read the
  appended notes inline. This is the only persistence beyond the system + runbook layer.

## Mechanism sketch (low-fidelity, for v2 plan author)

- Plan files gain a `## Handoff log` section (or equivalent) at the bottom. Entries
  follow a fixed shape: `### YYYY-MM-DD HH:MM — <agent> — <task-id-or-stage>`,
  followed by short prose: what was done, what is left, gotchas, file paths to look at.
- `/end-subagent-session` (or its successor) appends one entry per subagent close,
  pointing at the plan in scope (subagents should always have a plan in scope).
- Coordinator close becomes a runbook update + plan handoff log entry, not a memory
  write. If the coordinator learned something durable, the action is "write a plan or
  amend a runbook" — never "write to memory".
- All `agents/<name>/memory/` and `agents/<name>/learnings/` directories deleted from
  the repo (or archived under `agents/<name>/_legacy-memory/` for read-only reference
  during transition).

## Rationale (Duong's read, my paraphrase)

- Memory + learnings drift. They accumulate stale claims that contradict the runbook.
  Two sources of truth means the canonical truth eventually loses.
- Memory + learnings are read-by-default at session start, which costs context and
  rewards verbosity. Runbook + plan are read on demand, which keeps context clean.
- "Actionable feedback" should change the system (runbook edit, plan edit) — not sit
  in a learnings shard waiting to be re-discovered. If a lesson can't be turned into
  a system or plan change, it is by definition not actionable and not worth keeping.
- Hand-off notes on the plan keep the per-task signal exactly where it's useful (next
  agent on the same plan) and nowhere it isn't (the global memory commons).

## Open questions for the v2 plan author

1. **Decision-capture system** (Duong's preferences.md, the `decision-capture` skill,
   `agents/<coordinator>/memory/decisions/log/`) — is that in scope for removal too,
   or does it survive as a separate calibration mechanism that isn't "memory" per se?
   Lean: in scope. The same drift critique applies.
2. **Runbook authoring discipline** — if runbook becomes sole canonical truth, runbook
   edits become higher-stakes. Do they need an Orianna-equivalent gate?
3. **Cross-session continuity** for long-running coordinator work — if memory is gone
   and the coordinator session compacts, what is the resume mechanism? Sketch: the
   coordinator's "memory" becomes the in-flight plan(s) and their handoff logs.
4. **Migration path** — what happens to the 18 months of accumulated learnings shards?
   Triage pass: each learning either (a) becomes a runbook/architecture edit, (b)
   becomes a plan in `plans/proposed/`, or (c) is archived as historical curio.
5. **Coordinator-memory-v1 ADR** is currently mid-implementation. If this idea
   graduates, that whole ADR + T1-T12 chain becomes a sunk-cost decision: continue,
   stop and revert, or stop and leave landed work as inert dead code? Lean: stop and
   revert, but only after this idea graduates from idea to plan.
6. **Inbox** — Duong's framing didn't mention it explicitly. Inbox is technically
   cross-agent communication, not memory, but it's adjacent. Probably in scope for
   removal: any cross-agent signal worth persisting goes into a plan handoff log
   entry the recipient will read when they next pick up that plan.

## Conflicts with currently-approved work

- `plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md` (just had
  amendments 2/3/4 land today). The whole ADR is predicated on memory being a thing
  worth investing in.
- `plans/approved/personal/2026-04-25-frontend-uiux-in-process.md` and other
  approved plans reference learnings as a routing input.
- `architecture/coordinator-decision-feedback.md` describes a system whose value
  proposition rests on persistent calibration data.
- `agents/<coordinator>/CLAUDE.md` startup chains read memory shards on every session.

These conflicts are NOT a reason against the idea — they're a reason the idea
needs a careful migration plan if it graduates. Captured here so the v2 author
sees the surface area up front.

## Status

**Idea-only. Do not graduate to a plan without an explicit Duong "make this real" instruction.**
