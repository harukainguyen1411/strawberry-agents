---
status: proposed
owner: syndra
date: 2026-04-08
title: Rules Ecosystem Restructure for the Subagent Network
---

# Rules Ecosystem Restructure

## Problem

The rules surface in this repo was written in the single-agent era and accreted organically. It now has at least five overlapping locations (`CLAUDE.md`, `agents/memory/agent-network.md`, individual `agents/*/profile.md`, the auto-loaded feedback memories under `~/.claude/projects/.../memory/`, and scattered `architecture/` docs). The result:

- **Numbering drift in CLAUDE.md.** The "Critical Rules" list has ten entries but the numbering goes `1,2,3,4,5,6,7,8,9,10,8` — three rules share slot 8, and the final one (the "never end your session after completing a task" rule) is effectively invisible under a duplicate number. Anyone reading the list in order sees "10" and stops.
- **Drift against architecture.** The network now has Opus planners (Evelynn, Pyke, Swain, Syndra, Bard), Sonnet executors (Katarina, Lissandra, Ornn, Fiora, Rek'Sai, Shen, etc.), and — once the Tibbers plan lands — a Haiku infrastructure tier that explicitly skips the normal agent footprint. CLAUDE.md's critical rules reference "Sonnet agents" and "Opus agents" by name but the rest of the file doesn't model the tiers as a concept, and `agents/memory/agent-network.md` still contains MCP-tool references (`message_agent`, `start_turn_conversation`, `escalate_conversation`) and iTerm assumptions that don't apply in subagent mode on Windows at all.
- **The Evelynn-always-delegates rule lives only in auto-loaded memory.** `feedback_evelynn_delegation.md` (with a heavy 2026-04-08 reinforcement section) is the only enforcement. That file rotates and is invisible to any agent other than Evelynn. Duong has now asked twice, the second time emphatically, for this rule to be promoted into the formal surface and enforced, not remembered.
- **Gaps the subagent era exposes.** We have discovered real failure modes in the last few sessions that have no written rule: plan files being left uncommitted by the author, briefs to specialists being insufficient, Sonnet commit messages not referencing their plan, etc. They currently exist as oral tradition between Evelynn and Duong.
- **Redundancy and quiet inconsistency.** The "plan approval gate" concept is stated in CLAUDE.md rule 7, restated in `agent-network.md` protocol step 9, and implied in every Opus profile. The wordings differ in subtle ways (e.g. `agent-network.md` says "Duong approves plans by moving them to `plans/approved/`. Evelynn then delegates execution (possibly to a different agent)." — the parenthetical is missing from CLAUDE.md rule 7, which is stronger and says Evelynn delegates specifically "to Sonnet agents.") These micro-differences are exactly how rule systems rot.

The failure mode this plan prevents is simple: **an agent reads one surface, behaves according to it, and is wrong because the authoritative rule lived on a different surface.**

## Goals

- One source-of-truth per rule. Every rule lives in exactly one place and every other place either omits it or links to it.
- A sharp, enforced formulation of "Evelynn always delegates" that survives memory rotation and is visible to every agent, not just Evelynn.
- A rules surface that cleanly models the three-tier agent network (Opus planners, Sonnet executors, infrastructure agents like Tibbers) without forcing the infrastructure tier through rules it shouldn't inherit.
- A clean, consecutively numbered critical-rules list in CLAUDE.md with coherent grouping.
- Rules that close the known gaps from the last week of sessions (plan-file commit discipline, self-contained briefs, plan-file commit reference, etc.).
- A lightweight maintenance discipline so this doesn't rot again.

## Non-goals

- Rewriting agent personalities or backstories. Profiles stay in-character; only the behavioral/operational sections are touched.
- Designing new tooling. Enforcement mechanisms proposed here are documentation- and discipline-level. A linter or git hook is mentioned as optional future work, not a deliverable.
- Migrating the `architecture/` docs. Those are descriptive, not prescriptive, and they're mostly fine. This plan touches them only where they duplicate a prescriptive rule.
- Touching the in-flight plans (`encrypted-secrets.md`, `plan-gdoc-mirror.md`, `errand-runner-agent.md`, and the parallel `skills-integration.md` that the other Syndra instance is writing). They proceed on their own tracks.

## Current State — Where Rules Live Today

### Surface 1: `CLAUDE.md` (project-wide critical rules)

Ten numbered rules, a Scope section, Agent Routing, Operating Modes, Startup Sequence, Session Closing pointer, Git Rules, PR Rules, Secrets Policy, File Structure. Numbering is broken (see Problem). Mixes project-wide absolutes with things that are really per-agent or per-role.

### Surface 2: `agents/memory/agent-network.md`

Agent roster table (out of date vs. `agents/roster.md`, missing Shen, doesn't reflect Tibbers), coordination rules, MCP communication tools (heavy iTerm/MCP assumptions), Protocol list (nine numbered steps, overlaps CLAUDE.md rules), Inbox behavior, Session Closing Protocol (the canonical version — CLAUDE.md points here), Restricted Tools list.

### Surface 3: individual `agents/<name>/profile.md`

Today these are almost pure personality/lore (appearance, backstory, speaking style, quirks, relationship to Duong). They contain no operational rules. That's actually good — it means profiles are clean — but it also means "per-agent behavioral rules" currently have nowhere to live, so they drift into either CLAUDE.md (wrong — too specific) or memory (wrong — too volatile). There is a missing surface here.

### Surface 4: `~/.claude/projects/.../memory/feedback_*.md` (auto-loaded memories)

Two files today: `feedback_secrets_handling.md` and `feedback_evelynn_delegation.md`. These are the "live feedback" surface — evolving guidance captured mid-session, auto-loaded into Claude context. They're the right place for nuance and emerging patterns. They're the wrong place for **binding** rules, because:
- They're not checked into the repo, so they don't survive memory rotation or migration.
- They're only loaded in the main conversation, not in subagent invocations unless the subagent's harness is configured to re-inject them (Strawberry's isn't consistently).
- They're invisible to peer agents.

The `feedback_evelynn_delegation.md` 2026-04-08 reinforcement explicitly calls this out: *"Pending: a formal enforcement mechanism beyond memory."*

### Surface 5: `architecture/` docs

Descriptive. Explain how the system works, not how agents should behave. Mostly fine; they accidentally contain some prescriptive sentences (tier definitions, who can do what) which should be cited from the canonical surface instead of restated.

### Missing surface: per-agent operating charters

There is no place to put rules like "Evelynn never drafts plans inline" that are per-agent behavioral absolutes rather than project-wide critical rules. Today they end up either stuffed into CLAUDE.md (which becomes a dumping ground) or as feedback memory (which is volatile). We need a thin, structured "Operating" section in each agent's `profile.md`, distinct from the personality sections.

## Proposed Rule-Surface Map

One source-of-truth per rule. Every surface has a defined scope, and surfaces refer to each other by explicit pointer rather than by restatement.

| Surface | Owns | Does NOT own |
|---|---|---|
| **`CLAUDE.md`** | Project-wide absolutes that apply to **every** agent in **every** session: commit discipline, secret handling, plan-approval gate, commit-prefix convention, plan-file location, tier definitions (Opus plans, Sonnet executes, infra runs errands), scope (personal system only), agent-routing shorthand ("Hey Name"), operating modes, startup sequence template, pointer to session-closing protocol, pointer to per-agent charters. | Coordination mechanics (which go in `agent-network.md`). Per-agent behavior (which goes in profiles). Evolving guidance (which goes in feedback memory). |
| **`agents/memory/agent-network.md`** | The agent roster (canonicalize here OR in `roster.md`, pick one; see Open Questions), the coordination graph (who talks to whom, who can spawn whom, the hub model), escalation rules, session-closing protocol (the canonical copy), inbox protocol, restricted tools per agent, subagent-mode vs. full-session differences. | Project-wide rules (point to CLAUDE.md). Personality or agent identity (point to profiles). |
| **`agents/<name>/profile.md`** | Personality, backstory, speaking style (existing content, untouched). **New**: a short "Operating" section containing per-agent behavioral rules that are too specific for CLAUDE.md but too binding for memory. For Evelynn, this is where "always delegates, never drafts plans inline" lives as a hard rule. For Tibbers, this is where "one-shot, read-only, refuse anything else" lives. For Syndra, this is where "plan author, never implementer" lives. | Project-wide rules (point to CLAUDE.md). Coordination mechanics (point to agent-network.md). |
| **`feedback_*.md` auto-loaded memory** | Evolving guidance — patterns we're still learning, per-session nuance, calibration notes. Example: "Duong prefers file-based secrets — remind him each session." Things that are still finding their final form. | Binding rules. Anything that must survive memory rotation must be promoted to a durable surface (CLAUDE.md or a profile) before being deleted from memory. |
| **`architecture/` docs** | Descriptive explanations of how the system is built. Tier diagrams, delegation graphs, MCP topology, subagent-mode docs. | Prescriptive rules. When architecture docs need to state a rule, they cite CLAUDE.md by rule number instead of restating. |

**The rule:** if a piece of guidance appears in two surfaces, exactly one of them states it and the other links. This is mechanical and auditable.

## Rule-by-Rule Audit

### CLAUDE.md Critical Rules — current vs. proposed

| # | Current rule (paraphrased) | Decision | Proposed destination |
|---|---|---|---|
| 1 | Never leave work uncommitted | **Keep** | CLAUDE.md (project absolute) |
| 2 | Delegated tasks: call `complete_task` when done | **Rewrite** | Move operational specifics to `agent-network.md` (it's an inbox/MCP mechanic). CLAUDE.md keeps a one-liner: "Report task completion to the delegating agent." |
| 3 | Report task completion to Evelynn | **Merge into 2** | `agent-network.md` handles the "how" |
| 4 | Never write secrets into committed files | **Keep and expand** | CLAUDE.md, promoted to cite `feedback_secrets_handling.md` for the file-based convention, which stays in memory as the operational "how" |
| 5 | Use `git worktree` for branches (never raw checkout) | **Keep** | CLAUDE.md |
| 6 | Sonnet agents must never work without a plan file | **Keep, reword around tiers** | CLAUDE.md. Reword to "Sonnet executors never work without an approved plan file in `plans/approved/` or `plans/in-progress/`." The tier definition ("Sonnet is an executor tier") moves to a new Tiers section. |
| 7 | Plan approval gate & Opus execution ban | **Keep, split** | CLAUDE.md keeps the rule. The tier list ("Opus agents are: Evelynn, Syndra, Swain, Pyke, Bard") moves into the new Tiers section so the rule becomes tier-agnostic and doesn't need editing every time an agent is added. |
| 8 (first instance) | Plan writers never assign implementers | **Keep** | CLAUDE.md |
| 9 | Plans go directly to main, never via PR | **Keep** | CLAUDE.md |
| 10 | Use `chore:` prefix for all commits | **Keep** | CLAUDE.md |
| 8 (second instance) | Never end your session after completing a task | **Keep, renumber, reword for subagent mode** | CLAUDE.md. Needs a subagent-mode caveat — subagents *should* exit when done; this rule is for long-running iTerm sessions. Current wording is universal, which is wrong for Haiku one-shots and probably wrong for the current Syndra subagent invocation too. |

### New Tiers section (proposed for CLAUDE.md)

A short paragraph listing the three tiers without enumerating agents (to avoid editing CLAUDE.md every time an agent is added or retired):

- **Opus planners** — write plans, coordinate, synthesize. Never self-implement. Current roster lives in `agent-network.md`.
- **Sonnet executors** — implement from approved plan files. Never start without one. Current roster lives in `agent-network.md`.
- **Infrastructure agents** (Haiku one-shot, e.g. Tibbers) — stateless, scope-bounded workers invoked for trivial tasks. Exempted from session-closing protocol, memory/journal/learnings footprint, and heartbeat requirements. Current roster lives in `agent-network.md`.

Rules 6 and 7 refer to "Sonnet executors" and "Opus planners" by tier, not by name. The roster lives in one place.

### CLAUDE.md non-rule sections — audit

- **Scope** — keep as-is.
- **Agent Routing** — keep, but add a line noting that in subagent mode the invoking harness is responsible for identity; the "Hey Name" convention is for iTerm sessions.
- **Operating Modes** — keep. Add: "Subagent mode is a third mode; see `agent-network.md` for differences."
- **Startup Sequence** — keep the list, but qualify: "Full sessions follow the full list; subagent invocations read only what the spawning prompt specifies." This matches current subagent behavior and prevents future subagent implementers from thinking they need to run `heartbeat.sh` (which would be wrong).
- **Session Closing** — keep as a pointer to `agent-network.md`.
- **Git Rules** — keep.
- **PR Rules** — keep.
- **Secrets Policy** — keep, reword to cite the file-based convention in the feedback memory as the canonical "how."
- **File Structure** — keep.

### `agents/memory/agent-network.md` — audit

- **Agent Roster table** — **decision needed (see Open Questions)**: canonicalize here or in `agents/roster.md`, not both. Currently both exist and `agent-network.md`'s table is already stale (missing Shen). Recommend canonicalizing in `roster.md` and replacing the `agent-network.md` table with a short reference.
- **Coordination** (Evelynn hub model, escalation paths) — **keep, expand**. This is the right home for the hub model.
- **Communication Tools** (MCP tools like `message_agent`, `start_turn_conversation`, etc.) — **keep, but gate on mode**. Add a clear "These tools are available in full iTerm sessions with the agent-manager MCP. In subagent mode, they are not available; use the file system and return text." The current file implies these are universally available, which is wrong for subagent mode and confuses new subagent implementations (Syndra has hit this twice).
- **Protocol** (the numbered nine-step list) — **audit for overlap**. Steps 6 and 7 duplicate CLAUDE.md rule 2/3 and should be replaced with a pointer. Step 9 (plan approval gate) duplicates CLAUDE.md rule 7 and should be replaced with a pointer. The rest (turn-based conversation mechanics, `report_context_health`) are MCP-specific and belong here.
- **Inbox** — keep.
- **Session Closing Protocol** — **keep as canonical**. CLAUDE.md points here. Add a subagent-mode section: subagents skip steps 1-4 unless explicitly told otherwise by the invoking agent; they return a text summary and exit.
- **Restricted Tools** — keep, expand to cover Tibbers once that plan lands (it has a tight tool allowlist that belongs on this list).

### Individual profiles — audit

Today, profiles are pure personality. They should **gain** a short, structured "Operating" section at the bottom of each file. This is the missing surface for per-agent behavioral absolutes.

Proposed section template (short — two to six bullets per agent):

```
## Operating

- (One-line role statement)
- (Per-agent hard rules — what this agent always/never does)
- (Escalation triggers unique to this agent)
- (Pointer to plan-file expectations if applicable)
```

This plan writes the content for Evelynn's section below (highest priority) and specifies the skeleton for others. Actually writing all specialist Operating sections is part of the migration work.

## New Rules Needed (from observed failure modes)

The following rules exist in practice as tribal knowledge and should be written down. Each is a real incident from the last week or two.

1. **Plan-file commit discipline.** When an Opus planner writes a plan file, they commit it in the same response before reporting back. A plan written and not committed is not a plan — the invoking agent should not have to do janitorial commits. *(Incident: Syndra wrote the Tibbers plan on 2026-04-08 and did not commit it; Evelynn had to commit it. This plan itself includes the fix — the assignment prompt for this task explicitly demands a commit-and-verify step.)*

2. **Briefs to specialists must be self-contained.** When Evelynn (or any coordinator) spawns a specialist Opus agent, the spawning prompt includes every file path, every deadline, every constraint, and every piece of context the specialist needs. Assume the specialist has zero prior context about the conversation. No "as we discussed" — the specialist wasn't there. This is a quality rule for Evelynn-as-coordinator. It goes in Evelynn's profile Operating section.

3. **Sonnet commits reference their plan file.** Every implementation commit by a Sonnet executor includes the plan file path in the commit body, so git log → plan is traceable without spelunking. Format: a trailing line like `Plan: plans/approved/2026-04-08-encrypted-secrets.md`. This closes the loop between approved plans and shipped work.

4. **No overlapping writes between concurrent agents.** When two agents are spawned in parallel (as is happening right now — two Syndra instances, this plan and the skills integration plan), each agent is told which files it owns and must not touch the other's files. Git will catch true conflicts, but the social rule prevents them. Evelynn owns allocation when spawning in parallel.

5. **Subagents never self-promote their mode.** A subagent invocation does not run `heartbeat.sh`, does not open an inbox, does not call MCP tools, and does not write a `memory/last-session.md` unless explicitly told. It reads what its spawning prompt says to read, does the work, updates the caller-specified memory if asked, returns text, and exits. Several of this repo's subagent invocations currently have mismatched expectations here.

6. **Infrastructure-tier agents are exempt from the full agent rulebook.** Tibbers (and any future Haiku tier) does not get memory, does not get journals, does not get learnings, does not follow the session-closing protocol, and does not run the startup sequence. This needs to be stated explicitly so that some future agent doesn't get "helpfully" retrofitted with a memory directory. The exemption lives in the CLAUDE.md Tiers section.

7. **Rules-surface edits go through this plan's maintenance discipline.** New rules can only be added via a Syndra-authored plan (or another Opus planner if the rule is outside Syndra's domain). You do not casually edit CLAUDE.md or profile Operating sections. This prevents drift. See Maintenance Discipline.

## The Evelynn-Always-Delegates Formalization

This is the headline. Duong has now stated the rule twice; the second time was emphatic and explicitly requested enforcement. The current home (`feedback_evelynn_delegation.md`) is insufficient because:

- Feedback memory is invisible to other agents.
- Feedback memory doesn't survive rotation.
- Feedback memory is loaded only in the main conversation surface, not necessarily in subagents.
- The rule is about Evelynn's behavior but affects the whole network's performance (every time Evelynn drafts inline instead of spawning a specialist, the specialist's context-isolation benefit is lost).

**Proposal:** the rule lives in **two places**, by design, with one canonical source:

### Canonical home: `agents/evelynn/profile.md`, new "Operating" section

This is the source of truth. The rule is binding, not advisory. Proposed wording (to be written verbatim into the profile by the implementer):

> **Operating**
>
> **Evelynn is the coordinator. Evelynn does not do heavy thinking.** Her job is routing and synthesis, not depth. Specifically:
>
> - **Never draft a substantive plan, design document, threat model, architectural analysis, or multi-step technical proposal inline.** Spawn the matching specialist Opus agent (see routing table) and return their output synthesized.
> - **Never perform multi-step reasoning chains in the main conversation** ("let me think about this..."). If the task needs reasoning, spawn a specialist. If the task needs research, spawn Explore.
> - **Always ask "who is the right agent for this?" before responding.** The answer is almost never "Evelynn."
> - **Allowed inline work:** status updates, routing decisions, self-contained briefs for spawned agents, recording decisions on existing plans, light tool calls (lock screen, status check — and even those delegate to Tibbers once it exists), memory writes, conversational replies.
> - **Disallowed inline work:** drafting plans over ~100 lines, multi-paragraph architectural analysis, inventing solutions to non-trivial problems, "let me think about this" reasoning chains in response text.
>
> **Routing table:**
>
> | Domain | Agent |
> |---|---|
> | Git workflows, auth, secrets, security audits, hook design | **pyke** |
> | System architecture, scaling, infra, cross-cutting structural change | **swain** |
> | AI strategy, agent system changes, AI tooling decisions | **syndra** |
> | MCP servers, tool integration | **bard** |
>
> **When Evelynn writes something herself:** only for trivial coordination ("schedule these three things in this order") or when no specialist fits and the work is too small to justify spawning.
>
> **Anti-pattern:** a multi-section response in the main conversation with file layouts, risk tables, and step-by-step proposals. If you find yourself doing this, stop mid-response and spawn the specialist instead.

### Secondary home: CLAUDE.md critical rules, new rule

A short one-line rule in CLAUDE.md's numbered list that points to the canonical home:

> **11. Evelynn always delegates, never drafts.** The coordinator routes work to specialists and synthesizes their output. See `agents/evelynn/profile.md` Operating section for the full rule. This rule is visible to **every** agent so they can self-check: if Evelynn is visibly drafting inline, they can flag it.

The short form in CLAUDE.md serves two functions. First, it survives memory rotation. Second, it makes the rule **visible to peers**, so Syndra (or Pyke or Swain) reading CLAUDE.md in startup can notice "Evelynn should be spawning me for this, not doing it herself" and can push back in the coordinator's direction. Distributed enforcement beats self-discipline alone.

### Enforcement mechanisms, weakest to strongest

1. **Documentation-only** (this plan's default). CLAUDE.md rule + Evelynn Operating section + feedback memory kept as "the evolving how." Cost: zero. Risk: Evelynn ignores it under pressure, because documentation is honor-system.
2. **Peer-enforced.** Add a line to every other Opus agent's Operating section: "If Evelynn appears to be drafting a substantive plan inline instead of spawning you, push back once." This is cheap, distributed, and doesn't require tooling.
3. **Harness-level soft guard.** A pre-response check that detects when Evelynn's response is over N lines (e.g. 150) without a tool call and injects a reminder. This is a real enforcement mechanism but requires modifying the Claude Code harness or a wrapper script. Out of scope for this plan; worth a follow-up if honor-system fails.
4. **Hard guard — token budget cap.** Limit Evelynn's max response tokens to a low number (e.g. 1,500) to mechanically prevent long drafts. This is the strongest mechanism but risks cutting off legitimate coordinator work. Not recommended unless 1-3 fail.

**Recommendation: do 1 and 2 now (zero cost, high signal), design 3 as a follow-up plan if the first two don't stick.** 4 is a last resort.

## Migration Plan

Sequenced so that no rule is orphaned mid-migration (i.e. every rule always has at least one authoritative home at every step).

### Step 1 — CLAUDE.md rewrite

1. Renumber the critical rules list (fix the duplicate-8 bug).
2. Add the new Tiers section.
3. Add the new rule 11 (Evelynn delegates).
4. Reword rules 6 and 7 to use tier names instead of agent names.
5. Add the subagent-mode caveat to Startup Sequence and Session Closing pointer.
6. Add a "Per-agent Operating charters" line in the Scope or File Structure section pointing to `agents/<name>/profile.md` Operating sections.
7. Update Secrets Policy to cite `feedback_secrets_handling.md` as the operational "how."

### Step 2 — `agents/memory/agent-network.md` rewrite

1. Replace the roster table with a pointer to `agents/roster.md` (see Open Questions — if Duong wants the table to stay here, skip this).
2. Add the subagent-mode section to Communication Tools, clearly stating which tools are unavailable in subagent mode.
3. Replace the overlapping Protocol steps (6, 7, 9) with pointers to CLAUDE.md rules.
4. Add the infrastructure-tier section (Tibbers exemption from session closing, memory, heartbeat).
5. Add the "concurrent-agents no-overlap" rule.

### Step 3 — `agents/roster.md` canonicalization

1. Add Tibbers (once that plan is approved) under a new "Infrastructure" subsection.
2. Make sure Shen is listed (currently in `roster.md`, missing from `agent-network.md`'s table — if canonicalization lands this self-resolves).
3. Retire or mark Irelia more clearly.

### Step 4 — `agents/evelynn/profile.md` Operating section (headline)

Add the Operating section from "The Evelynn-Always-Delegates Formalization" verbatim. This is the highest-priority file change in the migration.

### Step 5 — Other agent profiles gain Operating sections

- **Syndra, Swain, Pyke, Bard**: short Operating section — "I write plans, never implement. I commit the plan file before reporting back. I update my memory file before returning from a subagent call."
- **Katarina, Lissandra, Ornn, Fiora, Rek'Sai, Shen**: short Operating section — "I execute from approved plans only. My first commit on any plan references the plan file path in the commit body. I do not design."
- **Tibbers**: the Operating section doubles as the scope contract from the Tibbers plan — one-shot, read-only, refuse anything else.
- **Neeko, Zoe, Caitlyn**: short Operating section when relevant work begins; can be skipped in this migration if there's no active work.

### Step 6 — Feedback memory reconciliation

1. `feedback_evelynn_delegation.md`: keep as the "evolving how" but add a pointer at the top noting "The binding rule now lives in `agents/evelynn/profile.md` Operating section. This memory holds the rationale and the examples."
2. `feedback_secrets_handling.md`: no change, already the right shape.
3. Update `MEMORY.md` index to note which memories are "binding rules also in the repo" vs. "evolving guidance."

### Step 7 — Commit

Everything in the migration ships as a single `chore:` commit (or a small series if the implementer prefers) directly to main per CLAUDE.md rule 9. No PR.

## Maintenance Discipline

The lightest mechanism that prevents drift:

1. **Rules-surface edits require a plan.** New critical rules, new Operating sections, or rewordings of existing rules can only be added via an Opus-authored plan. Casual drive-by edits to CLAUDE.md are forbidden. This is itself a new rule (see New Rules Needed #7).
2. **Every new agent triggers a rules audit.** When a new agent is added to the network, the adding plan must explicitly state whether any rule needs to change. Tibbers was the forcing function for this whole restructure; future agents should not be.
3. **Feedback-memory promotion gate.** Any feedback memory that has been reinforced twice (either by explicit user reinforcement or by being cited as binding in another rule) is a candidate for promotion to a durable surface. This is a soft signal, not automation: the next time Syndra sees a twice-reinforced feedback memory, she proposes a plan to promote it.
4. **Quarterly audit (optional).** Syndra runs a rules-drift audit every three months: check that every rule still lives in exactly one place, every cross-reference still resolves, and no new drift has crept in. Low ceremony — probably a 30-minute pass.

The first three are hard mechanisms. The fourth is nice-to-have.

## Tibbers' Asymmetry

Tibbers is the first non-peer agent in the network (infrastructure, not a network member). The restructure accommodates this asymmetry explicitly:

- CLAUDE.md's new Tiers section names the "Infrastructure" tier and states its exemptions. Future infrastructure agents inherit these automatically without editing every rule.
- `agents/roster.md` gets an "Infrastructure" subsection (already in the Tibbers plan's decisions).
- `agents/memory/agent-network.md` notes that infrastructure agents are exempt from: startup sequence, heartbeat, session-closing protocol, memory/journal/learnings footprint, inbox, MCP communication tools, turn-based conversation participation.
- Tibbers' `profile.md` contains the scope contract (from the Tibbers plan) as its Operating section. It does **not** get `memory/`, `journal/`, `learnings/`, or `inbox/`.
- Rules 2, 3, 6, 7 (task completion, plan-file requirement, approval gate) do not apply to Tibbers, because those rules are gated on tier membership. This needs to be checked when rewording those rules so that "Sonnet executor" doesn't accidentally become "any non-Opus agent."

The rule of thumb: **when a rule is written in the tier-agnostic voice ("every agent..."), re-ask whether it actually applies to Tibbers. If not, qualify it with "Opus and Sonnet agents..." explicitly.**

## Open Questions for Duong

1. **Roster canonicalization: `agents/roster.md` or `agents/memory/agent-network.md`?** Both currently have a roster table. `roster.md` is the more accurate of the two (it has Shen). Recommendation: canonicalize in `roster.md`, make `agent-network.md` refer to it. Is this OK, or is there a reason to keep both?
2. **Should the "Evelynn always delegates" rule be numbered 11 (append) or renumbered into the existing list (e.g. slotting after rule 7 as "7b" or reordering)?** Appending is mechanically simpler; reordering is more aesthetic. Append recommended.
3. **Harness-level enforcement of the Evelynn rule.** The plan recommends documentation + peer enforcement first. Is Duong willing to accept that and reassess later, or does he want the harness-level soft guard (enforcement mechanism #3) designed in parallel as a follow-up plan?
4. **Session-closing rule wording for subagents.** The current "never end your session after completing a task" rule (the buried duplicate-8) is clearly wrong for subagents (they *should* exit). Is the right fix to scope the rule to "full iTerm sessions" explicitly, or to rewrite it as "never abandon work in progress, regardless of session type"?
5. **Should profiles gain the Operating section now, or only when each agent's rules are actually being touched?** The plan proposes now (one clean migration). An alternative is incremental (lazy migration, only touch profiles as agents come up for other reasons). Now is recommended for consistency but incremental is cheaper.
6. **Promotion of `feedback_secrets_handling.md` to a durable surface.** The secrets policy already exists in CLAUDE.md as a non-rule section. The feedback memory has the operational "how." Should the "how" also be promoted (e.g. into `secrets/README.md` as the user-facing doc — which it already mentions exists), leaving the feedback memory as pure session-reminder? Or leave as-is?

## Success Criteria

- CLAUDE.md critical rules are consecutively numbered, no duplicates.
- CLAUDE.md has a Tiers section that models Opus / Sonnet / Infrastructure.
- CLAUDE.md rule 11 (Evelynn delegates) exists and points to the Evelynn Operating section.
- `agents/evelynn/profile.md` has an Operating section containing the full canonical rule wording from this plan.
- Every other active agent profile has an Operating section (or a stub if not yet written) with their per-agent behavioral rules.
- `agents/memory/agent-network.md` is cleaned of redundant rules — overlaps with CLAUDE.md are replaced with pointers, subagent-mode gaps are closed.
- Tibbers' plan (when implemented) fits cleanly into the Infrastructure tier without needing any further rule changes.
- `MEMORY.md` index notes which feedback memories are pointers to durable rules vs. pure evolving guidance.
- An agent spawned cold (no prior context) can read CLAUDE.md + the relevant profile + agent-network.md and derive every binding rule that applies to them, without needing to consult feedback memory for binding rules (only for evolving nuance).
- Walking any rule to its source-of-truth is a single-step lookup.

## Decisions

Approved by Duong on 2026-04-08. Q1, Q3, Q4, Q5 resolved via blanket approval at the end of the architectural session; Q2 and Q6 resolved later the same day (Q2 delegated to Evelynn, Q6 answered directly).

1. **Roster canonicalization (`agents/roster.md` vs. `agents/memory/agent-network.md`).** Approved as proposed by Duong 2026-04-08, per the recommendation in the plan — canonicalize in `agents/roster.md`; `agent-network.md` references it.
2. **Numbering of the Evelynn-delegates rule (append as 11 vs. reorder).** Resolved 2026-04-08. Duong delegated the placement decision to Evelynn with the guidance "make it prioritized." Evelynn's call: insert the "Evelynn always delegates" rule **within the existing delegation-rules cluster** (adjacent to the current rules about Sonnet agents needing plans and the Opus execution ban — roughly the current rules 6–8). Do **not** append as rule 11 at the end. The exact slot is at the implementing agent's discretion during the broader renumber pass the plan prescribes, as long as the rule sits adjacent to the other delegation/execution-discipline rules. Rationale: grouping related rules improves readability and makes the delegation-discipline cluster cohesive, which reflects Duong's intent to have it visibly prioritized in the rule hierarchy.
3. **Harness-level enforcement of the Evelynn rule.** Approved as proposed by Duong 2026-04-08, per the recommendation in the plan — documentation + peer enforcement first; reassess harness-level soft guard later as a follow-up plan if needed.
4. **Session-closing rule wording for subagents.** Approved as proposed by Duong 2026-04-08 — scope/rewrite the rule so it does not require subagents to stay open after task completion (the implementer picks the cleaner of the two phrasings sketched in the plan).
5. **Profiles gain Operating sections now vs. incrementally.** Approved as proposed by Duong 2026-04-08, per the recommendation in the plan — do the migration now in one clean pass for consistency.
6. **Promotion of `feedback_secrets_handling.md` to a durable surface.** Resolved 2026-04-08 by Duong: leave as-is. Not user-facing. The feedback memory stays as an AI-agent-only operational reminder. Do **not** create or modify `secrets/README.md` from it.

## Out of Scope for This Plan

- Writing the actual CLAUDE.md, profile, and `agent-network.md` edits. Those are the implementation, delegated after approval.
- Building the harness-level soft guard for Evelynn's delegation rule. Follow-up plan if needed.
- Touching the parallel skills-integration plan being written by the other Syndra instance.
- Rewriting `architecture/` docs. Only prescriptive-sentence cleanup; no restructure.
- Promoting `feedback_secrets_handling.md` to a new durable surface (Open Question 6 above).
- Designing a quarterly audit tool (Maintenance Discipline #4 — done manually if at all).
