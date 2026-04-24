---
date: 2026-04-08
topic: Agent roster vs Windows-mode harness reality
context: Multiple routing failures during the cafe session that all traced back to the same root cause — assuming the conceptual roster matched the registered subagents
---

# The roster is theater; .claude/agents/ is reality

## What I learned

`agents/roster.md` and `agents/memory/agent-network.md` describe a 16+ champion roster for Strawberry. **In Windows Mode, only ~6 of those champions are actually wired to the harness as invokable subagents.** Available list at session time:

- `katarina` (Sonnet executor — quick tasks)
- `lissandra` (Sonnet PR reviewer)
- `syndra` (Opus planner — AI strategy)
- `swain` (Opus planner — architecture)
- `pyke` (Opus planner — git/security)
- `bard` (Opus planner — MCP/tools)
- Plus harness generics: `general-purpose`, `Explore`, `Plan`, `statusline-setup`, `claude-code-guide`

Champions in `roster.md` but NOT in `.claude/agents/`: **Ornn, Fiora, Shen, Caitlyn, Rek'Sai, Neeko, Zoe**, plus the unfinished minions (Poppy, Yuumi, Tibbers, etc).

When I "spawned Ornn" or "spawned Fiora" or "spawned Caitlyn" during this session, I was actually using `subagent_type: "general-purpose"` with a role-flavored brief. I was role-playing the routing rather than actually invoking distinct subagents. I didn't realize this until Poppy's `.claude/agents/poppy.md` was created and I tried to use her as `subagent_type: poppy` — and the harness rejected it with: *"Agent type 'poppy' not found. Available agents: general-purpose, statusline-setup, Explore, Plan, claude-code-guide, bard, katarina, lissandra, pyke, swain, syndra."*

## Why it matters

_Note: The harness-registration gap described here is fully resolved — the roster now has 20+ registered `.claude/agents/<name>.md` files. The "no parallel clones" / "only two executor slots" constraints below were Windows-mode-specific and no longer apply._

_The broader "never parallelize same agent" rule was also retired 2026-04-21. The dispatch criterion is task independence, not agent identity. See `agents/evelynn/learnings/2026-04-21-coordinator-parallelism-mandatory.md` (mirrored under `agents/sona/learnings/`)._

~~The "no parallel clones" rule (don't run two katarinas in parallel) needs a tighter formulation given this reality:~~

~~- Don't run two of `katarina`~~
~~- Don't run two of `general-purpose`~~
~~- Don't give two `general-purpose` agents the same brief shape — even if I label them as different champions internally, they're the same shape from the harness's perspective~~

~~I have effectively **TWO Sonnet executor slots:** `katarina` + `general-purpose`. For Sonnet parallelism, those are the only two distinct subagents I can spawn concurrently. Anything beyond that is either serialization or role-played duplication.~~

(Retired — harness now has a full registered roster; same-agent-type parallelism is permitted when tasks are independent.)

## Why this wasn't documented

The roster.md was written FIRST during the original Strawberry design. Mac mode uses iTerm windows + MCP `agent-manager`, which has its own mechanism — agents don't need `.claude/agents/` files to be invokable on Mac. Windows mode requires explicit `.claude/agents/<name>.md` files. The mismatch was invisible until I tried to invoke a champion by `subagent_type` and got an error, and even then I had to consciously notice that I'd been pretending to route for the whole session up to that point.

## How to apply

_Note: Items 1 and 3 below are retired — the roster gap is closed and the serialization rule no longer applies. Item 2 remains useful practice._

1. ~~**Before routing parallel work**, ask: *"Do I have two actual harness subagents whose domains match these tasks?"* If yes, spawn them. If no, **serialize** the work or accept that you'll be using `general-purpose` as a stand-in (which is fine — but only ONE general-purpose stand-in at a time, and tagged honestly in your reports).~~ _Retired 2026-04-21: dispatch is gated on task independence, not registered-agent count._
2. **When telling Duong what you're spawning**, name the actual `subagent_type` you're using. He should be able to verify against the available roster.
3. ~~**Treat the gap as a real problem to fix**: each champion in roster.md should have a corresponding `.claude/agents/<name>.md` for Windows mode parity.~~ _Resolved — roster is fully registered._

## How it surfaced

Duong called it out indirectly when he told me to use *"the sub-agent that you created"* (Poppy). I went to spawn her, hit the harness error, and only then realized the broader pattern: I'd been pretending to route for the whole session. The lesson didn't come from theory — it came from the harness saying no.
