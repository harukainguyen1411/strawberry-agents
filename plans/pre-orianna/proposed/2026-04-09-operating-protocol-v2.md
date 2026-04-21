---
title: Operating Protocol v2 — How Strawberry Works Going Forward
status: proposed
owner: swain
created: 2026-04-09
---

# Operating Protocol v2

> Rough plan. Governance-level, not execution-level. This plan defines *how we work*, not *what we ship*. It inherits from and references the in-flight restructure plans rather than re-designing them. Anywhere this plan and a referenced plan disagree, the referenced plan wins on its own subject matter.
>
> Rule 7 applies. Swain authored. No self-implementation. Implementer assignment is Evelynn's call after approval.

---

## Why this plan exists

Over the last week Strawberry has accumulated four concurrent restructure plans and a protocol-leftover audit. Each is individually coherent. Together they expose a higher-order problem: **the operating protocol encoded in `CLAUDE.md`, `agents/memory/agent-network.md`, and the agent profiles was written for a specific execution model (macOS + iTerm + MCP coordination + one roster) that is no longer the reality.** Strawberry now runs on two platforms (macOS primary, Windows via Git Bash + subagents), is migrating coordination out of MCPs into skills, and has split planning into two phases — all while the protocol layer still describes the old world.

Pyke's audit (`assessments/2026-04-08-protocol-leftover-audit.md`) §8 surfaces ten cross-cutting themes. The top signal items:

1. **Subagent pivot is half-done.** Only 8 of ~15 agents have `.claude/agents/<name>.md`. The others assume iTerm.
2. **Two rosters drift.** `agents/roster.md` and `agents/memory/agent-network.md` disagree.
3. **Retired/half-scaffolded agents pollute the namespace.** Irelia, Zilean, Rakan, Shen all unclear.
5. **Platform-specific scripts scattered at top level.** The Phase 1 detailed spec names only a handful; the rest is uncovered.

These cannot be fixed by editing individual files. They are symptoms of a missing governance spec. This plan is that spec.

Duong added one new hard constraint while this plan was being drafted: **every `.claude/agents/<name>.md` must declare a `model:` frontmatter field.** Opus for planners, Sonnet for executors/reviewers, Haiku for minions. No silent inheritance from the parent session. That constraint lands here as a first-class rule.

---

## Scope boundary

**In scope:**

- The governance frame: who writes what, when, under which identity, on which platform.
- CLAUDE.md Critical Rules updates required by the existing in-flight plans once they converge.
- Cross-platform parity as a first-class protocol concern, not a footnote.
- Explicit model-tier declaration on every subagent.
- Agent lifecycle: onboarding, retirement, the single-source-of-truth roster.
- Protocol violation triage: what happens when an agent breaks a rule.
- The relationship between this v2 spec and the four in-flight restructure plans (inheritance, not duplication).

**Out of scope** (each owned by its own plan, cited here):

- **Plan lifecycle mechanics** — two-phase drafting, `plans/ready/`, `draft-plan`/`detailed-plan` skills, canonical plan frontmatter schema, plan-lint. Owned by `plans/proposed/2026-04-08-plan-lifecycle-protocol-v2.md` (Syndra). This v2 spec *references* it.
- **MCP restructure** — the external-system-only decision tree, `agent-manager` → `/agent-ops`, `evelynn` three-way split. Owned by `plans/proposed/2026-04-08-mcp-restructure.md` (Bard) and `plans/proposed/2026-04-09-mcp-restructure-phase-1-detailed.md` (Bard). This v2 spec *inherits* the decision tree as a governance invariant but does not re-specify the migration.
- **Skills integration mechanics** — skill format, four scopes, invocation paths, subagent ↔ skill interaction. Owned by `plans/approved/2026-04-08-skills-integration.md` (Syndra). This v2 spec treats skills as the primitive.
- **Evelynn continuity + coordinator purity** — Ionia condenser, Zilean retrieval, purity audit, Windows remote-restart flag file. Owned by `plans/proposed/2026-04-08-evelynn-continuity-and-purity.md` (Syndra). This v2 spec cites its tripwire recommendation and its remote-restart mechanism.
- **The repo leftover migration itself** — the concrete per-file moves/deletes/renames that execute the audit. Owned by Task #3 (pyke's next plan).
- **Anything in `plans/implemented/` or `plans/archived/`.** Frozen history.

---

## The protocol stack

Strawberry's operating protocol is a stack of layers. Each layer has exactly one source of truth. v2 is about making the layers legible and non-overlapping.

```
Layer 0 — Platform invariants         (this plan §"Cross-platform parity")
Layer 1 — Identity + tiers            (this plan §"Agent model-tier declaration" + §"Roster as single source of truth")
Layer 2 — Rules (CLAUDE.md)           (this plan §"CLAUDE.md rule updates", all existing in-flight plans)
Layer 3 — Coordination primitives     (this plan §"Evelynn's delegation stack" + mcp-restructure + skills-integration)
Layer 4 — Plan lifecycle              (plan-lifecycle-protocol-v2)
Layer 5 — Session lifecycle           (end-session skills, continuity-and-purity)
Layer 6 — Execution                   (Sonnet agents, always reading a plan file)
```

The ordering matters because every lower layer is a dependency of every higher layer. Layer 0 failing (a Windows skill silently fails) breaks everything above. Layer 1 failing (an agent runs on the wrong model tier) makes every rule at Layer 2 uncertainly enforced. And so on. v2's job is to close gaps at Layers 0, 1, and 2, and to certify that Layers 3–6 all terminate back at those foundations.

---

## Layer 0 — Cross-platform parity as first-class

Duong's hard constraint: **macOS and Windows must run similarly.** Today they do not:

- 11 of pyke's §1 audit rows are macOS iTerm affordances committed into per-agent directories.
- `windows-mode/` is a sibling to `scripts/`, not under it.
- Only 8 agents have `.claude/agents/<name>.md` files — the other 7 implicitly assume the iTerm launcher path.
- Scripts like `scripts/launch-evelynn.sh` and `scripts/restart-evelynn.ps1` live at the top level with no `mac/`/`windows/` classification.

Phase 1 detailed MCP restructure (Bard, 2026-04-09) introduces the `scripts/mac/` + `scripts/windows/` convention but explicitly scopes the sweep to the files named in that plan. v2 makes it universal.

### Protocol invariants (Layer 0)

1. **Every committed script is classified.** Either (a) POSIX-portable and lives under `scripts/` at the top level, or (b) platform-specific and lives under `scripts/mac/` or `scripts/windows/`. No exceptions. There is no "both work, it's fine" gray zone — if `macOS` and `Git Bash` behavior could differ, the script is platform-specific.
2. **Skill bodies are POSIX-only.** Any `.claude/skills/<name>/SKILL.md` that needs a macOS affordance calls a `scripts/mac/` helper rather than containing the macOS command inline. Same for Windows. The skill is the platform-neutral surface.
3. **Per-agent directories contain no platform state.** `agents/<name>/iterm/` blobs and similar move out of `agents/` entirely. iTerm profile state, if retained at all, lives under `scripts/mac/iterm-profiles/` or is regenerated on demand. An agent's repo footprint must be identical on Mac and Windows.
4. **`architecture/platform-parity.md` is the single source of truth** for what is Mac-only, what is Windows-only, and what each platform does in place of the other. Phase 1 detailed restructure (Bard) creates this file; v2 pins it as the canonical location.
5. **A new script or skill is not "done" until its parity row is documented.** The author of the new artifact adds the parity row in the same commit that introduces the artifact. The `draft-plan` and `detailed-plan` skills (plan-lifecycle-v2) must remind the author of this requirement.
6. **Windows has no Claude-invoked launcher.** Windows agent spawning is via the harness `Task` tool (subagents) exclusively. There is no PowerShell script that Claude calls to launch an agent on Windows, because subagents are the launcher. This mirrors phase-1-detailed's `scripts/windows/launch-agent.sh` stub that prints non-support and exits 2.

### Parity debts to clear (outside this plan, cited)

v2 does not execute these; Task #3 (pyke's migration plan) does. v2 lists them so the migration plan has an authoritative target:

- Move `scripts/launch-evelynn.sh` → `scripts/mac/launch-evelynn.sh`.
- Move `scripts/restart-evelynn.ps1` → `scripts/windows/` (or delete per mcp-restructure D4).
- Move `windows-mode/*` contents under `scripts/windows/`.
- Move or reclassify `agents/launch-agent.sh`, `agents/boot.sh`.
- Sweep `agents/<name>/iterm/` dirs.
- Sweep every `scripts/*` file and classify per invariant 1.
- Audit `scripts/gh-*`, `scripts/setup-*`, `scripts/*-bridge.sh`, `scripts/google-oauth-bootstrap.sh`, and `scripts/_lib_gdoc.sh` for platform assumptions. Classify each.

---

## Layer 1 — Identity, model tiers, and the single roster

Pyke §8 items 1, 2, 3 all reduce to: **the system does not have one authoritative answer to "who is an agent, what tier are they, and can they run cross-platform?"**

v2 fixes this at three sub-layers: roster consolidation, model-tier declaration, and lifecycle (onboard / retire).

### 1.1 Roster as single source of truth

**Protocol invariant:** `agents/memory/agent-network.md` is the single roster — it is the file every agent reads at startup, so it has to be the source of truth. `scripts/list-agents.sh` (Phase 1 MCP restructure) produces a machine-readable view from the filesystem; the human narrative lives in `agent-network.md`. Any divergence between what `list-agents.sh` finds and what `agent-network.md` lists is a CI failure (future hook).

**`agents/roster.md` — still open.** Duong is undecided between (a) hard-delete and rely on `agent-network.md` alone, or (b) keep a thin pointer file. Swain's lean: (a), consistent with the hard-delete retirement policy in §1.3 — fewer surfaces, fewer ways to drift. Flagged as the first item under "Open questions" for final call at approval time.

**Wired vs aspirational — two tiers of roster membership.** Not every name in `agent-network.md` is invokable today. v2 formalizes the distinction:

- **Wired.** The agent has all four of: `agents/<name>/` directory with `profile.md` and `memory/<name>.md`; `.claude/agents/<name>.md` with declared `model:` tier; a row in `agents/memory/agent-network.md`; and a parity row in `architecture/platform-parity.md` if applicable. A wired agent can be invoked as a subagent.
- **Aspirational.** The agent has a row in `agent-network.md` describing intended role/tier and may have `agents/<name>/` scaffolding, but lacks a `.claude/agents/<name>.md` harness profile. An aspirational agent cannot be invoked — the row is a design placeholder, not a live surface. Rakan, Ornn, Fiora, and similar currently sit here (per Duong's Q5 decision: keep Rakan as "aspirational, not wired").

Aspirational rows are legal in `agent-network.md` but must be clearly marked (e.g., a `status: aspirational` column in the roster table). They are not protocol violations; they are intended future wiring. When an aspirational agent is wired, it graduates to wired in a single onboarding commit per §1.3.

**Implication for pyke §8.3 (half-scaffolded agents):**

- **Zilean** — directory exists without `profile.md` or `memory/`. Either finish scaffolding per continuity-and-purity Component B (which ships them when that plan lands), or delete the skeleton. Until one of those happens Zilean is neither wired nor aspirational — she is a broken row that must be resolved. Task #3 picks the path.
- **Irelia** — retired. Removed from the live roster via the §1.3 retirement procedure (hard delete per Q4).
- **Shen** — wired. CLAUDE.md Rule 15 lists him on Sonnet; Task #3 adds his row to `agent-network.md` and confirms `.claude/agents/shen.md` declares `model: sonnet`.
- **Rakan** — aspirational (per Q5). Stays in `agent-network.md` as an aspirational row. No `.claude/agents/rakan.md` needed until/unless someone wires him.

### 1.2 Agent model-tier declaration (new hard rule)

**Protocol invariant:** every `.claude/agents/<name>.md` file MUST declare a `model:` frontmatter field. The legal values and their semantics:

| `model:` value | Used for | Tier rationale |
|---|---|---|
| `opus` | Planners, coordinators, architects. Write plans, design systems, route work. Never execute. | Judgment work, long-horizon design, expensive to run but high leverage per token. |
| `sonnet` | **Default for everything except really simple mechanical work.** Executors, reviewers, specialists, condensers, retrieval agents with any interpretation surface. Always read a plan file before doing execution work. | Strong, reliable tier across judgment-adjacent work. Correct cost/quality tradeoff for the overwhelming majority of tasks. |
| `haiku` | **Exception tier, reserved for really simple tasks.** Single-verb mechanical work with a tight contract and no interpretation surface — Poppy-class edits where the caller hands a file path, an old string, and a new string. | Cheap and fast, but only safe when the task is narrow enough that hallucination cannot slip through the contract. |

**Rule of thumb (per Duong, 2026-04-09):** Haiku only for really simple tasks. Sonnet is the default even when cost is a concern. If there is any doubt whether a task is "really simple" enough for Haiku, the answer is Sonnet. The cost of a wrong Haiku choice (a minion confidently mis-executes) dwarfs the cost of a conservative Sonnet choice.

No agent inherits its model tier from the parent session. Inheritance produced the silent-degradation class of bugs (an Opus agent running accidentally on Sonnet during a Sonnet parent session, producing worse plans than expected, with nobody noticing until a week later). The `model:` field is load-bearing.

**Role-to-tier authoritative mapping (per CLAUDE.md Rule 15, as landed 2026-04-09):**

- Opus: Evelynn, Syndra, Swain, Pyke, Bard.
- Sonnet: Katarina, Lissandra, Yuumi, Ornn, Fiora, Reksai, Neeko, Zoe, Caitlyn, Shen.
- Haiku: Poppy.

This mapping is already authoritative in `CLAUDE.md` Rule 15; v2 pins it here so that onboarding, retirement, and the audit/migration plan all read from the same target. Notable implications:

- **Yuumi is Sonnet**, not Haiku. The minion-tier default from continuity-and-purity's language does not apply to her — her role (errand runner, multi-step file moves, script execution with reporting) is judgment-adjacent and Rule 15 assigns Sonnet.
- **Shen is on the live roster as Sonnet.** Pyke's audit §1 flagged Shen as "not in `agent-network.md`, active-or-retired unclear." Rule 15's mapping resolves the question: active, Sonnet tier. Task #3 must add Shen's row to `agent-network.md` and confirm his `.claude/agents/shen.md` declares `model: sonnet`.
- **Rakan and Irelia are absent from Rule 15.** That is consistent with Irelia's retirement and with Rakan being pre-retirement-decision territory. Task #3 retires Irelia via the procedure below. Rakan is an open question for Duong (see §"Open questions" item 5).
- **Zilean and Ionia are not yet on Rule 15** because neither ships until continuity-and-purity lands. When they do, both declare `model: sonnet` — Ionia for judgment-tier transcript summarization, and Zilean because even "retrieval with verbatim citation" has enough interpretation surface (deciding which quote answers the question) that Haiku's rule-of-thumb exemption does not apply. Rule 15 amends to list them at that time. This is a direct consequence of Q2 (Duong, 2026-04-09): Haiku is the exception, Sonnet is the default.

**Task #3 (pyke migration plan) action:** add `model:` to every existing `.claude/agents/<name>.md` file, using Rule 15's mapping verbatim. Any agent missing from both Rule 15 and the legitimate exceptions above is escalated to Duong, not resolved unilaterally.

### 1.3 Agent lifecycle: onboarding and retirement

**Onboarding checklist** (new rule, enforced at profile-commit time — a draft-plan skill reminder in the short term, a hook in the long term):

1. `agents/<name>/profile.md` with personality + role.
2. `agents/<name>/memory/<name>.md` with `# <Name>` heading and an empty Sessions section.
3. `agents/<name>/inbox/`, `agents/<name>/journal/`, `agents/<name>/learnings/`, `agents/<name>/transcripts/` (empty, with `.gitkeep` each).
4. `.claude/agents/<name>.md` with frontmatter including `name`, `description`, `model`, and (if relevant) `tools` and `skills`.
5. Row added to `agents/memory/agent-network.md` roster table: name, role, tier, platforms, primary coordinator.
6. Row added to `architecture/platform-parity.md` if the agent has any platform-specific affordance. Default: no row needed; the agent is assumed cross-platform.
7. All of the above in a single commit with `chore: onboard <name> agent`.

Onboarding is done via `scripts/new-agent.sh` (Phase 1 MCP restructure). The script covers items 1–3 automatically; 4–7 are manual in Phase 1 and may become scripted later.

**Retirement procedure** (per Q4, Duong 2026-04-09: hard delete, git-controlled — no `.retired/` directory):

1. `git rm -r agents/<name>/` — hard delete the entire agent directory. History is preserved by git itself; the working tree no longer carries the dead weight. No `agents/.retired/<name>/` shadow copy.
2. `git rm .claude/agents/<name>.md` — delete the harness profile. A retired agent cannot be invoked.
3. Remove the row from `agents/memory/agent-network.md` roster. A short "Retired" footnote section lists name + retirement date + one-line reason for continuity; detailed history lives in git log.
4. Remove the row from `architecture/platform-parity.md` if present.
5. Prior learnings, journals, transcripts, and plan authorship attributable to the agent survive via git history. Do not scrub them from older commits or rewrite history.
6. All of the above land in a single commit. **Commit message template:** `chore: retire <name> agent — <one-line reason>`. The commit body restates the retirement reason and, if relevant, names the plan that authorized the retirement.

**Rationale for hard delete over archive directory:** an archive directory reintroduces the fossil problem this plan is trying to solve. Once a dir exists, it gets scanned, listed, and occasionally read — which means "retired" silently becomes "half-retired." Git history is a better archive than a working-tree directory because it is immutable and does not pollute filesystem scans. Rollback if a retirement turns out to be premature: `git revert <retirement-commit>` restores every file atomically.

**Pyke §8.3 cleanup targets on retirement procedure adoption:** Irelia is the first use of this procedure. Task #3 (pyke's migration plan) executes the retirement as the canonical example.

---

## Layer 3 — Coordination primitives: Evelynn's delegation stack

New directive from Duong, 2026-04-09: **the legacy `agent-manager` MCP surface is retired.** Not "being retired" — actually retired. The `agent-manager` and `evelynn` MCPs disconnected mid-session tonight while this plan was being drafted. The retirement is real, not theoretical. v2 must bake the replacement into the Layer 3 spec so no agent reaches for the legacy surface even when tool loading happens to surface the old names.

### 3.1 Evelynn's canonical delegation stack (ordered by primary use)

Evelynn delegates through exactly three channels, in this order:

1. **Agent teams** — the primary surface for **multi-agent collaborative work**. `TeamCreate` sets up a team with a shared task list and routing; the `Agent` tool with `team_name` / `name` parameters spawns teammates into it; `SendMessage` moves information between them; `TaskCreate` / `TaskUpdate` / `TaskList` coordinate the work. This is the surface you are reading in this session right now — the protocol-audit team is structured this way. Teams are the correct surface whenever two or more agents need to see each other's output, claim different parts of a problem, or route around each other's blockers.

2. **Native Claude Code subagents** — the primary surface for **single-agent focused delegation**. The `Agent` tool with `subagent_type: <name>` spawns a named subagent for a bounded task, the subagent reports back, and the conversation resumes. This is the right surface when Evelynn needs one agent to do one thing and return a result. No shared task list, no teammates to coordinate with. Narrower surface than a team, lower overhead, appropriate for the majority of single-shot delegations.

3. **Yuumi** — Evelynn's personal errand-runner. A specific Sonnet-tier subagent whose role is bounded mechanical admin: lookups, file moves, running existing scripts and reporting the output, light multi-step chores Evelynn would otherwise be tempted to do herself. Yuumi is not a tier above or below the other two — she is a *named instance* of surface #2 with a profile that makes her the default pick for that class of work. Reaching for Yuumi is how Evelynn preserves Rule 7 purity on routine admin without spinning up a full team or picking a specialist.

### 3.2 What is deprecated (exact retirement scope)

Everything on this list is gone. Evelynn, Syndra, Swain, Pyke, and Bard must not reach for any of the following, even if tool loading surfaces them:

- `agent-manager` MCP tools: `list_agents`, `get_agent`, `create_agent`, `launch_agent`, `message_agent`, `start_turn_conversation`, `speak_in_turn`, `pass_turn`, `end_turn_conversation`, `read_new_messages`, `get_turn_status`, `invite_to_conversation`, `escalate_conversation`, `resolve_escalation`, `delegate_task`, `complete_task`, `check_delegations`, `report_context_health`.
- Legacy iTerm launch flow: spawning agents by writing iTerm profile blobs, grid positioning, `scripts/launch-evelynn.sh` top-level (Mac-only; moves to `scripts/mac/` per Layer 0).
- Inbox-based peer-to-peer messaging as the primary channel. Inbox writes remain legal as a fallback notification surface (useful when a teammate isn't in the current session), but they are not the canonical delegation path — teams and subagents are.
- Turn-based conversations entirely. The 33 `.turn.md` files under `agents/conversations/` are fossils per pyke §8.4 and are archived/deleted in Task #3.
- `delegate_task` / `complete_task` / `check_delegations`. Delegation state lives in the shared TaskList (TaskCreate / TaskUpdate / TaskList) and in SendMessage summaries. The JSON files under `agents/delegations/` are fossils, also swept by Task #3.

Cross-reference: `plans/proposed/2026-04-09-mcp-restructure-phase-1-detailed.md` is the execution path for the deprecation. That plan's Step 7 handles the call-site sweep; v2 pins the *directive* here so that any site the phase-1 sweep misses (in-flight plans, new work written during the transition) is still governed.

### 3.3 Teams and subagents REPLACE the legacy surface — they are not additions

This is the load-bearing clarification Duong asked for explicitly. The ban on the legacy tools is not "prefer the new surface but fall back to the old one if the new one is inconvenient." It is: the new surface *is* how delegation works now. Reaching for `message_agent` or `launch_agent` because "it still happens to be loaded" is a protocol violation on the same level as an Opus agent running `Edit` directly.

Two implications:

- **No parallel channels.** There is no legitimate workflow that requires both the new and the old surface simultaneously. If an agent finds themselves thinking "I'll use the team for X and `message_agent` for Y," the answer is: use the team for both. If the team surface doesn't support Y, that is a bug in the team surface worth raising, not a reason to reach backward.
- **Discipline lives at the reach-for moment.** Rule 7 already bans Opus agents from executing; this Layer 3 directive extends the same discipline to *delegation surface choice*. When the Rule 7 tripwire hook (§2.2) ships, it can be extended to refuse legacy MCP tool calls on `opus`-tier agents as a second enforcement class — same hook, same pattern.

### 3.4 Other Opus agents delegate the same way

Syndra, Swain, Pyke, and Bard follow the same three-channel stack when they need teammates. The distinction between Evelynn and the rest is that Evelynn is the **top-level coordinator** — she receives Duong's requests and decides whether to spawn a team, a single subagent, or Yuumi. The other Opus agents are typically operating *inside* a team Evelynn created, but they have full authority to spawn their own subagents for their own research or multi-step work within that team, and to use Yuumi for errands. They do not spawn sub-teams (the "subagents cannot spawn subagents" rule from skills-integration applies), so "delegation" from a non-Evelynn Opus agent is bounded to surface #2 (subagents) and #3 (Yuumi). Surface #1 (new teams) is Evelynn's call.

### 3.5 Layer 1 × Layer 3 linkage — why Rule 15 became urgent

Duong asked to surface this explicitly: the model-tier rule (CLAUDE.md Rule 15, Layer 1) is **load-bearing for teams and subagents specifically because they amplify the silent-inheritance risk**. Here is the failure mode the rule is guarding against:

- Before teams, silent inheritance was a single-session problem. An Opus agent spawning without an explicit `model:` would pick up the parent session's model. At worst, one agent ran on the wrong tier for one session.
- With teams, every teammate Evelynn spawns without an explicit `model:` inherits Evelynn's tier. A full Opus team costs 5–10× a correctly-tiered team, degrades specialists who should be Sonnet, and does it silently — nothing in the UI says "this Sonnet teammate is actually running on Opus because you forgot the frontmatter."
- Subagents have the same risk but in reverse: an Opus planner spawning a subagent without `model:` might silently downgrade to Sonnet, and suddenly the planner is making planning decisions on the wrong tier. Component A of continuity-and-purity already flagged this risk for Ionia.

Rule 15 is the fix: **every `.claude/agents/<name>.md` MUST declare `model:`, no inheritance.** Teams made the problem urgent because teams multiply it. v2 pins this linkage so that anyone reading §1.2 in isolation understands why the rule exists and why it is not "just a hygiene nicety" — it is the thing standing between Evelynn and an accidental all-Opus team on her next spawn.

---

## Layer 2 — CLAUDE.md rule updates

This section lists the rule changes v2 requires in `CLAUDE.md`. Every change is phrased as "current text → v2 text" or "new rule N (exact text)." v2 does not edit `CLAUDE.md` directly — the detailed phase of this plan (if approved and detailed) does, or Task #3's migration plan rolls them into its commits. This plan just pins the target.

### 2.1 Rule 6 (Sonnet agents must never work without a plan file) — tightened

Current: "Sonnet agents must never work without a plan file — Sonnet agents execute, they don't design. Every delegated task to a Sonnet agent must reference a plan file in `plans/`."

**v2 replacement:** "Sonnet agents must never work without a plan file in `plans/ready/` or `plans/in-progress/`. Sonnet agents execute; they don't design. The plan must be detailed enough that the executor makes no design judgment calls (per plan-lifecycle-protocol-v2's detailed-plan bar). If a Sonnet agent encounters ambiguity, they stop and escalate to Evelynn rather than improvising."

Depends on: `plans/proposed/2026-04-08-plan-lifecycle-protocol-v2.md` introducing `plans/ready/`. Until that plan lands, Rule 6 keeps saying `plans/` and v2 notes the future tightening.

### 2.2 Rule 7 (Plan approval gate & Opus execution ban) — tightened

Current text is load-bearing already. v2 adds one sentence: "Opus agents take no `Edit`, `Write`, `Bash` (non-read-only), or `git` actions outside their own memory/learnings files. If an Opus agent is tempted to make an edit directly, they stop and dispatch a minion (Poppy for mechanical edits, Yuumi for errands, Katarina for engineering)."

**Tripwire placement (per Q1, Duong 2026-04-09): Claude Code harness pre-tool-use hook, not profile text.** The enforcement surface for this clause is a hook that intercepts `Edit`, `Write`, `Bash`, and `git`-shelling calls on agents whose `model:` is `opus` and whose target paths are not inside `agents/<self>/memory/**` or `agents/<self>/learnings/**`. On hit, the hook refuses the tool call and emits a reminder to dispatch a minion. Profile text and Rule 7 prose are documentation; the hook is enforcement. This is a deliberate departure from Swain's initial lean (both profile and rule text). Rationale: the continuity-and-purity Component C audit showed that prose reminders are not holding for Evelynn even after three prior learning files — the discipline-layer enforcement needs a structural tripwire.

Hook implementation is **out of scope for this plan**. v2 pins the placement decision; the hook itself is a follow-up plan (owner: Bard or Pyke, tooling-layer specialists). The plan must address: cross-platform compatibility (the hook runs on both macOS and Windows Git Bash), agent-identity detection inside the hook (reading `model:` from the current subagent's frontmatter), the allowlist of paths an Opus agent may still touch (own memory, own learnings, and plan files under `plans/proposed/` — the latter is how Opus agents still write their own plans), and escape-hatch semantics for Duong's "go ahead" override clause already in Rule 7.

### 2.3 Rule 9 (Plans go directly to main, never via PR) — unchanged in intent, clarified

Current text is correct but ambiguous on the two-phase lifecycle. **v2 clarification:** "Both rough plans (in `proposed/`) and detailed plans (expanded in `approved/` and promoted to `ready/`) commit directly to main. Only implementation work (Sonnet execution of a `ready/` or `in-progress/` plan) goes through a PR." Hooks on plan-lifecycle-protocol-v2.

### 2.4 Rule 10 (Use `chore:` prefix for all commits) — unchanged

Reconfirmed. v2 reminds all new skills and scripts to enforce `chore:` in any commit helper.

### 2.5 Rule 12 (Use `scripts/plan-promote.sh`) — expanded

Current text is correct for the Drive-mirror invariant. **v2 expansion:** "`scripts/plan-promote.sh` is the single choke point for every plan transition between lifecycle directories. The legal transitions are: `approved → ready`, `ready → in-progress`, `in-progress → implemented`, and `any → archived`. The `proposed → approved` transition remains manual (Duong moves the file). Raw `git mv` for plan files is forbidden; the script enforces Drive unpublish, status rewrite, and parity-row updates." Hooks on plan-lifecycle-protocol-v2.

### 2.6 New Rule (expected 15) — MCP-only-for-external

Exact text (inherited verbatim from phase-1-detailed Step 11 Rule 15): "Project MCPs are only for external system integration. Local coordination, state management, and procedural discipline belong in skills, CLAUDE.md rules, and shell scripts. Before adding a new MCP, confirm it talks to a stateful or protocol-heavy external system per `architecture/platform-parity.md` and the decision tree in `plans/proposed/2026-04-08-mcp-restructure.md` §1."

### 2.7 New Rule (expected 16) — POSIX portability

Exact text (inherited verbatim from phase-1-detailed Step 11 Rule 16): "All skills and scripts in `scripts/` (outside `scripts/mac/` and `scripts/windows/`) MUST be POSIX-portable bash runnable on both macOS and Git Bash on Windows. Platform-specific affordances live under `scripts/mac/` or `scripts/windows/` and are listed in `architecture/platform-parity.md`."

### 2.8 Rule 15 (Model-tier declaration) — already landed 2026-04-09

While this plan was being drafted, Duong committed Rule 15 directly to `CLAUDE.md`: "Every agent definition must declare its model" with the Opus / Sonnet / Haiku mapping above. v2 reconfirms it and treats it as the canonical Layer 1 invariant. No new rule text needed here — v2's contribution is the onboarding/retirement procedures in §1.3 that make Rule 15 maintainable as the roster evolves, and the commitment in Task #3 to backfill `model:` across every existing `.claude/agents/<name>.md` file.

### 2.9 New Rule (expected 16) — Roster single source of truth

**Exact text:** "`agents/memory/agent-network.md` is the single roster. Adding or retiring an agent is a single-commit operation that updates the filesystem (`agents/<name>/`), the harness profile (`.claude/agents/<name>.md`), the roster file, and — if applicable — `architecture/platform-parity.md`. `agents/roster.md` is deprecated; reference `agent-network.md` instead. An agent is not on the roster unless all four places agree."

### 2.10 New Rule (expected 17) — Cross-platform parity is universal

**Exact text:** "Every committed script is either POSIX-portable (lives at `scripts/<name>`) or platform-specific (lives under `scripts/mac/<name>` or `scripts/windows/<name>`). No committed script may assume a platform without declaring it via directory placement. Per-agent directories under `agents/<name>/` contain no platform-specific state; iTerm profile blobs and equivalents live under `scripts/mac/` or outside git. New scripts and skills are not complete until their row is added to `architecture/platform-parity.md`."

Numbering note: Rule 15 is Duong's model-tier rule (already landed). Rules 16 and 17 above are additive on top of it. Phase 1 MCP restructure's phase-1-detailed Step 11 also plans new rules 15 and 16 (MCP-only-for-external, POSIX portability); those numbers will need to renumber once this plan and the MCP restructure land in the same commit sequence. v2's position: Rule 15 stays as landed (model tier); the MCP and POSIX rules in §2.6 and §2.7 become Rules 16 and 17; the roster and parity rules here become Rules 18 and 19. Evelynn or the detailed phase of this plan picks the exact numbering at commit time. The text is what matters.

---

## Layer 5 — Session lifecycle hookups

v2 does not re-specify `/end-session` or `/end-subagent-session` — those are owned by Katarina's in-progress end-session-skill plan and already partially shipped. v2 just names the dependencies and the integration points:

- **Startup**: agent reads `profile.md` → `memory/<name>.md` → `memory/last-session.md` → `agents/memory/duong.md` → `agents/memory/agent-network.md` → `learnings/index.md`. Once the continuity-and-purity Component A ships, add `memory/last-session-condensed.md` as the first item, with `memory/last-session.md` as fallback. v2 pins this ordering in the agent-network.md Protocol section (to be rewritten under phase-1 MCP restructure Step 10).
- **Close**: every session closes via `/end-session` (top-level) or `/end-subagent-session` (subagent). No agent may terminate by any other mechanism. This is existing Rule 14, reconfirmed.
- **Memory continuity**: the continuity-and-purity Component A condenser is the primary mechanism for avoiding "Evelynn wrote a thin handoff again" failures. Not in v2 scope to design; v2 references it.
- **Remote-restart**: the Windows flag-file mechanism from continuity-and-purity Component D is the canonical remote-restart path. v2 pins it as the required primitive for any future remote-control work.

---

## Layer 6 — Execution discipline

Two reminders, both inherited:

1. **Sonnet agents always read a plan file before doing execution work.** No exceptions. Reinforced by Rule 6 v2 text above.
2. **Opus agents never implement.** Reinforced by Rule 7 v2 text. The continuity-and-purity tripwire is the discipline-layer enforcement.

---

## Protocol violation triage

Today, protocol violations produce a learning file and drift back into normal operations. Pyke's audit implicitly counted dozens of leftover fossils from violations that were never cleaned up. v2 needs an explicit triage path.

**Proposed triage** (rough, to be detailed if this plan is approved):

1. **Detect.** Either (a) Duong corrects an agent in-session, (b) the Component A condenser's "What Evelynn got away with" section surfaces a silent violation, or (c) a pre-commit hook refuses a commit (secrets, chore: prefix, plan frontmatter).
2. **Record.** The offending agent writes a learning file at `agents/<name>/learnings/YYYY-MM-DD-<topic>.md` with the rule, the violation, the correction, and the mitigation. This is an existing convention; v2 confirms it.
3. **Escalate if repeat.** If the same rule has been violated by the same agent more than twice (visible from the learnings index), Evelynn opens a rough plan under `plans/proposed/` proposing a structural fix. A structural fix is preferred over a third learning file that will not hold. The continuity-and-purity plan's tripwire recommendation is the archetype here.
4. **Clean up fossils.** Every rule retirement produces fossils — files, scripts, conversations, delegations, tool references. Pyke §8.4 documents 33 turn-based `.turn.md` files and 6 `d-*.json` delegations as visible fossils. Task #3 (the migration plan) is the current fossil sweep; v2 requires that every future rule retirement triggers a fossil sweep in the same commit as the rule change.

---

## Open questions for Duong

### Resolved in-session (2026-04-09)

- **Q1 — Rule 7 tripwire placement.** RESOLVED: pre-tool-use harness hook, not profile text. §2.2 updated. Hook implementation is a follow-up plan.
- **Q2 — Haiku baseline for minions, or Sonnet?** RESOLVED: Sonnet is the default. Haiku is the exception, reserved for really simple mechanical tasks (Poppy-class). §1.2 updated; Ionia and Zilean both declare `model: sonnet` when they ship.
- **Q4 — Retirement target directory.** RESOLVED: hard delete, git-controlled. No `.retired/` directory. §1.3 updated.
- **Q5 — Rakan classification.** RESOLVED: keep Rakan as "aspirational, not wired." §1.1 introduces the wired/aspirational distinction to formalize this status. Ornn, Fiora, and similar sit in the same tier.

### Still open

1. **Roster file consolidation.** Duong is unsure whether to hard-delete `agents/roster.md` or keep it as a thin pointer to `agents/memory/agent-network.md`. Swain's lean (consistent with the Q4 hard-delete policy for retirement): delete `agents/roster.md` outright. `agent-network.md` is the file agents actually read at startup; the pointer file is drift-bait. Final call at approval time.

2. **Model tier for agents not yet in Rule 15.** Rule 15 covers the current roster. Aspirational agents (Rakan etc) don't need a tier until they're wired. But when they ARE wired, Task #3 or the onboarding plan must confirm the tier with Duong rather than inferring from role description. This is process, not a blocker — flagging so the onboarding skill checklist includes it.

3. **Pyke §8.7 — stale plans in `plans/proposed/`.** Four plans from 2026-04-03 to 2026-04-05 are stuck. Does v2 add a staleness-TTL rule (e.g., a plan in `proposed/` with no update for N days gets auto-archived), or is that the plan-lifecycle-v2 plan's job? Swain's lean: let plan-lifecycle-v2 own it; v2 just flags that it needs to exist.

4. **Where does `architecture/platform-parity.md` get maintained?** It's created by Phase 1 detailed MCP restructure and v2 pins it as the single source of truth. But who maintains it as new artifacts land? Swain's lean: the `draft-plan` and `detailed-plan` skills from plan-lifecycle-v2 must include a "parity row update" reminder in their body. Skill-level enforcement, complemented by the Rule 7 tripwire hook for edit discipline.

5. **Agent identity in SendMessage vs inbox.** In subagent mode (this session), agents communicate via SendMessage. In top-level mode, they write to `agents/<name>/inbox/`. v2 treats these as two surfaces for the same primitive; the agent's code doesn't change. But is this actually equivalent, or does SendMessage introduce auditability gaps the inbox path doesn't have? Flagging — not blocking v2 approval, but worth a follow-up plan if the gap is real.

---

## Rollback / failure-mode sketch

This plan is governance spec, so rollback is cheap: every rule change in Layer 2 is a single-commit `git revert`. But the failure modes that matter are not rollbacks, they are *adoption failures*:

- **If the `model:` rule is added but nobody updates the profiles.** Mitigation: Task #3 (pyke migration plan) commits the field updates in the same PR as the rule. Do not ship the rule text without the backfill.
- **If the retirement procedure is added but nobody retires Irelia.** Mitigation: the first use of the procedure happens in Task #3 against Irelia as the canonical example. Writing the procedure and using it are a single commit.
- **If parity invariants land but the existing debts from pyke §8.5 are not swept.** Mitigation: Task #3's migration plan must enumerate every existing script and classify it. No rule additions without the sweep.
- **If the tripwire for Rule 7 lands but Evelynn ignores it.** This is not a v2 failure mode — it's a continuity-and-purity failure mode, and the Component C audit already documented that discipline beats structure. v2 pins the placement; whether it works is a discipline question the condenser monitors continuously.
- **If v2 and a referenced plan disagree on a point of substance.** Per this plan's opening note: the referenced plan wins on its own subject matter. v2 is governance glue, not a re-litigation.

Worst failure mode: **the rules land, the profiles get `model:` fields, the rosters get consolidated, and then within two weeks somebody introduces a new agent without a `model:` field and nobody notices.** The structural fix is a hook; the v2 text leaves the hook out of scope because the CLAUDE.md rule is the first line of defense and the hook is a second-phase investment. If the manual discipline fails over the first month, the detailed phase of v2 (or a follow-up) adds the hook.

---

## Out of scope

- Executing the audit cleanup (pyke Task #3).
- Designing the plan-lifecycle mechanics.
- Designing the MCP restructure.
- Designing the Ionia condenser, Zilean, or the Windows remote-restart flag file.
- Adding any specific hook implementations.
- Any PR workflow changes, branch protection changes, or CI additions.
- Any work on `apps/`, `services/`, `tasklist/`, or the myapps side of the workspace.
- Rewriting any `plans/implemented/` or `plans/archived/` file.
- Any change to the secrets policy (Rule 11 is load-bearing and untouched).
- Any change to git workflow rules (worktree, no-rebase) — those are correct as-is.
