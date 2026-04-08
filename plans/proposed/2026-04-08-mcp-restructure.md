---
status: proposed
owner: bard
created: 2026-04-08
title: MCP Restructure — Reclassify Project MCPs as Skills, Rules, or External-Integration MCPs
---

# MCP Restructure

> Rough plan. Problems, shape, tradeoffs, open questions. No diffs, no step-by-step. A detailed execution spec comes later per phase, after Duong approves.
>
> **Rule 7 applies.** Bard wrote this. No self-implementation. Implementer assignment is Evelynn's call after approval.

## Context — why now

Duong audited the project-level MCPs showing up in his `/mcp` dialog (`agent-manager`, `evelynn`) and flagged that neither is really an MCP. The claude-code-guide specialist then researched Claude Code best practices and audited both servers. The finding was clean enough to act on:

- `agent-manager` is pure local coordination over `agents/`, inbox files, and iTerm config. Zero external systems. It was reached-for reflexively because "tool integration = MCP" in this repo's habit.
- `evelynn` is three concerns crammed into one process:
  1. **Local agent control + state** (`shutdown_all_agents`, `commit_agent_state_to_main`, `restart_evelynn`) — local git + filesystem, no external surface.
  2. **Telegram** — legitimately external (Telegram API), legitimately MCP-shaped.
  3. **Firestore task board** (`task_list`, `task_create`, `task_update`, `task_delete`, `task_changes`) — legitimately external and stateful, legitimately MCP-shaped.
- `evelynn` also has an honor-system "sender" field where the server trusts caller-supplied identity. That smell disappears the moment local coordination moves into a skill, because the skill runs inside the caller's own context — identity is intrinsic, not self-reported.

This plan inherits from two approved sister plans and must not re-litigate them:

- `plans/approved/2026-04-08-skills-integration.md` — established `.claude/skills/<name>/SKILL.md` format, four scopes, preload pattern, decision matrix, and the skill ↔ subagent interaction model. Everything skill-format-shaped in this plan defers to it.
- `plans/in-progress/2026-04-08-end-session-skill-phase-1.md` — Katarina is currently shipping `/end-session` + `/end-subagent-session`. The `agent-lifecycle` work in Phase 2 of this plan must cross-reference rather than duplicate.

## 1. The governing invariant

**Project MCPs are only for external system integration. Local coordination, state management, and procedural discipline belong in skills, CLAUDE.md rules, and shell scripts.**

Restated as a decision tree (compact form from the claude-code-guide research, mapping to the five tool categories in this repo):

1. **Does the tool talk to an external system over the network or a third-party API?**
   - Yes → candidate MCP. Continue to 2.
   - No → NOT an MCP. Skip to 4.
2. **Is the external integration stateful, long-lived, or protocol-heavy (OAuth, websockets, persistent session)?**
   - Yes → MCP is the right shape.
   - No → could be a script + skill instead (see 5). Prefer that if the API is a simple HTTP call.
3. **Does the caller need natural-language input, refusal discipline, or a discoverable entry point?**
   - Yes → wrap the MCP in a skill for the entry point. The skill is the UX, the MCP is the engine.
   - No → raw MCP is fine.
4. **Is the action procedural — a playbook the caller follows — or a convention the caller should always apply?**
   - Procedural and called often → **skill** (possibly `context: fork` if it needs isolation).
   - Always-on convention / policy → **CLAUDE.md rule**.
   - Lifecycle event the harness can fire automatically → **hook**.
5. **Is the action deterministic with no judgment required?**
   - Yes → **shell script** (optionally wrapped by a skill for discoverability).
   - No → back to 4.

Five output categories: **MCP**, **MCP-wrapped-by-skill**, **skill**, **rule**, **script/hook**.

Going forward every new tool addition must pass this tree. If nothing above category 1 returns "yes," the feature does not become an MCP, full stop. This is the governing lens for the two migrations below and for anything future.

## 2. agent-manager migration (Phase 1)

`agent-manager` has five clusters of functionality. Each cluster maps to a different category.

### 2.1 What the server does today

From `mcps/agent-manager/` (retired, see v2 §3.2):

- `list_agents()` / `get_agent(name)` (retired, see v2 §3.2) — scans `agents/*/` for metadata.
- `create_agent(...)` (retired, see v2 §3.2) — scaffolds `agents/<name>/{profile.md,memory/,journal/,learnings/,inbox/}` plus an iTerm profile.
- `launch_agent(name, task)` (retired, see v2 §3.2) — spawns an agent in a new iTerm window at a grid position.
- `message_agent(name, message, ...)` (retired, see v2 §3.2) — writes an inbox file + triggers an iTerm notification.
- Grid positioning / iTerm profile helpers.
- Turn-based conversations, delegations, health registry, context-health reporting (read the full tool list from `mcps/agent-manager/server.py` during detailed phase — this rough plan captures the structural shape, not the exhaustive inventory).

### 2.2 Proposed restructure by cluster

| Cluster | Shape | Landing spot |
|---|---|---|
| **Agent metadata lookup** (`list_agents`, `get_agent` — retired, see v2 §3.2) | Rule + script | A concise CLAUDE.md section "Agent Roster" pointing at `agents/memory/agent-network.md` (already exists) plus a `scripts/list-agents.sh` that reads the filesystem. No LLM judgment needed — deterministic. |
| **Agent creation** (`create_agent` — retired, see v2 §3.2) | Skill wrapping a script | `/new-agent <name>` skill with `allowed-tools: Bash Write`. The skill handles natural-language input ("create an agent named X who specializes in Y"), scaffolds the dirs by calling `scripts/new-agent.sh`, and stops short of anything iTerm-specific. iTerm profile generation splits into a macOS-only step. |
| **Agent launch** (`launch_agent` — retired, see v2 §3.2) | macOS-only shell script | `scripts/launch-agent-iterm.sh` (macOS only). Not under Claude's control on Windows. Windows mode has no iTerm; Windows mode uses subagents (`Task` tool) instead, and that path does not go through `agent-manager` anyway. |
| **Agent messaging** (`message_agent` — retired, see v2 §3.2, inbox writes) | Skill (`agent-ops`) | `/agent-ops send <agent> <message>` — a project skill at `.claude/skills/agent-ops/SKILL.md`. Wraps inbox file writes. No MCP process needed; the skill has `allowed-tools: Write Read Bash` and does the work inline in the caller's context. Inherits identity intrinsically. |
| **Turn-based conversations, delegations, health registry, context-health** | Mixed | Needs per-tool analysis in the detailed phase. First pass: turn-based conversations and delegations are local state (JSON files under `agents/conversations/`, `agents/delegations/`), so they become scripts + a `/delegate` and `/converse` skill. Health registry is already partly in `agents/health/heartbeat.sh`; keep the script, add a thin `/health` skill that reads the registry. |
| **iTerm grid positioning** | Delete from Claude's surface | Pure macOS window management. Lives as a bash helper invoked by `scripts/launch-agent-iterm.sh`. Claude never calls it directly. |

### 2.3 What happens to `mcps/agent-manager/`

Two options, open question for Duong (§8):

- **(a) Archive-in-place** — leave the directory, remove the `.mcp.json` registration, drop a `README.md` at `mcps/agent-manager/README.md` stating "superseded by `/agent-ops`, `scripts/new-agent.sh`, and CLAUDE.md Agent Roster section. See `plans/implemented/2026-04-08-mcp-restructure.md`." Reversible. Keeps the Python source around as reference while the skills settle in.
- **(b) Delete the directory in the same commit that lands the skills.** Cleaner but harder to revert.

Recommendation: **(a) for Phase 1, with (b) scheduled in Phase 3 cleanup** once two weeks of use confirm the skills cover every workflow the MCP used to cover.

### 2.4 Call-site updates

Every agent profile and every plan currently mentioning `list_agents`, `message_agent`, `launch_agent`, `start_turn_conversation`, `delegate_task`, `check_delegations`, `complete_task`, etc. (all retired, see v2 §3.2), needs updating — these tool names are referenced across `agents/memory/agent-network.md`, most agent profiles, and several plans. The detailed phase enumerates the grep. Rough-plan shape: a single sweep replaces MCP tool calls with skill invocations or script calls, all in one commit so no agent is left pointing at a dead tool mid-migration.

**Ordering constraint:** call sites MUST be updated in the same commit that removes the MCP registration. Otherwise agents will try to call missing tools and fail. This is a mandatory failure-mode guard (see §7).

## 3. evelynn three-way split (Phase 2)

Bigger, messier. The `evelynn` MCP at `mcps/evelynn/server.py` (~700 lines) has three clearly separable concerns.

### 3.1 Concern A — local agent control + state → `agent-lifecycle` skill + CLAUDE.md rules

Tools in scope:

- `shutdown_all_agents(sender, exclude?)` — iterates agents, requests graceful shutdown, confirm-gated.
- `commit_agent_state_to_main(sender)` — stages any dirty agent state files and commits to main. Pure local git.
- `restart_evelynn()` — iTerm-based restart of Evelynn's window. macOS-only, already unreliable (per Bard's memory, always returns "uncertain").

Proposed landing:

- **`/agent-lifecycle shutdown-all [--exclude <name>]`** — a project skill. Allowed tools: `Bash Read Write`. Body contains the confirm-gate prose and the shutdown loop. Runs in caller's context so "only Evelynn can call this" becomes a skill-level discipline rule (the skill body refuses if `$CALLER != evelynn`), or — better — a CLAUDE.md rule plus a hook.
- **`/agent-lifecycle commit-state`** — wraps the git add + commit sequence. `allowed-tools: Bash`. Pre-commit hook already enforces `chore:` prefix, so this just wraps the sequence.
- **`restart_evelynn`** — **delete this capability entirely**. It never worked reliably, it's macOS-iTerm-specific, and in subagent mode (Windows) there is no "restart Evelynn" — a new subagent is just a new subagent. If it turns out Duong still wants a macOS-only restart helper, that becomes a standalone `scripts/restart-evelynn-iterm.sh` with no Claude-side surface. Open question §8.

**CLAUDE.md rules added** (declarative, not procedural):

- "Only Evelynn invokes `/agent-lifecycle shutdown-all`."
- "State-commit happens before any session close that touched agent state." (This partly overlaps with `/end-session` Step 8 — see §4.)

### 3.2 Concern B — Telegram → stays MCP (or becomes a plugin skill)

Tools: `telegram_send_message`, `telegram_poll_messages`.

This is the clearest "stays MCP" case. Telegram Bot API is stateful (webhook or long-poll), needs a persistent token, and the marketplace plugin exists (`claude-plugins-official/telegram`) with a skill interface already built.

Two sub-options:

- **(a) Keep bespoke evelynn-telegram MCP**, refactored into a cleaner `mcps/telegram/` directory, stripped of all the local-coordination tools. Preserves the exact behavior the repo's Windows-mode bridge relies on (`scripts/start-telegram.sh`, `scripts/telegram-bridge.sh`).
- **(b) Adopt the `claude-plugins-official/telegram` plugin skill**, retire the bespoke MCP. Simpler long-term, but the bespoke bridge has inbox-driven semantics that may not map cleanly. The skills-integration plan already flagged this as "defer to Bard to evaluate."

Recommendation: **(a) for Phase 2, (b) evaluated in Phase 3** after a proof-of-concept with the plugin in a scratch repo. Switching is a one-commit change once the plugin is proven equivalent.

### 3.3 Concern C — Firestore task board → stays MCP

Tools: `task_list`, `task_create`, `task_update`, `task_delete`, `task_changes`.

Legitimately external (Google Cloud Firestore), legitimately stateful (subscription-based changes stream). Stays MCP. Refactors into `mcps/task-board/` (or whatever name Duong prefers — open question §8).

The one design question here: is there a marketplace plugin that subsumes it? The skills-integration plan inventoried the marketplace and listed `firebase` and `supabase` plugins — `firebase` likely covers Firestore but may be Realtime-DB-flavored. Worth a quick check in Phase 2 before building a bespoke refactor. If the plugin covers the five task-board operations cleanly, adopt it; otherwise refactor in place.

### 3.4 Sender-enforcement fix

Free win: the honor-system sender check on `evelynn` disappears the moment local coordination moves into `agent-lifecycle` skills. Skills run in the caller's own context, so identity is who-is-in-the-chair, not a self-reported string. The remaining MCP surfaces (Telegram, Firestore) don't need sender enforcement at all because they're external-only and the caller identity is irrelevant to them — either the token is authorized or it isn't.

Note this as an *incidental* security improvement, not a goal of the migration.

### 3.5 What happens to `mcps/evelynn/`

Refactor-in-place is tempting but risky because the three concerns are interleaved in ~700 lines of Python. Proposed shape:

1. Create `mcps/telegram/` (or `mcps/external-comms/`) fresh, copy only the Telegram functions, clean imports.
2. Create `mcps/task-board/` fresh, copy only the Firestore functions, clean imports.
3. Move `mcps/evelynn/server.py` to `mcps/evelynn/archive/server.py.old` with a `README.md` stating "split into telegram + task-board per plans/implemented/2026-04-08-mcp-restructure.md" — or delete outright in Phase 3 cleanup.
4. Update `.mcp.json` to register the two new MCPs and deregister `evelynn`.

Open question §8: does Duong want **one external-comms MCP** (telegram + firestore together, one process) or **two** (telegram + task-board as separate processes)? Two is cleaner by separation-of-concerns, one is cheaper on process overhead. Bard's lean is two.

## 4. Interaction with `/end-session` (Katarina's in-progress work)

Katarina is implementing `plans/in-progress/2026-04-08-end-session-skill-phase-1.md` right now. That skill runs the 11-step close protocol: clean jsonl → archive transcript → journal → handoff → memory → learnings → commit → log_session → final report. Step 8 is "commit" — which overlaps directly with `commit_agent_state_to_main` from `evelynn`.

Three options for how `agent-lifecycle` and `/end-session` relate:

- **(a) `agent-lifecycle` IS `/end-session`.** Rename or subsume — one skill handles close + state-commit + shutdown. **Rejected.** `/end-session` is per-session and runs on every close. `shutdown-all` is a destructive broadcast that only Evelynn runs. They have different scopes, different caller constraints, and different failure modes. Conflating them hides the difference.
- **(b) They're distinct skills that share helpers.** `/end-session` handles the per-session close. `/agent-lifecycle` provides `shutdown-all`, `commit-state`, and future lifecycle ops as separable sub-commands. They share a common helper script (`scripts/commit-agent-state.sh`) that both invoke — `/end-session` Step 8 calls it inline, `/agent-lifecycle commit-state` is the natural-language entry point for "Evelynn, commit the current agent state before we do X."
- **(c) `/end-session` calls helpers that `/agent-lifecycle` provides.** Same as (b) but with `/agent-lifecycle` as the helper provider and `/end-session` as a caller. Ordering issue: `/end-session` ships first (Katarina, in progress), so whichever helper `/end-session` ends up with IS the helper `/agent-lifecycle` inherits.

**Recommendation: (b).** `/end-session` ships with its own inline Step 8 as specified in Katarina's Phase 1 plan. Phase 2 of this plan introduces `scripts/commit-agent-state.sh` as a refactoring of Step 8's inline logic, and `/end-session` Step 8 updates to call the script. `/agent-lifecycle commit-state` is a thin skill wrapper around the same script. Zero duplication of logic, zero ordering dependency, Katarina's Phase 1 is unaffected.

**Do not touch** `plans/in-progress/2026-04-08-end-session-skill-phase-1.md`. It's actively in progress. Any interaction with it happens via a new plan in Phase 2 of this plan, not by editing the approved spec.

## 5. Interaction with the approved skills-integration plan

`plans/approved/2026-04-08-skills-integration.md` is the parent plan for all skill work in this repo. This MCP-restructure plan inherits:

- **Skill format** — project-scoped `.claude/skills/<name>/SKILL.md`, YAML frontmatter per skills-integration §"Frontmatter (the important fields)".
- **Invocation model** — slash command + auto-load by description. `disable-model-invocation: true` where the user must be in the loop (e.g., `shutdown-all`).
- **Preload pattern** — every new skill must be added to the relevant agent `skills:` frontmatter lists. `/agent-ops` preloads into Evelynn, specialists, and implementers. `/agent-lifecycle` preloads into Evelynn only.
- **The six-skill cap for v1** — skills-integration caps the initial set at six. This plan adds `/agent-ops` and `/agent-lifecycle` (plus possibly `/new-agent`, `/delegate`, `/converse`), which pushes the cap. Flag: Phase 1 of this plan intentionally exceeds the six-skill cap. Duong may want to merge `/agent-ops`, `/delegate`, `/converse` into one umbrella skill to stay under the cap. Open question §8.

**No re-litigation of skill format, invocation rules, or preload semantics.** Those are settled by the approved plan.

## 6. Phasing

Independently shippable, independently revertible.

### Phase 1 — `agent-manager` → skills + scripts + rules

Smallest blast radius. No external integration involved. The MCP is purely local, so nothing external breaks when it goes away. Proves the skill-replaces-MCP pattern before tackling the messier `evelynn` split.

Scope: replace `agent-manager` entirely. Ship `/agent-ops`, `scripts/new-agent.sh`, `scripts/list-agents.sh`, possibly `/new-agent` and `/delegate`. Update all call sites in agent profiles and plans. Remove MCP registration. Archive `mcps/agent-manager/`.

Reversible by: re-registering the MCP in `.mcp.json` and reverting the call-site sweep. Skills can coexist with the MCP during a rollback window (both work, agents use whichever they see first).

**Exit criteria:** all agents run a full delegation round-trip (Evelynn → specialist → report) using only the new skills, no `agent-manager` MCP calls, for one week.

### Phase 2 — `evelynn` three-way split

Harder because it mixes local + external + external. Depends on Phase 1 landing cleanly — the `/agent-ops`-style pattern is the template for the local-coordination half of the split.

Scope:

1. Ship `/agent-lifecycle` skill with `shutdown-all` and `commit-state` sub-commands.
2. Add `scripts/commit-agent-state.sh` shared helper; wire `/end-session` Step 8 to use it (coordinated with Katarina if `/end-session` is already shipped; straightforward if not).
3. Create `mcps/telegram/` (bespoke refactor) OR adopt marketplace plugin.
4. Create `mcps/task-board/` (bespoke refactor) OR adopt `firebase` plugin.
5. Archive `mcps/evelynn/`, update `.mcp.json`.
6. Delete or keep `restart_evelynn` per open question.
7. Call-site sweep for the evelynn tools.

Reversible by: re-registering the old MCP and reverting the call-site sweep. But Phase 2 is higher blast radius because Telegram and Firestore are real external integrations — a bad cutover can silently drop messages. Mitigation: run the old MCP and the new MCPs **in parallel for one week**, verifying telemetry parity before removing the old one. This is a deliberate exception to "clean cutover" because the cost of a silent drop is high.

**Exit criteria:** one week of parallel operation with zero parity diffs, then old MCP removed.

### Phase 3 — governance + cleanup

1. Add the decision tree from §1 to `architecture/tool-categories.md` (or wherever the governance docs live) so future tool additions pass through it.
2. Add a CLAUDE.md rule: "Before adding a new MCP, confirm it's external-only per `architecture/tool-categories.md`." Prevents regression.
3. Delete the archived MCP directories from Phase 1 and Phase 2 once the skills have proven stable.
4. Evaluate marketplace plugins (`telegram`, `firebase`) against the bespoke Phase 2 refactors. If a plugin is equivalent, swap it in.
5. Audit any remaining MCPs Duong has in `/mcp` (global scope) against the decision tree, noting which are legitimate external integrations and which might warrant the same treatment in a future plan.

## 7. Rollback and failure modes

### 7.1 Skill can't cleanly replace an MCP tool

Some MCP tools have persistent-process semantics a stateless skill can't replicate — e.g., long-poll subscriptions, in-memory caches, shared state between calls. Mitigations:

- For `agent-manager`: none of its tools have persistent-process semantics. All are stateless read/write over the filesystem. Low risk.
- For `evelynn`: `task_changes` (Firestore subscription stream) is persistent. That's precisely why it stays MCP. `shutdown_all_agents`'s confirm gate is session-scoped state, but the state lives in a temp file on disk, which a skill can read/write. Low risk.
- If a tool surprises us, the fallback is `context: fork` + a dedicated stripped-down subagent for that one tool. Documented escape hatch, not a blocker.

### 7.2 Removing an MCP breaks agents mid-session

Highest-probability failure. Agents currently running with the old MCP in their context will try to call missing tools on their next turn. Mitigations:

- Phase 1 call-site sweep is in the **same commit** as the MCP removal. No inter-commit window.
- For Phase 2, parallel operation (both old and new MCPs registered) means agents can call either surface during the cutover week.
- Evelynn-the-coordinator's session is the most sensitive; the cutover commit should land during a natural pause (end of day, between workdays) so she restarts cleanly post-merge.

### 7.3 New skill has different ergonomics and Duong hates it

Real risk. MCP tools have fixed JSON signatures; skills use natural-language `$ARGUMENTS` parsing, which is fuzzier and can feel unpredictable. Mitigations:

- Every skill in this plan wraps a deterministic shell script. The script is the engine; the skill is the natural-language shell. If Duong hates the skill UX, the script still works on its own and he can call it directly from Bash.
- Ship Phase 1 to Evelynn only first (one-week trial), gather feedback, then roll out the skill preload to other agents.
- Skills are cheap to rewrite. A bad `/agent-ops` design can be iterated on without touching any Python.

### 7.4 Subagent-mode nested-delegation limitation

Skills-integration plan already flagged: subagents cannot spawn subagents. The `agent-manager` migration doesn't fix this — it just re-packages the same limitation. `/agent-ops send <agent> <message>` in subagent mode still requires the human to actually spawn the target agent. This plan does not fix nested delegation in subagent mode; it inherits the same workaround from the skills-integration plan (top-level spawning with Duong in the loop).

### 7.5 Skills pushing past the six-skill cap

Skills-integration caps v1 at six. This plan adds 2-5 more. If the cap is a hard constraint, fold multiple lifecycle ops under one umbrella skill (`/agent-lifecycle <subcommand>` already does this; `/agent-ops <subcommand>` can do the same). Open question §8.

### 7.6 Plugin marketplace alternatives we didn't evaluate

The `claude-plugins-official` marketplace has `telegram` and `firebase` skills Bard hasn't looked at yet. If either is a drop-in replacement for the bespoke refactor, Phase 2 gets a lot cheaper. If neither fits, Phase 2 is a full rewrite. Unknown until evaluated. Evaluation happens in Phase 2 Step 1, gated behind a quick proof-of-concept.

## 8. Open questions for Duong

Genuinely gating, not trivia.

1. **One external-comms MCP or two?** Telegram + Firestore as one process (`external-comms`) or two (`telegram` + `task-board`)? Bard's lean is two — cleaner separation, independently restartable, neither blocks the other. But two processes means two entries in `/mcp`, which is mild UX noise.
2. **Delete old MCP directories on migration, or archive them?** (a) archive-in-place with a README pointing at this plan, reversible; (b) delete in the landing commit, cleaner but harder to revert. Bard's lean is archive for Phase 1-2, delete in Phase 3.
3. **Any MCP tools you personally muscle-memory-use that you do NOT want renamed or moved?** If Duong types `message_agent` (retired, see v2 §3.2) by hand ever, the skill surface will feel alien. Flag any that matter.
4. **`restart_evelynn` — keep as a macOS-only script, or delete entirely?** It never worked reliably (always returned "uncertain"). In subagent/Windows mode it has no meaning. Bard's lean is delete entirely, leave a `scripts/restart-evelynn-iterm.sh` stub only if Duong actually uses it.
5. **Adopt marketplace `telegram` and `firebase` plugins, or bespoke refactor?** Unknown until Phase 2 proof-of-concept. Flag this now so Duong knows a switch is on the table.
6. **Skill count cap — soft or hard?** Skills-integration caps v1 at six. This plan exceeds it. Fold into umbrella skills (`/agent-ops send|list|new|delegate|converse`, `/agent-lifecycle shutdown-all|commit-state`) to stay at two new skills? Bard's lean is fold — fewer top-level slash entries, subcommand discovery via `/agent-ops` with no args.
7. **Phase 2 ordering re: Katarina's `/end-session`.** If `/end-session` Phase 1 lands before this plan's Phase 2, the `commit-agent-state.sh` helper refactor happens *after* `/end-session` has inline commit logic, and §4(b) applies cleanly. If Phase 2 of this plan somehow lands first, the helper ships first and `/end-session` Phase 1 picks it up. Either ordering works, but Duong should confirm he expects Phase 1 of `/end-session` to ship first (it's already in-progress).

## 9. What this plan does NOT do

- Does not touch `CLAUDE.md` rules directly in the rough phase. Rule additions happen in the detailed phase.
- Does not touch `plans/in-progress/2026-04-08-end-session-skill-phase-1.md`.
- Does not touch `plans/approved/2026-04-08-skills-integration.md`.
- Does not evaluate Duong's global-scope MCPs — only the two project-scoped MCPs in this repo. A future plan can audit globals.
- Does not specify exact tool signatures, subcommand syntax, or skill frontmatter fields. Those come in the detailed phase per sub-phase.
- Does not assign implementers. Evelynn's call after Duong moves this to `plans/approved/`.
