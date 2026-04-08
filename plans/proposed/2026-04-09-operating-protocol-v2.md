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
Layer 3 — Coordination primitives     (skills, SendMessage, inbox, task board) — mcp-restructure + skills-integration
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

**Protocol invariant:** `agents/memory/agent-network.md` is the single roster. `agents/roster.md` is deleted or becomes a thin pointer file. `scripts/list-agents.sh` (introduced by Phase 1 MCP restructure) reads the filesystem to produce a machine-readable list; the human-readable narrative lives in `agents/memory/agent-network.md`. Any divergence between what `list-agents.sh` finds and what `agent-network.md` lists is a CI failure (future hook).

**What "being on the roster" means:** the agent has (a) a directory at `agents/<name>/` with at minimum `profile.md` and `memory/<name>.md`, (b) a subagent definition at `.claude/agents/<name>.md` with a declared `model:` tier, (c) a row in `agents/memory/agent-network.md` listing role, tier, and platforms, (d) a parity row in `architecture/platform-parity.md` if the agent has any platform-specific affordances. If any of these four are missing, the agent is not on the roster and cannot be invoked.

**Implication for pyke §8.3 (half-scaffolded agents):**

- **Zilean** — directory exists without `profile.md` or `memory/`. Either finish scaffolding per the draft in the continuity-and-purity plan's Component B (which ships them when that plan lands), or delete the skeleton. Task #3 picks the path; v2 says "one or the other, pick now."
- **Irelia** — retired. Must be removed from the live roster per the retirement procedure below. Her directory moves to `agents/.retired/irelia/` or is deleted. Her row leaves `agent-network.md`.
- **Rakan, Shen** — unclear status. Must be classified: active (then they need model-tier, `.claude/agents/` file, parity row) or retired (then the retirement procedure runs on them). No middle ground.

### 1.2 Agent model-tier declaration (new hard rule)

**Protocol invariant:** every `.claude/agents/<name>.md` file MUST declare a `model:` frontmatter field. The legal values and their semantics:

| `model:` value | Used for | Tier rationale |
|---|---|---|
| `opus` | Planners, coordinators, architects. Write plans, design systems, route work. Never execute. | Judgment work, long-horizon design, expensive to run but high leverage per token. |
| `sonnet` | Executors and reviewers. Implement plans, run tests, review PRs, ship code. Always read a plan file before working. | Strong execution tier; correct judgment/cost tradeoff for implementation work. |
| `haiku` | Minions. Bounded, mechanical, pattern-match tasks: retrieval, mechanical edits, shell-wrapping, status reports. | Cheap, fast, no interpretation surface; hallucinations must be controlled by contract not tier. |

No agent inherits its model tier from the parent session. Inheritance produced the silent-degradation class of bugs (an Opus agent running accidentally on Sonnet during a Sonnet parent session, producing worse plans than expected, with nobody noticing until a week later). The `model:` field is load-bearing.

**Role-to-tier authoritative mapping (per CLAUDE.md Rule 15, as landed 2026-04-09):**

- Opus: Evelynn, Syndra, Swain, Pyke, Bard.
- Sonnet: Katarina, Lissandra, Yuumi, Ornn, Fiora, Reksai, Neeko, Zoe, Caitlyn, Shen.
- Haiku: Poppy.

This mapping is already authoritative in `CLAUDE.md` Rule 15; v2 pins it here so that onboarding, retirement, and the audit/migration plan all read from the same target. Notable implications:

- **Yuumi is Sonnet**, not Haiku. The minion-tier default from continuity-and-purity's language does not apply to her — her role (errand runner, multi-step file moves, script execution with reporting) is judgment-adjacent and Rule 15 assigns Sonnet.
- **Shen is on the live roster as Sonnet.** Pyke's audit §1 flagged Shen as "not in `agent-network.md`, active-or-retired unclear." Rule 15's mapping resolves the question: active, Sonnet tier. Task #3 must add Shen's row to `agent-network.md` and confirm his `.claude/agents/shen.md` declares `model: sonnet`.
- **Rakan and Irelia are absent from Rule 15.** That is consistent with Irelia's retirement and with Rakan being pre-retirement-decision territory. Task #3 retires Irelia via the procedure below. Rakan is an open question for Duong (see §"Open questions" item 5).
- **Zilean and Ionia are not yet on Rule 15** because neither ships until continuity-and-purity lands. When they do, their `.claude/agents/*.md` files must declare `model: haiku` (Zilean, retrieval-only) and `model: sonnet` (Ionia, per Component A's judgment-tier rationale) respectively, and Rule 15 should be amended to list them.

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

**Retirement procedure** (new rule; pyke §8.3 explicitly flagged this as missing):

1. Add `retired: YYYY-MM-DD` and `retirement-reason: <one-line>` to the agent's `profile.md` frontmatter.
2. Move `agents/<name>/` → `agents/.retired/<name>/`. Preserve history via `git mv`, not delete + re-add.
3. Delete `.claude/agents/<name>.md` entirely. A retired agent cannot be invoked by the harness.
4. Remove the row from `agents/memory/agent-network.md` roster. Add a footnote under a "Retired" section listing name + retirement date + retirement reason.
5. Remove the row from `architecture/platform-parity.md` if present.
6. Do NOT retroactively delete the agent's prior learnings, journals, transcripts, or historical plan authorship. Those are history.
7. All of the above in a single commit with `chore: retire <name> agent`.

**Pyke §8.3 cleanup targets on retirement procedure adoption:** Irelia (retired already per prior decision, cleanup incomplete). Possibly Rakan/Shen pending classification.

---

## Layer 2 — CLAUDE.md rule updates

This section lists the rule changes v2 requires in `CLAUDE.md`. Every change is phrased as "current text → v2 text" or "new rule N (exact text)." v2 does not edit `CLAUDE.md` directly — the detailed phase of this plan (if approved and detailed) does, or Task #3's migration plan rolls them into its commits. This plan just pins the target.

### 2.1 Rule 6 (Sonnet agents must never work without a plan file) — tightened

Current: "Sonnet agents must never work without a plan file — Sonnet agents execute, they don't design. Every delegated task to a Sonnet agent must reference a plan file in `plans/`."

**v2 replacement:** "Sonnet agents must never work without a plan file in `plans/ready/` or `plans/in-progress/`. Sonnet agents execute; they don't design. The plan must be detailed enough that the executor makes no design judgment calls (per plan-lifecycle-protocol-v2's detailed-plan bar). If a Sonnet agent encounters ambiguity, they stop and escalate to Evelynn rather than improvising."

Depends on: `plans/proposed/2026-04-08-plan-lifecycle-protocol-v2.md` introducing `plans/ready/`. Until that plan lands, Rule 6 keeps saying `plans/` and v2 notes the future tightening.

### 2.2 Rule 7 (Plan approval gate & Opus execution ban) — tightened

Current text is load-bearing already. v2 adds one sentence: "Opus agents take no `Edit`, `Write`, `Bash` (non-read-only), or `git` actions outside their own memory/learnings files. If an Opus agent is tempted to make an edit directly, they stop and dispatch a minion (Poppy for mechanical edits, Yuumi for errands, Katarina for engineering). The continuity-and-purity plan's Component C tripwire recommendation is the enforcement mechanism for this clause at the discipline layer; v2 pins it as the target."

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

1. **Rule 7 tripwire placement.** The continuity-and-purity plan Component C recommends a pre-action self-check tripwire for Evelynn and defers its home to "the rules restructure plan." v2 is that plan. Duong's call: does the tripwire go in `CLAUDE.md` Rule 7 text (declarative), in Evelynn's profile (identity-scoped), or as a Claude Code harness hook (enforcement-scoped)? **Swain's lean: Evelynn's profile AND Rule 7 text.** Both surfaces. The profile is where Evelynn rereads it at startup; Rule 7 is where other Opus agents absorb it via osmosis. Harness hooks are brittle and platform-specific; skip.

2. **Haiku baseline for minions, or Sonnet?** v2 declares Haiku as the minion default with Ionia (the condenser) as a documented Sonnet exception. Continuity-and-purity Component A recommends Sonnet for Ionia because "lossy-but-faithful summarization of multi-thousand-line transcripts is above Haiku's rated tier." Duong's call: accept the exception, or force Ionia to Haiku with stricter contracts?

3. **Roster consolidation path.** Two options: (a) delete `agents/roster.md` and consolidate into `agents/memory/agent-network.md`; (b) keep `agents/roster.md` as a thin pointer file that links to `agents/memory/agent-network.md`. Swain's lean: (a), delete it. Less surface, fewer ways to drift. But (b) is gentler if any tooling still references `roster.md`.

4. **Retirement target directory — `.retired/` or outright delete?** The procedure above proposes `agents/.retired/<name>/`. Alternative: hard delete and rely on git history. Swain's lean: `.retired/` for the first retirement (Irelia) as a documentation artifact, then evaluate whether the directory provides ongoing value. If nobody reads it in a month, hard delete going forward.

5. **Model tier for Lissandra, Caitlyn, and any other currently-ambiguous agents.** The baseline mapping above is Swain's best-guess. Duong may want to override. v2's detailed phase (if approved) or Task #3 must confirm with Duong agent-by-agent before committing the `model:` field.

6. **Pyke §8.7 — stale plans in `plans/proposed/`.** Four plans from 2026-04-03 to 2026-04-05 are stuck. Does v2 add a staleness-TTL rule (e.g., a plan in `proposed/` with no update for N days gets auto-archived), or is that the plan-lifecycle-v2 plan's job? Swain's lean: let plan-lifecycle-v2 own it; v2 just flags that it needs to exist.

7. **Where does `architecture/platform-parity.md` get maintained?** It's created by Phase 1 detailed MCP restructure and v2 pins it as the single source of truth. But who maintains it as new artifacts land? Swain's lean: the `draft-plan` and `detailed-plan` skills from plan-lifecycle-v2 must include a "parity row update" reminder in their body. Skill-level enforcement, not a hook.

8. **Agent identity in SendMessage vs inbox.** In subagent mode (this session), agents communicate via SendMessage. In top-level mode, they write to `agents/<name>/inbox/`. v2 treats these as two surfaces for the same primitive; the agent's code doesn't change. But is this actually equivalent, or does SendMessage introduce auditability gaps the inbox path doesn't have? **Flagging — not blocking v2 approval, but worth a follow-up plan if the gap is real.**

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
