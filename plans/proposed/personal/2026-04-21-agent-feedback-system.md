---
status: proposed
concern: personal
owner: lux
created: 2026-04-21
orianna_gate_version: 2
tests_required: false
complexity: complex
tags: [feedback, meta-tooling, agent-system, continuous-improvement, shared-rules]
related:
  - plans/proposed/personal/2026-04-21-daily-agent-repo-audit-routine.md
  - plans/proposed/personal/2026-04-21-retrospection-dashboard.md
  - plans/proposed/personal/2026-04-21-coordinator-decision-feedback.md
  - plans/approved/2026-04-20-strawberry-inbox-channel.md
  - feedback/2026-04-21-orianna-signing-latency.md
  - feedback/2026-04-21-phase-discipline-approved-vs-in-progress.md
  - architecture/agent-pair-taxonomy.md
  - architecture/key-scripts.md
---

# Continuous agent-feedback system

## 1. Context

Duong's 2026-04-21 framing:

> "A lot of the times things happen that we did not expect and it slow us down — the system is supposed to streamline the process and make things faster, not slower. I want a continuous feedback system where agents and subagents can write feedback to, like what went wrong and suggestions to improve the system. This should be broadcast to all agents and encourage them to write feedback if they encounter a problem and they think it could be improved. We should add to routine run to consolidate feedback into improvement ideas."

Today the `feedback/` folder exists at the repo root with two ad-hoc entries (`feedback/2026-04-21-orianna-signing-latency.md`, `feedback/2026-04-21-phase-discipline-approved-vs-in-progress.md`). Both are high-signal — the first surfaced a real 15-30 min/sign latency problem with four concrete speedup options; the second surfaced a coordinator-discipline norm worth codifying. Both exist because Sona wrote them unprompted, not because the system invited the write. <!-- orianna: ok -->

The gap the framing identifies is structural:

- There is no **schema** — the two existing entries share a shape by accident. Future entries will drift unless a schema is declared.
- There is no **trigger heuristic** — agents currently write feedback when they happen to feel moved. Most friction events pass silently because the LLM prioritizes "finish the task" over "pause and document the pain."
- There is no **broadcast** — nothing causes Evelynn or Sona to read new feedback on session start, and nothing surfaces feedback to subagents who might benefit from a sibling's lesson.
- There is no **consolidation** — feedback entries accumulate and stay ad-hoc. They never become improvement ideas, ADRs, or rule changes unless a human hand-sweeps them.

### 1.1 Scope of this ADR vs sibling plans

Three concurrent personal ADRs touch adjacent ground; this ADR stays narrowly in the agent-authored-feedback lane:

| Plan | Scope | Relationship |
|---|---|---|
| `plans/proposed/personal/2026-04-21-daily-agent-repo-audit-routine.md` | Drift detection against checked-in state (dead refs, rule duplication, upstream features) — mechanical | Sibling: the audit routine emits findings against the repo; this ADR emits feedback from agents about their own lived friction. Different source, same consolidation cadence. §D7 integrates the two into one daily run. | <!-- orianna: ok -->
| `plans/proposed/personal/2026-04-21-retrospection-dashboard.md` | What did the agent system do, render history | Consumer: the retro dashboard can surface open feedback counts as a health tile; schema commitment in §D8. | <!-- orianna: ok -->
| `plans/proposed/personal/2026-04-21-coordinator-decision-feedback.md` | Duong's decisions — predictions, calibration | Orthogonal: decision-feedback tracks Duong's choices; this ADR tracks agent-lived friction. No shared state. | <!-- orianna: ok -->
| `plans/approved/2026-04-20-strawberry-inbox-channel.md` | Cross-session inbox delivery | Integration: the consolidation digest rides into Evelynn's inbox via the same Monitor-based channel. <!-- orianna: ok --> |

## 2. Decision

Adopt a five-layer continuous-feedback system:

1. **Write layer** — a single file-shape (schema in §D1) dropped into `feedback/` by any agent that hits a defined trigger (§D2). Every tier writes into the same folder; no per-agent silos. <!-- orianna: ok -->
2. **Broadcast layer** — a lightweight boot-chain include (§D3) makes every coordinator session (Evelynn, Sona) see an auto-generated `feedback/INDEX.md` of open entries <7 days old. Subagents do NOT eagerly read feedback; Skarner routes on-demand queries when relevant. <!-- orianna: ok -->
3. **Encouragement layer** — a new `_shared/feedback-trigger.md` stanza inlined into every `.claude/agents/*.md` via the existing `scripts/sync-shared-rules.sh` mechanism (§D4). Prescriptive triggers the LLM will actually obey. <!-- orianna: ok -->
4. **Ritual layer** — three integration points that bake feedback-writing into existing session rituals (§D4A): a new `/agent-feedback` skill for on-demand one-minute emission (invocable by **coordinators and subagents both**), a new reflection step inside `/end-session`, and a matching reflection step inside `/pre-compact-save` (executed by Lissandra on the coordinator's behalf). Subagent self-invocation is a first-class path, not a special case — any agent that hits a §D2 trigger mid-task may invoke `/agent-feedback` directly. The shared-rules inline is what makes agents *think* about feedback; the ritual layer is what makes them *actually write it* at known reflection points.
5. **Consolidation layer** — a weekly rollup (Sunday 07:05 Asia/Bangkok, piggybacked on the daily audit routine's infrastructure) dispatches Lux + Karma to produce a feedback digest at `assessments/feedback-digests/YYYY-MM-DD.md` (§D5). High-signal items graduate to proposed plans; stale items are pruned. <!-- orianna: ok -->

### 2.1 Shape in one paragraph

An agent hits a friction trigger — unexpected hook block, schema surprise, retry loop >2, tool permission denial, documentation that contradicts reality, a review cycle that took >3 iterations, or a surprise that cost >5 minutes. Before continuing the task, the agent invokes the new `/agent-feedback` skill, which prompts for the four key fields (what-went-wrong, suggestion, friction-cost-minutes, category) and writes a `feedback/YYYY-MM-DD-HHMM-<author>-<kebab-slug>.md` file following the §D1 schema — targeted ~1 minute round-trip so the ceremony does not deter use. At session close, `/end-session` (for Sona + Evelynn) runs a reflection step that emits at least one feedback entry if the session hit any trigger, or skips with a logged "no friction worth writing" if the session was smooth. Lissandra's `/pre-compact-save` mirrors the same reflection step before compact on the coordinator's behalf. The pre-commit hook auto-appends the filename to `feedback/INDEX.md` (timestamp-sorted, open-state only). Evelynn's startup chain reads `feedback/INDEX.md` and surfaces the count + top-3 `high`-severity entries. Sunday's routine dispatches Lux (categorize + dedupe) and Karma (triage into action-or-drop) to produce a weekly digest committed to `assessments/feedback-digests/`. Digest items marked `graduate` become follow-up proposed ADRs; items marked `keep-open` roll over; items marked `stale` move to `feedback/archived/`. <!-- orianna: ok -->

### 2.2 Scope — out

- **No blocking behavior.** Writing feedback never blocks the task that triggered it. The agent writes and continues. No hook prevents a commit because "you should write feedback for this."
- **No LLM-generated feedback on an LLM's behalf.** Each feedback entry is authored by the agent that lived the friction. Coordinators do not write feedback on behalf of subagents they dispatched.
- **No paid service.** Files + git + existing Monitor inbox only. No Slack, no email, no SaaS.
- **No work-concern/personal-concern split on feedback files.** Agents accumulate knowledge globally per `CLAUDE.md` §Scope. A single `feedback/` folder serves both concerns; frontmatter `concern:` tags origin. <!-- orianna: ok -->
- **No automatic promotion to ADRs.** The consolidation digest recommends graduation; Duong (or Evelynn on Duong's standing delegation) confirms before a plan scaffold is created.
- **No feedback on feedback.** The digest does not introspect itself. Meta-feedback is a human-only sidebar if/when it matters.
- **No retroactive backfill.** The two existing entries (`feedback/2026-04-21-orianna-signing-latency.md`, `feedback/2026-04-21-phase-discipline-approved-vs-in-progress.md`) are migrated to the new schema as part of Phase 1 (§6) but no historical journal-mining.

## 3. Design

### D1. Write path — file schema and naming

**Filename:** `feedback/YYYY-MM-DD-HHMM-<author>-<kebab-slug>.md`. <!-- orianna: ok -->

- Date+time prefix in local Asia/Bangkok for sort-ability (same timezone as all other repo timestamps; confirm in §OQ1).
- `<author>` is the agent's canonical name (lowercase, as in `.claude/agents/<name>.md`). Coordinators use `evelynn` / `sona`; subagents use their own name. <!-- orianna: ok -->
- `<kebab-slug>` is 2-5 words describing the friction, no leading articles. Example: `orianna-signing-latency`, `phase-discipline-approved-vs-in-progress`.

**Frontmatter schema** (every field required unless marked optional):

```yaml
---
date: 2026-04-21
time: "15:42"
author: sona
concern: work            # work | personal
category: hook-friction  # see category enum below
severity: medium         # low | medium | high
friction_cost_minutes: 15
related_plan: plans/in-progress/work/2026-04-20-managed-agent-dashboard-tab.md  # optional
related_pr: https://github.com/Duongntd/strawberry-agents/pull/123              # optional
related_commit: 71fd8a5  # optional
related_feedback: []     # optional, list of prior feedback filenames this supersedes or amends
state: open              # open | acknowledged | graduated | stale
---
```

**Category enum** (fixed; extensions require a doc-level edit to this ADR):

| Category | Meaning |
|---|---|
| `hook-friction` | A git hook, pre-commit hook, or CI gate blocked the agent unexpectedly. |
| `schema-surprise` | A file format, frontmatter field, or CLI arg surprised the agent (mismatch with docs or memory). |
| `tool-missing` | A capability the agent needed did not exist (no script, no skill, no MCP server). |
| `tool-permission` | A capability existed but the agent's tool permissions blocked it. |
| `doc-stale` | Documentation or memory disagreed with reality. |
| `review-loop` | A review/sign/fact-check cycle took >3 iterations or >15 minutes. |
| `coordinator-discipline` | A coordinator-side norm was violated or is missing (e.g. phase discipline, dispatch ordering). |
| `retry-loop` | An operation was retried >2 times before success. |
| `context-loss` | Agent lost context due to a predictable cause (compact, cross-session, missing memory). |
| `other` | Anything not covered above — the consolidation pass may split this into a new category later. |

**Severity semantics** (mirrors `plans/proposed/personal/2026-04-21-daily-agent-repo-audit-routine.md` §D4 for cross-system consistency): <!-- orianna: ok -->

| Severity | Meaning | Typical consolidation disposition |
|---|---|---|
| `high` | Active blocker or repeat offense; the agent would hit this again tomorrow. | Graduate to ADR within one week. |
| `medium` | Non-blocking but correct-but-slow; batchable with sibling friction. | Aggregate in digest; graduate if ≥3 siblings. |
| `low` | One-off observation or low-confidence suggestion. | Accumulate quietly; prune after 30 days. |

**Body structure** (required sections, in order):

```markdown
# <Title matching the slug>

## What went wrong
<2-6 sentences — concrete, factual, with file paths or commit SHAs where relevant.>

## Suggestion
<1-3 bullet options, each with a rough effort estimate (S/M/L) and a named owner candidate.>

## Why I'm writing this now
<1-2 sentences on the trigger — which of the §D2 triggers fired.>
```

The two existing entries already fit this body structure almost exactly; the migration (§6 T1) only adds frontmatter.

### D2. Trigger heuristic — when to write

Writing feedback is a **small, prompt-driven action** with an explicit decision rule. The shared-rules include (§D4) carries this exact text to every agent.

**Write feedback immediately — before continuing the current task — when ANY of these fire:**

1. **Unexpected hook/gate block.** A git hook, pre-commit hook, Orianna sign, CI gate, or branch-protection rule blocked you in a way you did not anticipate from the context/prompt.
2. **Schema/docs mismatch.** You read a schema (frontmatter, CLI arg, filename convention, rule number) in one place and found it stated differently in another place — or found reality contradicted both.
3. **Retry loop >2.** You retried the same operation (tool call, script, sign, build, test) more than twice with the same inputs before it succeeded. Each additional retry is a signal the first attempt shape is wrong.
4. **Review/sign cycle >3 iterations.** An Orianna sign, a Senna/Lucian review, or a fact-check took more than three round trips before clean.
5. **Tool missing or permission-blocked.** You needed a capability (a script, a skill, an MCP server, a tool in your allowed list) and it did not exist or was denied.
6. **Coordinator-discipline slip.** (Coordinators only.) You noticed a bookkeeping step (phase flip, inbox scan, learning save) you should have done earlier and didn't.
7. **Surprise costing >5 minutes.** Anything not covered above that cost you more than five minutes of task time because reality did not match your expectation.

**Do NOT write feedback for:**

- Expected friction (the test failed because you wrote the test wrong — that's the loop working).
- Transient infrastructure issues (the network glitched once).
- User-caused corrections (Duong said "do X differently" — that's steering, not friction).
- Things you can fix in the same session in <5 minutes.

**Budget:** writing a feedback entry costs ~3-5 minutes (think + frontmatter + body). The trigger list is calibrated so most tasks produce zero entries, some produce one, and a cross-cutting pain day produces 2-3. If an agent finds itself writing >3 per session, Lux is notified via inbox for a deeper look at whether the triggers are too sensitive or whether that session uncovered a structural issue.

### D3. Broadcast path — how agents discover feedback

**Pick: boot-chain include for coordinators + on-demand Skarner route for subagents.**

Justification — three candidates evaluated against the two-layer boot memory system shipped in `plans/in-progress/personal/2026-04-21-memory-consolidation-redesign.md`:

| Option | Pro | Con | Verdict |
|---|---|---|---|
| (A) Append every entry to every agent's `agents/<name>/inbox/` | Strong delivery guarantee; matches the existing inbox-channel pattern. | Heavy — 30 agents × every feedback = inbox explosion. Evelynn just pruned inboxes for exactly this reason. | Rejected. | <!-- orianna: ok -->
| (B) `feedback/INDEX.md` coordinators read on startup; subagents read on demand | Lightweight; one file updated by pre-commit hook. Coordinators see the count + top-3 in their boot chain. Subagents can ask Skarner when they suspect a sibling has hit a similar friction. | Subagents may miss signal a coordinator never surfaces to them. | **Chosen** — the "encourage writing" cost is LOW when the coordinator is the one most likely to act. Subagents can read on demand. | <!-- orianna: ok -->
| (C) Boot-chain include loading recent (<7d) feedback on every session | Universal reach — every subagent sees everything. | Heavy token cost every session; pollutes short-lived subagent contexts with concerns they can't act on. | Rejected — violates the two-layer boot minimization goal. |

**Coordinator boot chain** — one line added to Evelynn's `agents/evelynn/CLAUDE.md` startup block and Sona's `agents/sona/CLAUDE.md` startup block: <!-- orianna: ok -->

```
3a. Read feedback/INDEX.md — the first 20 lines. If count_open_high > 0, surface to Duong at first opportunity.
```

**Subagent on-demand route** — Skarner (the retrieval agent at `.claude/agents/skarner.md`) learns a new query kind `feedback-search <category|severity|author|keyword>` that greps `feedback/INDEX.md` + open feedback files. Dispatched by any subagent who thinks "wait, did someone already hit this?" — the trigger is self-initiated, not eager. §D4's shared-rules stanza names Skarner as the route for "has another agent seen this?" curiosity. <!-- orianna: ok -->

**`feedback/INDEX.md` format** (machine-writable, human-readable): <!-- orianna: ok -->

```markdown
# Open feedback index

_Auto-generated by `scripts/feedback-index.sh`. Do not hand-edit._ <!-- orianna: ok -->
_Generated: 2026-04-21T15:45:00+07:00_

| Severity | Date       | Author  | Category              | Slug                                      | Cost (min) |
|----------|------------|---------|-----------------------|-------------------------------------------|------------|
| high     | 2026-04-21 | sona    | review-loop           | orianna-signing-latency                   | 30         |
| medium   | 2026-04-21 | sona    | coordinator-discipline| phase-discipline-approved-vs-in-progress  | 10         |

Open: 2 | High: 1 | Medium: 1 | Low: 0
Graduated (this week): 0
Stale (pending prune): 0
```

The index is regenerated by `scripts/feedback-index.sh` on every pre-commit that touches `feedback/**.md`. Hook logic: if the diff touches `feedback/*.md`, regenerate `feedback/INDEX.md` and stage it as part of the same commit. See §D6 for the hook implementation. <!-- orianna: ok -->

**Why not eager-broadcast the content of feedback to subagents:** most feedback is coordinator-shaped (phase discipline) or cross-cutting (sign latency). A subagent who reads all 20 open entries every session burns tokens on context that rarely changes what it does. The on-demand Skarner route preserves the escape hatch for the rare case where a subagent does benefit ("I'm about to hit the same hook — did anyone else?").

### D4. Encouragement mechanic — shared-rules inline

**Pick: a new `_shared/feedback-trigger.md` stanza inlined into every paired agent definition via the existing include-and-sync mechanism.** <!-- orianna: ok -->

The repo already runs a sync-shared-rules pattern: ten files live under `.claude/agents/_shared/` (`ai-specialist.md`, `architect.md`, `breakdown.md`, `builder.md`, `frontend-design.md`, `frontend-impl.md`, `quick-executor.md`, `quick-planner.md`, `test-impl.md`, `test-plan.md`), each inlined into matching agent defs via `<!-- include: _shared/<role>.md -->` markers, resynced by `scripts/sync-shared-rules.sh`. The feedback-trigger text piggybacks on this mechanism. <!-- orianna: ok -->

**Shape:** a new file `.claude/agents/_shared/feedback-trigger.md` (~35 lines) carrying the trigger heuristic from §D2 plus a two-sentence instruction on the file-write ceremony. Inlined into every existing `_shared/<role>.md` via an `<!-- include: _shared/feedback-trigger.md -->` marker at the bottom of each shared role file. Nested include is resolved by `scripts/sync-shared-rules.sh` in a second pass (see §D4.1). <!-- orianna: ok -->

**Why inline rather than a top-level CLAUDE.md rule:**

- A new universal invariant in `CLAUDE.md` (e.g. rule #20) is coordinator-read on boot. But subagents don't read top-level `CLAUDE.md` in full on every spawn — their agent def is the binding context. Putting the trigger in a universal rule would miss the subagent population that produces most of the friction signal.
- The shared-rules pattern is already load-tested. Every paired agent already gets a `_shared/<role>.md` inlined into their def. Adding one more stanza to each `_shared/*.md` file is the lowest-disruption path to universal reach. <!-- orianna: ok -->
- Text-level reach beats link-level reach. An LLM is dramatically more likely to actually obey a trigger that is five paragraphs into its own agent def than a trigger that is a one-line pointer to another file.

**Content of `_shared/feedback-trigger.md`** (target body, ~35 lines): <!-- orianna: ok -->

```markdown
## Feedback trigger — write when friction fires

You are part of a system that improves continuously only if agents emit signal when things go wrong.

**Write a feedback entry immediately — before continuing the current task — when ANY of these fire:**

1. Unexpected hook/gate block (git hook, Orianna sign, CI, branch protection).
2. Schema or docs mismatch (one source says X, another says not-X, reality says Y).
3. Retry loop >2 on the same operation with the same inputs.
4. Review/sign cycle >3 iterations.
5. Tool missing or permission-blocked.
6. Coordinator-discipline slip (coordinators only).
7. Surprise costing >5 minutes because expectation ≠ reality.

**How to write — invoke the `/agent-feedback` skill:**

The skill handles filename derivation, frontmatter synthesis, and (for coordinators) commit ceremony. Target total time: 60 seconds.

- **If you are a coordinator** (Evelynn / Sona) or Lissandra impersonating one: the skill writes AND commits immediately with prefix `chore: feedback — <slug>`.
- **If you are a subagent** (Viktor, Senna, Yuumi, Vi, Jayce, etc.): the skill writes the file to the working tree but does NOT commit — your `/end-subagent-session` sweep picks it up at session close in a single `chore: feedback sweep —` commit. This keeps your feature-branch diff scope clean.

Either way, you invoke the same skill: `/agent-feedback`. Supply four fields when prompted: category (from the §D1 enum), severity, friction-cost in minutes, and a short "what went wrong + suggestion" free-form. Schema: `plans/proposed/personal/2026-04-21-agent-feedback-system.md` §D1. <!-- orianna: ok -->

After the skill returns (filename + optionally commit SHA), continue your original task.

**Do NOT write feedback for:** expected failures (a red test that you expected to be red), transient network issues, user-steering ("Duong said X instead"), or things you can fix in <5 minutes without changing the system.

**Budget:** most sessions produce zero entries. A cross-cutting pain day produces 2-3. If you find yourself writing >3 per session, notify Lux via `agents/lux/inbox/` — either the triggers are too sensitive or that session uncovered a structural issue worth a deeper look. <!-- orianna: ok -->

**Curious whether a sibling agent already hit your friction?** Ask Skarner: dispatch with `feedback-search <keyword>` before writing a duplicate entry.
```

#### D4.1 Nested-include resolution

`scripts/sync-shared-rules.sh` currently resolves one level of include — a paired agent def with `<!-- include: _shared/<role>.md -->` gets the shared file inlined. To support nested includes (the feedback-trigger stanza inside each `_shared/<role>.md`), the sync script gains a second pass: <!-- orianna: ok -->

1. Pass 1 (existing): inline `_shared/<role>.md` content into agent defs carrying the include marker. <!-- orianna: ok -->
2. Pass 2 (new): after pass 1, scan the expanded agent defs for `<!-- include: _shared/feedback-trigger.md -->` markers (which came from the `_shared/<role>.md` files themselves) and inline `_shared/feedback-trigger.md`. <!-- orianna: ok -->
3. Idempotency preserved: running twice produces identical output.

Alternatively, `sync-shared-rules.sh` could resolve includes recursively to arbitrary depth. Depth-2 is sufficient for this ADR; depth-N is deferred to a follow-up if/when a second nested include is needed. §6 T3 implements depth-2; §OQ2 gates the question of depth-N. <!-- orianna: ok -->

#### D4.2 Interaction with existing `_shared/*.md` files <!-- orianna: ok -->

Ten files receive the include marker. No other text changes are made to `_shared/*.md` files in this ADR — the trigger stanza is strictly additive. The `scripts/lint-subagent-rules.sh` check (which verifies shared-rule drift) extends to also verify that each `_shared/<role>.md` carries exactly one `<!-- include: _shared/feedback-trigger.md -->` marker. <!-- orianna: ok -->

### D4A. Ritual layer — `/agent-feedback`, `/end-session`, `/pre-compact-save`

Shared-rules text (§D4) makes agents *aware* of the trigger heuristic. Rituals are what convert awareness into behavior — on-demand writing does not reliably happen unless it is baked into the sessions' existing reflection points. Three integration points, each first-class:

#### D4A.1 `/agent-feedback` skill — on-demand one-minute emission

**New skill at `.claude/skills/agent-feedback/SKILL.md`.** <!-- orianna: ok --> Any agent (coordinator or subagent) invokes `/agent-feedback` when a trigger fires to emit an entry in ~60 seconds.

**Naming note — why `/agent-feedback` not `/feedback`:** `/feedback` is a reserved Claude Code built-in slash command; colliding with it would create confusing dispatch behavior. The `agent-` prefix scopes the name to our system and matches the `agents/` folder and subject-matter convention already used across the repo. <!-- orianna: ok -->

**The skill supports two first-class invocation modes** — a coordinator mode and a subagent mode — with different commit behavior to match each caller's normal session shape.

**Mode A — coordinator self-invocation (or Lissandra-on-behalf):**

- Caller: Evelynn, Sona, or Lissandra impersonating a coordinator.
- Context: either mid-session (on-demand trigger hit) or during `/end-session` / `/pre-compact-save` reflection.
- Commit: immediate. The skill writes the file AND commits with `chore: feedback — <slug>`. Coordinators routinely commit during a session, so an extra commit is consistent with their normal flow.

**Mode B — subagent self-invocation mid-task:**

- Caller: any subagent (Viktor in a build loop, Senna blocked by a schema mismatch, Yuumi bounced by a permission prompt, Vi hitting an unexpected xfail-gate behavior, Jayce finding a documented script has been renamed, etc.).
- Context: a §D2 trigger fires during the subagent's task. The subagent invokes `/agent-feedback`, writes the entry, returns to the task within ~1 minute.
- Commit: **deferred.** The skill writes the feedback file to the working tree but does NOT commit. Subagents often do not commit unrelated work during their session (their output is a PR branch, or a handoff report). Forcing a mid-task commit would both derail the subagent's normal flow and risk mixing the feedback commit into a logically-unrelated diff (e.g. `chore: feedback —` on a `feat:`-scoped branch).
- **Sweep at session close:** the subagent's `/end-subagent-session` protocol gains one new step (§D4A.5): check for any uncommitted `feedback/*.md` files, and if present, stage + commit them as a single `chore: feedback sweep — <agent-name> — <date>` commit at the very end of session close, after the normal handoff/learnings commit. If `/end-subagent-session` is not reached (session aborted / timeout), the files remain in the working tree and the dispatching coordinator's `/end-session` sweeps them (already-scoped sweep step described in §D4A.5). <!-- orianna: ok -->

**Skill contract (unified body — branching on caller at invocation):**

```markdown
# /agent-feedback — emit a feedback entry

Detect caller type from context:
- If the invoking agent is a coordinator (Evelynn, Sona) or Lissandra: mode = A.
- Otherwise: mode = B (subagent).

Prompt the caller for the four core fields in order:

1. **Category** (show the enum from §D1 of plans/proposed/personal/2026-04-21-agent-feedback-system.md; pick one).
2. **Severity** (low | medium | high; default medium).
3. **Friction cost** (integer minutes).
4. **What went wrong + suggestion** (free-form; skill synthesizes into the §D1 body structure).

Then:
1. Derive `<kebab-slug>` from the first line of "what went wrong" (2-5 words, no leading articles).
2. Compose filename `feedback/YYYY-MM-DD-HHMM-<author>-<kebab-slug>.md` using Asia/Bangkok local time. `<author>` is the invoking agent's canonical name. For mode A when Lissandra impersonates, use the coordinator name, not "lissandra". <!-- orianna: ok -->
3. Write the file with §D1 frontmatter + three-section body.
4. **Mode A:** git add + commit with prefix `chore: feedback — <slug>`. Pre-commit hook regenerates feedback/INDEX.md. Report filename + SHA back to caller.
5. **Mode B:** leave the file uncommitted in the working tree. Do NOT stage, do NOT commit. Report filename back to caller. The sweep happens at /end-subagent-session (or coordinator's /end-session if subagent session does not reach close).

The caller then resumes their original task. Target total time: 60 seconds.
```

**Why a skill rather than raw file-write:** skills are the existing mechanism for compact, well-shaped ceremonies (see `.claude/skills/end-session/SKILL.md`, `.claude/skills/pre-compact-save/SKILL.md`). A skill invocation is lower cognitive cost than "write a file with these fields" — the prompt structure is enforced by the skill body, not by the agent remembering the schema. The ~1-minute budget is achievable because the skill does the frontmatter synthesis, filename derivation, and (for mode A) commit ceremony — the caller only supplies four fields of content. <!-- orianna: ok -->

**Why two commit modes rather than one:** a subagent that commits a feedback file mid-PR-task introduces a commit into its feature branch that does not belong to the feature. The diff-scope rule (CLAUDE.md rule 5) requires the commit's prefix match its diff; `chore:` on a `feat:`-scoped branch is awkward and may interact badly with release-please. Leaving feedback uncommitted in-session and sweeping at close keeps the feature branch's logical diff clean while still capturing the signal.

**Subagent invocation is first-class, not a special case.** Shared-rules text in `_shared/feedback-trigger.md` (§D4) is identical for coordinators and subagents — it directs every tier to `/agent-feedback` when a trigger fires. The skill detects caller-type and branches internally. Every paired agent definition in `.claude/agents/*.md` reaches the same instruction via the `_shared/<role>.md → _shared/feedback-trigger.md` nested include. Subagent authors (Viktor, Senna, Yuumi, Vi, Jayce, and every other paired agent) are expected sources of feedback signal — probably the majority source, since subagents do the bulk of hands-on execution where friction originates. <!-- orianna: ok -->

#### D4A.2 `/end-session` reflection step

**Edit `.claude/skills/end-session/SKILL.md`** to add a new step in the protocol, inserted between the existing handoff-note/memory-shard/journal steps and the final commit. The coordinator (Sona or Evelynn — `/end-session` is coordinator-only per CLAUDE.md rule 8) performs this reflection with the full session in context. <!-- orianna: ok -->

**Reflection step body (to be inserted into `/end-session` SKILL.md):**

```markdown
## Step — session friction reflection (emit feedback if warranted)

Before the final commit, reflect on the session against the §D2 trigger list
from plans/proposed/personal/2026-04-21-agent-feedback-system.md:

1. Did any git hook / Orianna sign / CI / branch-protection rule block you
   unexpectedly?
2. Did any schema, doc, or memory surprise you (reality disagreed with what you
   read)?
3. Did you retry the same operation >2 times with the same inputs before
   success?
4. Did any review/sign cycle take >3 iterations?
5. Did you need a tool/script/skill/MCP that did not exist, or was blocked?
6. Did you (coordinator-discipline) slip on a bookkeeping step you should have
   done earlier?
7. Did any surprise cost >5 minutes because expectation ≠ reality?

**If the answer to any of 1-7 is yes:** invoke `/agent-feedback` now for the most
salient one (not every one — budget one entry per session unless multiple
high-severity events occurred). Use the coordinator as `author:`.

**If the answer to all 1-7 is no:** log a one-line note in the handoff shard —
"no feedback this session (all triggers clean)". This explicit null-output keeps
the mechanism honest — silence should mean "checked and clean", not "forgot to
check".

Then proceed to the final commit.
```

**Why `/end-session` rather than a pre-push hook:** session close is the moment when the coordinator has *the most complete view* of the session's friction. A hook at commit time sees only the diff; `/end-session` sees the full conversation. The reflection quality is materially better.

**Why coordinators only (not subagents' `/end-subagent-session`):** subagents have narrow scope and short horizons — they rarely accumulate the breadth of signal needed for a good feedback entry. Their path to emit is the on-demand `/agent-feedback` skill when a trigger fires mid-task. Subagent end-sessions stay narrow by design per the existing `.claude/skills/end-subagent-session/` protocol. If subagent-level feedback emerges as valuable later, §OQ7 gates that addition. <!-- orianna: ok -->

#### D4A.3 `/pre-compact-save` reflection step

**Edit `.claude/skills/pre-compact-save/SKILL.md`** and mirror the reflection step into Lissandra's protocol. `.claude/agents/lissandra.md` describes Lissandra as the pre-compact consolidator who speaks in the coordinator's voice; the feedback reflection fits naturally as a new step in her protocol, inserted between the existing memory-shard/journal steps and her final commit. <!-- orianna: ok -->

**Reflection step body (to be inserted into `/pre-compact-save` SKILL.md and cross-referenced in `.claude/agents/lissandra.md`):**

```markdown
## Step — pre-compact friction reflection (emit feedback if warranted)

You (Lissandra) are impersonating the active coordinator. Before your final
consolidation commit, run the same seven-trigger check as /end-session
(§D4A.2 of plans/proposed/personal/2026-04-21-agent-feedback-system.md):

1-7. Same seven triggers.

**If any triggered:** invoke /agent-feedback on the coordinator's behalf with
`author: <coordinator>` (not `author: lissandra` — you are speaking in the
coordinator's voice, and the feedback is the coordinator's observation). Use
severity and friction_cost_minutes based on the session evidence you have in
context.

**If none triggered:** log "no feedback this pre-compact (all triggers clean)"
in the handoff shard.

Then proceed to your final commit.
```

**Why mirror in `/pre-compact-save` rather than defer to `/end-session`:** compacts can happen far more often than `/end-session` invocations — a long session may compact 2-3 times before it ends. Deferring all feedback to `/end-session` would lose signal from the earlier portions of the session whose detail is precisely what a compact is about to discard. Capturing feedback at compact time preserves the evidence window.

**Voice invariant:** Lissandra writes in the coordinator's voice per her existing protocol. The feedback entry's `author:` is the coordinator's name (`evelynn` or `sona`), not `lissandra`. Lissandra's role is consolidator, not primary author — feedback authorship must align with the agent who lived the session.

#### D4A.4 Interaction between the four integration points

- `/agent-feedback` is the **atomic write primitive**. `/end-session`, `/pre-compact-save`, and subagent mid-task invocations all call it. There is exactly one file-writing code path; the two commit modes (§D4A.1) diverge only in whether the skill itself commits.
- A single session may produce 0, 1, or 2+ feedback entries: 0 if smooth; 1 if one trigger fired either mid-session (on-demand) or at close; 2+ if multiple distinct frictions warrant separate entries. The `/end-session` step budgets one entry per session unless multiple high-severity events occurred — this soft-cap prevents floods. Subagent mid-task invocations are not counted against this cap (they are live event-driven emissions, not reflection-driven).
- Double-writing is acceptable and expected in edge cases: a mid-session `/agent-feedback` for a specific hook block plus an `/end-session` entry for a cross-cutting pattern is two valid entries. The consolidation pass (§D5) will cluster them under one head entry if they share enough signal.
- No integration point writes feedback on behalf of any agent other than the active caller. Coordinators do not write feedback on behalf of subagents they dispatched; subagents do not write feedback on behalf of sibling subagents. Each agent emits its own friction.
- A subagent that dispatched *its own* subagents (rare — only Lissandra and a handful of coordinator-lookalike agents do this) does not aggregate their feedback. Every agent's feedback is first-person.

#### D4A.5 Subagent feedback sweep — `/end-subagent-session` addition

The existing `/end-subagent-session` skill at `.claude/skills/end-subagent-session/SKILL.md` runs at every subagent session close per CLAUDE.md rule 8. This ADR adds one step to that protocol, executed after the normal handoff/learnings commit and before the final session-exit report: <!-- orianna: ok -->

```markdown
## Step — feedback sweep (pick up mid-task /agent-feedback writes)

Check the working tree for any uncommitted files matching `feedback/*.md` <!-- orianna: ok -->
(new files, not edits to tracked files):

    git status --porcelain | grep -E '^\?\? feedback/[^/]+\.md$' || true

If one or more files are listed:
1. Stage them all: `git add feedback/*.md` (scoped).
2. Commit with prefix `chore: feedback sweep — <your-agent-name> — YYYY-MM-DD`.
   The pre-commit hook regenerates feedback/INDEX.md automatically.
3. Push per the normal session-exit protocol.

If no files are listed: skip silently. No log line needed — the sweep is
idempotent.
```

**Why a sweep rather than forcing mid-task commits:**

- Subagent feature branches' diff scope stays logically consistent (CLAUDE.md rule 5).
- Subagents that work in worktrees need only one extra commit at close, not N interspersed commits throughout the session.
- The sweep commit itself has `chore:` prefix matching its `feedback/**` diff scope — no rule violation. <!-- orianna: ok -->

**Coordinator fallback sweep:** if a subagent session aborts (crash, timeout, or the subagent never invokes `/end-subagent-session`), uncommitted `feedback/*.md` files remain in the working tree. The dispatching coordinator's `/end-session` protocol (edited per §D4A.2) includes the same sweep step as a final pass: any `feedback/*.md` files still uncommitted at coordinator close are swept with `chore: feedback sweep — <coordinator-name> — YYYY-MM-DD` (author is the coordinator, but the entries' own frontmatter `author:` fields preserve the original subagent attribution). <!-- orianna: ok -->

**Double-sweep safety:** if both the subagent's `/end-subagent-session` and the coordinator's `/end-session` attempt a sweep, the second finds nothing uncommitted and no-ops. The sweep is idempotent.

### D5. Consolidation routine — weekly rollup

**Cadence: weekly, Sunday 07:05 Asia/Bangkok.**

Not daily: feedback volume is low (2 entries in 24 hours is already a relatively high day). A daily digest would have too little signal most mornings. A weekly rollup accumulates 5-15 entries typically, which is enough shape to find clusters.

Not monthly: cluster-to-action latency matters. A weekly rhythm means a friction written on Monday gets triaged the following Sunday, with a follow-up plan potentially scaffolded within 7-10 days. Monthly would let signal rot.

**Owner: Lux (categorize + dedupe) + Karma (triage into action).** No new agent.

- **Lux** runs dimension 1: group feedback entries by category + similarity, flag duplicates, mark entries as `graduate` (worth an ADR), `keep-open` (valid but not yet actionable), or `stale` (superseded or no longer true). Opus-tier research is the right match — this is a categorization pass, not a mechanical one.
- **Karma** runs dimension 2: for every `graduate`-marked entry, draft a one-paragraph problem statement + a one-paragraph candidate solution + a proposed owner. Quick-lane planner is the right match — these drafts are pre-proposed-plan stubs, not full ADRs.
- Coordinator (Evelynn, not Sona — this is a repo-wide concern, personal-coordinator owns it) consolidates both outputs into the digest and commits.

**Piggybacked on the daily audit routine's Claude Code Routine infrastructure.** The Sunday run of `daily-agent-repo-audit` (from `plans/proposed/personal/2026-04-21-daily-agent-repo-audit-routine.md`) adds one more dispatched subagent pair for the feedback consolidation. Not a separate Routine — piggybacking avoids a second `/schedule` entry, reuses the same cost accounting budget (§D2 of that ADR), and keeps the audit-vs-feedback integration tight. §D7 details the integration. <!-- orianna: ok -->

**Output artifact: `assessments/feedback-digests/YYYY-MM-DD.md`.** One file per weekly run. Schema: <!-- orianna: ok -->

```markdown
---
date: 2026-04-21
run_id: <routine-execution-id>
feedback_window: 2026-04-14..2026-04-20
entries_processed: 12
entries_graduated: 2
entries_kept_open: 7
entries_marked_stale: 3
---

# Feedback digest — week of 2026-04-14..2026-04-20

## Graduated (candidate ADRs)

### 1. Orianna signing latency (3 entries clustered)
- **Source feedback:** `feedback/2026-04-21-orianna-signing-latency.md`, `feedback/2026-04-19-...`, `feedback/2026-04-17-...`
- **Problem:** Orianna sign takes 15-30 min per clean batch on work ADRs.
- **Candidate solution:** Ship `scripts/orianna-pre-fix-work-adr.sh` as a batch-fix pre-pass (from the source feedback's recommendation A).
- **Proposed owner:** Syndra (scripts) with Lux review
- **Draft ADR stub:** (2-paragraph problem+solution, ready for planner)

### 2. ...

## Kept open (not yet actionable)

- `feedback/2026-04-18-memory-drift-midsession.md` — low severity, one occurrence. Rolling forward to next week.
- ...

## Marked stale (archived this run)

- `feedback/2026-03-15-worktree-cleanup-slow.md` — superseded by `plans/implemented/2026-04-01-worktree-prune.md`. Moved to `feedback/archived/`. <!-- orianna: ok -->

## Cluster analysis (Lux)

| Category              | Count | High | Medium | Low |
|-----------------------|-------|------|--------|-----|
| review-loop           | 3     | 1    | 2      | 0   |
| coordinator-discipline| 2     | 0    | 2      | 0   |
| ...                   | ...   | ...  | ...    | ... |

## Raw sources
- `feedback/INDEX.md` snapshot at digest time: sha256 <hex> <!-- orianna: ok -->
- Entries processed: (list of 12 filenames)
```

**Graduation path:** entries marked `graduate` produce a pre-planner stub inside the digest. Evelynn (or Duong directly) reviews the stub, and if approved, the stub is promoted to a `plans/proposed/personal/YYYY-MM-DD-<slug>.md` scaffold by Karma in a follow-up session. The feedback entry's frontmatter is updated `state: graduated` and the filename of the resulting proposed plan is added to frontmatter as `graduated_to: plans/proposed/...`. <!-- orianna: ok -->

**Stale detection:** Lux marks an entry `stale` if any of:

- The feedback references a plan/script/path that no longer exists and the friction it described would not recur against current state.
- A newer feedback entry (lower date) supersedes it explicitly via the `related_feedback:` frontmatter field.
- An implemented plan resolved the underlying issue (checked via `grep feedback-filename plans/implemented/**.md`).

Stale entries are moved to `feedback/archived/` as a subfolder preserved in git history. The INDEX drops them; the digest logs them; they are queryable via Skarner for "have we seen this friction before?" but do not count against the open cap. <!-- orianna: ok -->

**Duplicate detection:** Lux dedupes by category-shared-tokens similarity (same heuristic as `plans/proposed/personal/2026-04-21-daily-agent-repo-audit-routine.md` §D7 — ≥3 shared non-stopword tokens, ≥0.4 Jaccard). Duplicates are clustered under one `graduate`-marked head entry; satellite entries point to the head via `related_feedback:`. <!-- orianna: ok -->

### D6. Pre-commit index regeneration hook

A new hook `scripts/hooks/pre-commit-feedback-index.sh` runs on every commit that touches `feedback/**.md`: <!-- orianna: ok -->

1. Detect if any staged diff file matches `^feedback/[^/]+\.md$` (or deletion of same). <!-- orianna: ok -->
2. If yes, invoke `scripts/feedback-index.sh` (re-generate `feedback/INDEX.md` from frontmatter of all `feedback/*.md` files with `state: open`). <!-- orianna: ok -->
3. Stage `feedback/INDEX.md` as part of the same commit. <!-- orianna: ok -->
4. Verify the regenerated index matches the staged one (guard against manual INDEX edits).

The hook is installed via the existing `scripts/install-hooks.sh`, added to the list alongside the commit-prefix and secret-scan hooks. No `--no-verify` bypass per CLAUDE.md rule 14. Schema violations (missing required frontmatter) fail the hook with a clear message pointing at §D1.

The index-regeneration script `scripts/feedback-index.sh` itself is POSIX-portable bash (per CLAUDE.md rule 10) using a small Node shim for YAML parsing (frontmatter parsing with shell alone is too fragile for a user-edited schema). The Node shim reuses the same pattern as the existing `scripts/_lib_plan_structure.sh` family. <!-- orianna: ok -->

### D7. Integration with the daily agent-repo audit routine

**Pick: feedback consolidation is a Sunday-only sibling dimension of the daily audit routine, piggybacked on the same Claude Code Routine infrastructure.**

Evaluated against three candidates:

| Option | Pro | Con | Verdict |
|---|---|---|---|
| (A) 6th daily audit dimension | One Routine; daily cadence | Feedback volume doesn't warrant daily — produces empty digests 5/7 days | Rejected. |
| (B) Separate Routine on Sunday only | Clean separation of concern | Two `/schedule` entries; duplicate cost accounting | Rejected. |
| (C) Piggyback: the Sunday run of the daily audit routine dispatches the feedback consolidation pair in addition to its five audit dimensions | One Routine; daily cadence for drift + weekly cadence for feedback; shared commit | Slightly more complex parent prompt logic (conditional dispatch on day-of-week) | **Chosen.** |

**Implementation in the audit routine's parent prompt (§D10 of the audit ADR):**

```
If today is Sunday (day-of-week == 0):
  Dispatch additionally:
    - Lux for feedback-categorize (over feedback/*.md with state:open).
    - Karma for feedback-triage (consumes Lux's output).
  Consolidate output into assessments/feedback-digests/$DATE.md.
  Mutate feedback/*.md frontmatter (state: graduated / stale per Lux's verdict).
  Include digest summary in the commit message and in the Evelynn inbox message.
```

**Token budget impact:** Lux + Karma dispatch adds ~50k in / ~12k out to the Sunday run. Against the audit routine's ~255k in / ~55k out daily baseline (§D2 of that ADR), Sunday is ~20% heavier. Still well within the Pro tier's 5-routine/day cap.

**Rollback independence:** if the feedback system is disabled, the audit routine's parent prompt skips the Sunday block gracefully (checks for `feedback/` directory + non-zero open-entry count before dispatching). The audit routine itself is unaffected. <!-- orianna: ok -->

### D8. Shared-schema commitments with sibling plans

The retrospection dashboard (`plans/proposed/personal/2026-04-21-retrospection-dashboard.md` §D8-equivalent) promises a system-health tile. This ADR commits: <!-- orianna: ok -->

- `feedback/INDEX.md` is the retro dashboard's sole read surface for feedback counts. Schema: the table columns in §D3 are stable; breaking changes require a schema-version bump in a sibling ADR. <!-- orianna: ok -->
- The retro dashboard's "System" health panel surfaces: `count_open_high`, `count_open_medium`, `count_graduated_last_7d`, `oldest_open_entry_days`. All four are derivable from `feedback/INDEX.md` plus `ls feedback/` mtimes. <!-- orianna: ok -->
- Cross-linking: each feedback entry is URL-referenceable from the retro dashboard via `/feedback/<filename-without-ext>`. The dashboard does not mutate feedback files.

**Not shared:**

- The daily audit routine's `audits/findings-tracker.json` and this ADR's `feedback/INDEX.md` are intentionally separate. Audit findings are mechanical drift (dead refs); feedback entries are human-agent-felt friction. They cluster differently, graduate differently, and prune differently. One shared tracker would smear both signals. <!-- orianna: ok -->
- The coordinator-decision-feedback plan shares no state with this ADR. Agent friction is not a decision.

### D9. Failure modes and resilience

**Failure cases:**

1. **Agent writes feedback with malformed frontmatter.** Pre-commit hook fails with a clear message pointing at §D1 schema. Agent fixes and retries. No silent drop.
2. **Two agents write the same filename in the same minute.** Filename collision. The second commit's hook detects the name collision and suffixes `-2` automatically.
3. **`feedback/INDEX.md` regeneration fails.** Hook fails; commit blocked. Agent inspects the regen script output, fixes the offending feedback file, retries. The blocking behavior is acceptable here because a broken INDEX would silently lose signal. <!-- orianna: ok -->
4. **Lux/Karma fail during Sunday consolidation.** Audit routine's `dimensions_errored` mechanism (§D9 of the audit ADR) extends to the feedback dispatch pair. Digest is skipped for that week, feedback entries stay `open`, next Sunday picks them up. No catastrophic state loss.
5. **Feedback volume explodes (>30 open entries).** Symptom of either a structural problem (many agents hitting similar friction) or an over-sensitive trigger. Lux's Sunday digest includes a "volume alarm" section at >30 open entries; at >50 the Monday morning inbox gets a `high`-severity meta-entry. Trigger calibration happens via the shared-rules file edit.
6. **Graduated entries accumulate as zombies.** An entry marked `graduated` whose linked proposed plan never advances past `proposed/` is surfaced by the digest's "graduation follow-up" section at 14 days post-graduation. <!-- orianna: ok -->

### D10. Disable and rollback

**Disable:**

- Remove `<!-- include: _shared/feedback-trigger.md -->` from each `_shared/<role>.md` file and re-run `scripts/sync-shared-rules.sh`. Agents stop being prompted to write. <!-- orianna: ok -->
- Comment out the Sunday conditional in the audit routine's parent prompt. Digests stop being generated.
- Existing `feedback/*.md` entries remain as a historical archive; nothing is deleted. <!-- orianna: ok -->

**Full rollback:**

- Delete `scripts/hooks/pre-commit-feedback-index.sh`, `scripts/feedback-index.sh`. <!-- orianna: ok -->
- Delete `.claude/agents/_shared/feedback-trigger.md`. <!-- orianna: ok -->
- Revert the `_shared/*.md` edits that added the include marker. <!-- orianna: ok -->
- Revert `scripts/sync-shared-rules.sh` to depth-1 resolution.
- Delete `feedback/INDEX.md` generation logic in the audit routine's Sunday block. <!-- orianna: ok -->
- `feedback/` directory + `assessments/feedback-digests/` remain as historical record; safe to delete if desired. <!-- orianna: ok -->

**Partial rollback (disable encouragement only, keep write-schema):**

- Only remove the shared-rules include. Agents can still write feedback voluntarily (the two existing entries were written that way), but the trigger prompt no longer fires automatically. Consolidation still runs on whatever volume arrives.

## 4. Non-goals

- **Not a bug tracker.** GitHub Issues / PRs remain for product bugs. Feedback is about the agent system's own friction, not application bugs.
- **Not a journal.** Agent journals (`agents/<name>/journal/**`) capture per-session narrative; feedback captures specific friction events worth systemic attention. <!-- orianna: ok -->
- **Not a learning.** Agent learnings (`agents/<name>/learnings/**`) capture reusable patterns the agent itself discovered; feedback captures problems *with the system* that the agent couldn't unilaterally solve. <!-- orianna: ok -->
- **Not a memory.** Agent memory (`agents/<name>/memory/<name>.md`) is per-agent persistent context; feedback is cross-agent, cross-session system signal. <!-- orianna: ok -->
- **Not a retro tool for Duong.** The retrospection dashboard owns that lane. This ADR's consumer is the agent system itself; Duong gets a summary via inbox, not a drilling view.
- **Not a replacement for Skarner's retrieval role.** Skarner queries feedback on demand; it does not own feedback lifecycle.

## 5. Risks & mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| Agents treat the trigger heuristic as aspirational and write nothing | high | Prescriptive list of 7 concrete triggers in `_shared/feedback-trigger.md` rather than a "when appropriate" phrasing. The existing two entries were written without any trigger prompt, so the base rate is already non-zero. If 7-day window post-launch shows <3 new entries, Lux is notified to sharpen triggers. | <!-- orianna: ok -->
| Agents write feedback for every minor hiccup (spam) | medium | Explicit "Do NOT write for" list in the trigger stanza; the `friction_cost_minutes: >5` qualifier; the `>3 per session → notify Lux` safety net. |
| Nested-include resolution in `sync-shared-rules.sh` introduces bugs | medium | Phase 1 tasks (§6 T3) include a depth-2 idempotency test and an xfail test before impl. The existing sync script is well-tested; depth-2 is additive, not invasive. | <!-- orianna: ok -->
| `feedback/INDEX.md` regeneration hook blocks legitimate commits | medium | Hook fails loud with clear error messages pointing at schema §D1. Pre-commit hooks already exist in the repo (CLAUDE.md rule 14), so agents are already accustomed to hook-driven feedback. | <!-- orianna: ok -->
| Consolidation dispatch on Sunday conflicts with a Sunday audit-routine failure | low | Piggyback integration (§D7) means Sunday failure degrades feedback digest gracefully — entries stay `open`, next Sunday picks up. |
| Feedback duplicates ADRs in `plans/proposed/` (same problem surfaced twice) | low-medium | `related_plan:` frontmatter field makes the link explicit; Lux's consolidation checks the `plans/proposed/` and `plans/approved/` indexes for matches and flags duplicates. | <!-- orianna: ok -->
| Schema drift over time as new categories emerge | low | `category: other` exists as a catch-all. Consolidation surfaces `other`-category clusters in the digest; ADR edit to formalize new categories is a deliberate act. |
| Feedback exposes confidential project details that shouldn't be in git | low | `concern:` field signals origin; `secrets/` rule (CLAUDE.md rule 2) still applies. The existing two entries contain no secrets — file paths and commit SHAs are public-by-git-nature. | <!-- orianna: ok -->
| Agents write conflicting feedback (one says X is bad, another says X is fine) | low | This is signal, not noise. Lux's consolidation clusters conflicting feedback under one cluster head and flags "divergent" in the digest — the pair may reveal that context matters (e.g. X is bad in concern A but fine in concern B). |
| The trigger for "coordinator-discipline slip" relies on coordinator self-honesty | medium | The existing `feedback/2026-04-21-phase-discipline-approved-vs-in-progress.md` entry is exactly this shape, written by Sona unprompted. Base rate is positive. If coordinator self-reporting decays, adding a hook-side detector for known discipline slips (e.g. impl commit against `plans/approved/**` without a matching `plans/in-progress/**` promotion in the same branch) graduates to a follow-up ADR. | <!-- orianna: ok -->
| Weekly cadence is too slow for urgent feedback | low | `severity: high` entries trigger real-time inbox surfacing via the shared `agents/evelynn/inbox/` channel at write time (the hook writes a companion inbox shard for `high`-severity entries). Weekly rollup handles non-urgent consolidation; urgent signal flows immediately. | <!-- orianna: ok -->

## 6. Tasks

## Task breakdown

**Phase 1 — Write-path + broadcast.** Estimate: 4 tasks, 155 minutes.

- [ ] **T1** — Migrate the two existing ad-hoc entries to the §D1 schema. Add frontmatter to `feedback/2026-04-21-orianna-signing-latency.md` and `feedback/2026-04-21-phase-discipline-approved-vs-in-progress.md`; adjust body sections to match the `## What went wrong / ## Suggestion / ## Why I'm writing this now` structure where needed. No content changes. kind: chore. estimate_minutes: 20. Files: `feedback/2026-04-21-orianna-signing-latency.md`, `feedback/2026-04-21-phase-discipline-approved-vs-in-progress.md`. DoD: both files pass §D1 frontmatter validation (`scripts/feedback-index.sh --check` — part of T2). <!-- orianna: ok -->

- [ ] **T2** — Implement `scripts/feedback-index.sh` — POSIX-portable bash with a Node shim for YAML parsing. Reads `feedback/*.md` (not `feedback/archived/`), extracts frontmatter, writes `feedback/INDEX.md` per the §D3 template. Also supports `--check` mode that validates schema without writing. kind: impl. estimate_minutes: 55. Files: `scripts/feedback-index.sh` (new), `scripts/_lib_feedback_parse.mjs` (new — Node YAML parser shim). <!-- orianna: ok --> DoD: script renders a valid INDEX from the two migrated entries; `--check` passes on both files; `--check` fails on a deliberately-malformed fixture. <!-- orianna: ok -->

- [ ] **T3** — Install the pre-commit hook `scripts/hooks/pre-commit-feedback-index.sh` that detects `feedback/*.md` diffs and regenerates INDEX. Wire into `scripts/install-hooks.sh` alongside existing hooks. kind: impl. estimate_minutes: 40. Files: `scripts/hooks/pre-commit-feedback-index.sh` (new), `scripts/install-hooks.sh` (edit). <!-- orianna: ok --> DoD: hook runs on a test commit that edits a feedback file; INDEX is regenerated and staged; hook fails on a commit with malformed frontmatter.

- [ ] **T4** — Add boot-chain read in Evelynn + Sona `CLAUDE.md` startup sections. One line each pointing at `feedback/INDEX.md`. kind: docs. estimate_minutes: 40. Files: `agents/evelynn/CLAUDE.md` (edit), `agents/sona/CLAUDE.md` (edit). <!-- orianna: ok --> DoD: fresh coordinator session reads the index as part of startup; high-severity count surfaces in the first user turn when >0.

**Phase 2 — Encouragement (shared-rules inline).** Estimate: 3 tasks, 120 minutes.

- [ ] **T5** — Author `.claude/agents/_shared/feedback-trigger.md` with the §D4 content. kind: docs. estimate_minutes: 35. Files: `.claude/agents/_shared/feedback-trigger.md` (new). <!-- orianna: ok --> DoD: file exists, ~35 lines, contains the 7 triggers + the 4-step write ceremony + the "do NOT write for" list.

- [ ] **T6** — Extend `scripts/sync-shared-rules.sh` to resolve includes at depth 2 (per §D4.1). Add xfail test first (§6 T6a) then impl (T6b). kind: impl. estimate_minutes: 55. Files: `scripts/sync-shared-rules.sh` (edit), `scripts/__tests__/sync-shared-rules.xfail.bats` (edit). <!-- orianna: ok --> DoD: running sync twice produces identical output; a paired agent def ends up with both the role shared content AND the feedback-trigger stanza inlined below it.

- [ ] **T7** — Add `<!-- include: _shared/feedback-trigger.md -->` marker to the bottom of each of the 10 existing `_shared/*.md` files; re-run sync; verify all paired agent defs now carry the stanza. kind: docs. estimate_minutes: 30. Files: all 10 files under `.claude/agents/_shared/` (edit), plus the resulting diff on every paired `.claude/agents/*.md` produced by `scripts/sync-shared-rules.sh`. <!-- orianna: ok --> DoD: `scripts/lint-subagent-rules.sh` passes; spot-check of three random agent defs (e.g. `.claude/agents/jayce.md`, `.claude/agents/vi.md`, `.claude/agents/karma.md`) confirms the stanza is present.

**Phase 3 — Ritual integration (skill + session-close hooks).** Estimate: 5 tasks, 230 minutes.

- [ ] **T8** — Author `.claude/skills/agent-feedback/SKILL.md` — the atomic write primitive per §D4A.1. Supports both coordinator-mode (immediate commit) and subagent-mode (leave uncommitted for sweep). Includes the four-field prompt, filename derivation, frontmatter synthesis, §D1 body structure, caller-type detection, and the conditional commit branch. kind: docs. estimate_minutes: 60. Files: `.claude/skills/agent-feedback/SKILL.md` (new). <!-- orianna: ok --> DoD: skill file exists; dry-run against a mocked trigger produces a valid §D1 file; mode-A test path commits, mode-B test path leaves uncommitted.

- [ ] **T9** — Edit `.claude/skills/end-session/SKILL.md` to insert the §D4A.2 reflection step before the final commit and the §D4A.5 sweep step at the very end. kind: docs. estimate_minutes: 40. Files: `.claude/skills/end-session/SKILL.md` (edit). <!-- orianna: ok --> DoD: the seven-trigger reflection step is present; the sweep step picks up uncommitted `feedback/*.md` and commits them with `chore: feedback sweep —` prefix.

- [ ] **T10** — Edit `.claude/skills/pre-compact-save/SKILL.md` and cross-reference in `.claude/agents/lissandra.md` to insert the §D4A.3 reflection step. Voice invariant: the feedback's `author:` is the coordinator Lissandra is impersonating, not Lissandra herself. kind: docs. estimate_minutes: 40. Files: `.claude/skills/pre-compact-save/SKILL.md` (edit), `.claude/agents/lissandra.md` (edit). <!-- orianna: ok --> DoD: reflection step is present in both files; voice invariant is documented; example dry-run emits feedback with coordinator `author:`.

- [ ] **T11** — Edit `.claude/skills/end-subagent-session/SKILL.md` to add the §D4A.5 subagent sweep step. Picks up any `feedback/*.md` files a subagent wrote mid-task via mode-B `/agent-feedback` and commits them in a single `chore: feedback sweep — <agent> — <date>` commit at session close. kind: docs. estimate_minutes: 40. Files: `.claude/skills/end-subagent-session/SKILL.md` (edit). <!-- orianna: ok --> DoD: sweep step is present; idempotent against zero uncommitted feedback files; fallback documentation points at coordinator `/end-session` sweep.

- [ ] **T12** — Edit the audit routine's parent prompt (§D10 of that ADR) to add the Sunday conditional block per §D7. Also author `.claude/skills/feedback-consolidate/SKILL.md` — the Sunday skill that Lux + Karma execute (renamed from the earlier `.claude/skills/feedback/` draft to avoid the naming collision with `/feedback` and with the Mode-A/B skill at `.claude/skills/agent-feedback/`). kind: docs. estimate_minutes: 50. Files: `plans/proposed/personal/2026-04-21-daily-agent-repo-audit-routine.md` §D10 (edit to reference this ADR's feedback dispatch), `architecture/audit-routine.md` (to-be-created by that ADR's T4 — edit to include the feedback integration), `.claude/skills/feedback-consolidate/SKILL.md` (new). <!-- orianna: ok --> DoD: audit-routine ADR's §D10 cross-references this ADR's feedback dispatch; consolidate skill includes Lux-categorize + Karma-triage dispatch templates and the §D5 digest schema.

**Phase 4 — First live digest.** Estimate: 1 task, 35 minutes.

- [ ] **T13** — First live digest dry-run: against the 2 migrated entries + any net-new entries from the week, Lux + Karma produce the first `assessments/feedback-digests/2026-04-27.md` (or next Sunday after launch). Human (Evelynn + Duong) reviews; pattern locks in. kind: meta. estimate_minutes: 35. Files: `assessments/feedback-digests/<next-sunday>.md` (new). <!-- orianna: ok --> DoD: digest exists, follows §D5 schema, identifies the Orianna-signing cluster as `graduate` with a named candidate ADR stub.

## Test plan

`tests_required: false` because this ADR is documentation + configuration + shell scripts. Rationale: no `apps/**` code lands; the Node shim in T2 is a thin YAML parser with no business logic; the hook logic is a bash if-then-regenerate pattern that's straightforward. Per `architecture/plan-frontmatter.md` Quick reference, opting out requires a justification in the plan body — this paragraph is that justification. <!-- orianna: ok -->

That said, three lightweight invariant checks run as part of the task DoDs and will be captured as bats tests alongside the existing `scripts/__tests__/` suite: <!-- orianna: ok -->

1. **Schema validator (T2 DoD).** `scripts/feedback-index.sh --check` against:
   - Two valid fixtures (the migrated entries) → exit 0.
   - Three malformed fixtures (missing `severity`, invalid `category` enum, missing `## What went wrong` section) → exit non-zero with the faulty field named in stderr.
2. **Hook blocking (T3 DoD).** A synthetic commit that edits a feedback file with malformed frontmatter → hook fails loud, commit rejected. A valid edit → INDEX is regenerated, staged, commit succeeds.
3. **Sync depth-2 idempotency (T6 DoD).** Running `scripts/sync-shared-rules.sh` twice on a clean tree produces zero diff. Running once on a tree where `_shared/feedback-trigger.md` has changed by one line produces the expected one-line change in each of the 10 `_shared/*.md` files AND in each paired agent def. <!-- orianna: ok -->

Test files:

- `scripts/__tests__/feedback-index.xfail.bats` (new) — covers invariants 1 above. <!-- orianna: ok -->
- `scripts/__tests__/pre-commit-feedback-index.xfail.bats` (new) — covers invariant 2. <!-- orianna: ok -->
- `scripts/__tests__/sync-shared-rules.xfail.bats` (edit existing) — covers invariant 3.

These tests are xfail-first per CLAUDE.md rule 12 even though `tests_required: false`, because the repo's invariant-check pattern keeps them cheap and durable.

## 7. Open questions

- **OQ1 — Timezone confirmation.** All timestamps assumed Asia/Bangkok (UTC+7). Confirm against `architecture/plan-lifecycle.md` or Duong directly before T2 lands the filename convention in the `feedback-index.sh` regex. <!-- orianna: ok -->
- **OQ2 — Nested include depth.** Depth-2 resolves the current need. If a future ADR wants a third-level nested include, do we go recursive or do we keep enumerating passes? Deferred to when that need is concrete.
- **OQ3 — Per-concern feedback folders.** This ADR mandates one global `feedback/` folder. If work-concern feedback grows to dominate and mixes poorly with personal-concern feedback in the INDEX, split to `feedback/work/` + `feedback/personal/`. Deferred; `concern:` frontmatter already enables the split cheaply later. <!-- orianna: ok -->
- **OQ4 — High-severity real-time companion inbox shard.** §5 mitigation claims `severity: high` entries also write an inbox shard immediately. Should this be part of `scripts/hooks/pre-commit-feedback-index.sh` (same hook) or a separate `scripts/hooks/pre-commit-feedback-high-sev.sh`? Unify into one hook for simplicity unless a lint reason emerges. <!-- orianna: ok -->
- **OQ5 — Skarner's `feedback-search` route.** This ADR names Skarner as the on-demand query agent but does not specify the exact query grammar beyond `feedback-search <keyword>`. A follow-up edit to `.claude/agents/skarner.md` formalizes it; not a blocker for Phase 1.
- **OQ6 — Does Sona read this same `feedback/INDEX.md`?** Yes, per §D3 T4. But Sona's startup chain is in `agents/sona/CLAUDE.md` (work-concern specific); confirm the boot-chain edit happens in both files, not just Evelynn's. <!-- orianna: ok -->
- **OQ7 — Subagent `/end-subagent-session` reflection step.** Currently §D4A.2 binds reflection to coordinator `/end-session` only. Subagents get the on-demand path (mode B) + the sweep at close. Does subagent `/end-subagent-session` also deserve a reflection step that invokes `/agent-feedback` if any trigger fired? Argument for: subagents are the origin of most hands-on friction. Argument against: subagent sessions are short and narrow, and mode-B on-demand already covers the live trigger path. Deferred until 7-day volume data lands — if subagent friction is consistently underreported relative to coordinator friction, add the reflection step to `/end-subagent-session` in a follow-up.

## Architecture impact

None in v1. The system is additive:

- A new directory (`feedback/` — already exists). <!-- orianna: ok -->
- A new shared-rules file (`.claude/agents/_shared/feedback-trigger.md`). <!-- orianna: ok -->
- Two new skills (`.claude/skills/agent-feedback/SKILL.md`, `.claude/skills/feedback-consolidate/SKILL.md`). <!-- orianna: ok -->
- A new script and hook (`scripts/feedback-index.sh`, `scripts/hooks/pre-commit-feedback-index.sh`). <!-- orianna: ok -->
- Edits to three existing skills (`.claude/skills/end-session/SKILL.md`, `.claude/skills/pre-compact-save/SKILL.md`, `.claude/skills/end-subagent-session/SKILL.md`) adding reflection + sweep steps. <!-- orianna: ok -->
- An edit to one existing script (`scripts/sync-shared-rules.sh` — depth-2 resolution).
- An edit to one existing agent definition (`.claude/agents/lissandra.md`) cross-referencing the pre-compact reflection.
- A documentation integration with a sibling plan's Routine.

No architectural component or interface changes. No new universal invariant added to CLAUDE.md (the trigger stanza rides via shared-rules include, not via a rule-number entry). No existing rule modified.

If the feedback system becomes a first-class named component in the agent-system story, a follow-up ADR adds it to `architecture/agent-system.md` and creates `architecture/feedback-system.md`. Deferred until volume justifies. <!-- orianna: ok -->
