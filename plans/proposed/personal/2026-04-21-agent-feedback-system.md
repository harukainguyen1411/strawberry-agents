---
status: proposed
concern: personal
owner: lux
created: 2026-04-21
tests_required: false
complexity: complex
tags: [feedback, meta-tooling, agent-system, continuous-improvement, shared-rules]
related:
  - plans/proposed/personal/2026-04-21-daily-agent-repo-audit-routine.md
  - plans/proposed/personal/2026-04-21-retrospection-dashboard.md
  - plans/proposed/personal/2026-04-21-coordinator-decision-feedback.md
  - plans/approved/2026-04-20-strawberry-inbox-channel.md
  - feedback/2026-04-21-orianna-signing-latency.md
  - feedback/2026-04-21-orianna-signing-followups.md
  - feedback/2026-04-21-phase-discipline-approved-vs-in-progress.md
  - feedback/2026-04-21-viktor-context-ceiling-batched-impl.md
  - feedback/2026-04-22-coordinator-verify-qa-claims.md
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
- **No retroactive backfill.** The five existing ad-hoc entries (`feedback/2026-04-21-orianna-signing-latency.md`, `feedback/2026-04-21-orianna-signing-followups.md`, `feedback/2026-04-21-phase-discipline-approved-vs-in-progress.md`, `feedback/2026-04-21-viktor-context-ceiling-batched-impl.md`, `feedback/2026-04-22-coordinator-verify-qa-claims.md`) are migrated to the new schema as part of G1 T1 (§6); no historical journal-mining beyond those.

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

The five existing entries already fit this body structure largely; the migration (§6 G1 T1) adds frontmatter and normalizes section headings where needed.

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

Alternatively, `sync-shared-rules.sh` could resolve includes recursively to arbitrary depth. Depth-2 is sufficient for this ADR; depth-N is deferred to a follow-up if/when a second nested include is needed. §6 G3 T7 implements depth-2; §OQ2 gates the question of depth-N. <!-- orianna: ok -->

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

### D11. Sync-shared-rules boundary — feedback flow does not amend shared rules

A feedback entry is **signal**, not a rule change. The pipeline that converts signal to rule change is explicitly two-step and human-gated:

1. Feedback entry written → consolidation digest clusters it → digest marks cluster `graduate` → candidate ADR stub is drafted → Evelynn/Duong approve → Karma scaffolds a `plans/proposed/...` plan → plan moves through the normal Orianna-gated lifecycle to `plans/implemented/`. <!-- orianna: ok -->
2. **Only if** the implemented plan's §Architecture-impact explicitly edits a `_shared/*.md` file does `scripts/sync-shared-rules.sh` carry that edit to the paired agent defs on the next sync run. <!-- orianna: ok -->

What this ADR is **not** doing:

- Writing feedback does not directly mutate any `_shared/*.md` file. <!-- orianna: ok -->
- The consolidation digest does not mutate any `_shared/*.md` file — it may *recommend* such a mutation as part of a graduated stub, but the mutation itself happens in the downstream plan's implementation commits. <!-- orianna: ok -->
- A `high`-severity entry's inbox shard (§D9 item 5) does not escalate to an automatic shared-rule edit. Escalation cadence is weekly-digest-minimum, ADR-gated.

What this ADR **is** doing to the sync mechanism:

- One additive change: nested-include depth-2 resolution (§D4.1), implemented in `scripts/sync-shared-rules.sh` in G3 T7.
- Ten additive edits: one `<!-- include: _shared/feedback-trigger.md -->` marker per `_shared/<role>.md` file (G3 T8). <!-- orianna: ok -->
- No edit ever re-phrases or removes existing shared-rule content in this ADR's scope.

**Scoping rule for future shared-rule amendments emerging from feedback:** an amendment that applies to all roles goes into a new standalone `_shared/<topic>.md` (never overloads an existing role file). An amendment that applies to one role (e.g. only architects) edits that one `_shared/<role>.md` directly. This rule is codified here rather than in `architecture/` so the feedback-to-rule pipeline has an explicit convention without needing a separate architectural doc. <!-- orianna: ok -->

## Invariants

Properties the system must preserve at all times (checked by tests in §Test plan and by hook logic in §D6):

1. **One file-writing path.** Every feedback entry is written by `/agent-feedback`. No other mechanism (no raw Write, no hook-synthesized entries, no consolidation-authored primary entries) produces a `feedback/YYYY-MM-DD-HHMM-<author>-<slug>.md` file. Violation detectable by: any `feedback/*.md` whose git-introducing commit is not prefixed `chore: feedback` or `chore: feedback sweep`. <!-- orianna: ok -->
2. **Author-fidelity.** A feedback entry's `author:` frontmatter names the agent that lived the friction, never a proxy. Lissandra writing on behalf of a coordinator uses the coordinator's name; coordinators never use subagent names. Violation detectable by: `author:` value mismatch against the invoking agent's canonical name in the commit or sweep.
3. **No blocking behavior.** Writing feedback never blocks the original task. The `/agent-feedback` skill returns within ~60 seconds and the caller resumes. The pre-commit hook blocks only on malformed frontmatter, never on "you should have written more feedback."
4. **Idempotent index.** Running `scripts/feedback-index.sh` twice on an unchanged `feedback/**` tree produces zero diff on `feedback/INDEX.md`. The hook must not stage unnecessary INDEX mutations. <!-- orianna: ok -->
5. **Idempotent sync.** Running `scripts/sync-shared-rules.sh` twice on a clean tree produces zero diff. Depth-2 nested include resolution does not re-order content.
6. **State machine is monotone.** An entry's `state:` moves only through `open → acknowledged → graduated` or `open → stale`. No demotion (`graduated → open`, `stale → open`). Re-opening requires a new entry that supersedes via `related_feedback:`.
7. **Scope separation preserved.** No feedback entry mutates a file outside `feedback/**`. The consolidation digest writes only into `assessments/feedback-digests/**`. ADR graduation writes only into `plans/proposed/**`. <!-- orianna: ok -->
8. **Secret-free.** No feedback entry contains a plaintext secret. Existing CLAUDE.md rule 2 applies; the pre-commit secret-scan hook already protects `feedback/**`. <!-- orianna: ok -->
9. **Concern-tagged but concern-shared.** Every entry carries `concern: work | personal` frontmatter, but all entries live in the single `feedback/` folder and appear in the single `feedback/INDEX.md`. Splitting by concern is a deferred decision (§OQ3), never done silently. <!-- orianna: ok -->
10. **Feedback is not a plan.** No `feedback/*.md` file is ever moved into `plans/**`. Graduation produces a *new* plan file; the feedback entry stays in `feedback/**` with `state: graduated` and a `graduated_to:` frontmatter pointer. <!-- orianna: ok -->

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
| Nested-include resolution in `sync-shared-rules.sh` introduces bugs | medium | G3 T7 includes a depth-2 idempotency test and an xfail test before impl. The existing sync script is well-tested; depth-2 is additive, not invasive. | <!-- orianna: ok -->
| `feedback/INDEX.md` regeneration hook blocks legitimate commits | medium | Hook fails loud with clear error messages pointing at schema §D1. Pre-commit hooks already exist in the repo (CLAUDE.md rule 14), so agents are already accustomed to hook-driven feedback. | <!-- orianna: ok -->
| Consolidation dispatch on Sunday conflicts with a Sunday audit-routine failure | low | Piggyback integration (§D7) means Sunday failure degrades feedback digest gracefully — entries stay `open`, next Sunday picks up. |
| Feedback duplicates ADRs in `plans/proposed/` (same problem surfaced twice) | low-medium | `related_plan:` frontmatter field makes the link explicit; Lux's consolidation checks the `plans/proposed/` and `plans/approved/` indexes for matches and flags duplicates. | <!-- orianna: ok -->
| Schema drift over time as new categories emerge | low | `category: other` exists as a catch-all. Consolidation surfaces `other`-category clusters in the digest; ADR edit to formalize new categories is a deliberate act. |
| Feedback exposes confidential project details that shouldn't be in git | low | `concern:` field signals origin; `secrets/` rule (CLAUDE.md rule 2) still applies. The existing two entries contain no secrets — file paths and commit SHAs are public-by-git-nature. | <!-- orianna: ok -->
| Agents write conflicting feedback (one says X is bad, another says X is fine) | low | This is signal, not noise. Lux's consolidation clusters conflicting feedback under one cluster head and flags "divergent" in the digest — the pair may reveal that context matters (e.g. X is bad in concern A but fine in concern B). |
| The trigger for "coordinator-discipline slip" relies on coordinator self-honesty | medium | The existing `feedback/2026-04-21-phase-discipline-approved-vs-in-progress.md` entry is exactly this shape, written by Sona unprompted. Base rate is positive. If coordinator self-reporting decays, adding a hook-side detector for known discipline slips (e.g. impl commit against `plans/approved/**` without a matching `plans/in-progress/**` promotion in the same branch) graduates to a follow-up ADR. | <!-- orianna: ok -->
| Weekly cadence is too slow for urgent feedback | low | `severity: high` entries trigger real-time inbox surfacing via the shared `agents/evelynn/inbox/` channel at write time (the hook writes a companion inbox shard for `high`-severity entries). Weekly rollup handles non-urgent consolidation; urgent signal flows immediately. | <!-- orianna: ok -->

## 6. Tasks

Task groups map 1:1 to the five decision layers in §2. Each group may be scheduled independently; inter-group dependencies are stated per task. Total: 13 tasks, ~540 minutes.

**Group 1 — WRITE layer (data model + schema validator).** 3 tasks, 115 minutes. Depends on: nothing. Unlocks: G2, G3.

- [ ] **T1** — Migrate the five existing ad-hoc entries to the §D1 schema. Add frontmatter and normalize body sections to `## What went wrong / ## Suggestion / ## Why I'm writing this now` where needed. No content rewriting. kind: chore. estimate_minutes: 30. Files: `feedback/2026-04-21-orianna-signing-latency.md`, `feedback/2026-04-21-orianna-signing-followups.md`, `feedback/2026-04-21-phase-discipline-approved-vs-in-progress.md`, `feedback/2026-04-21-viktor-context-ceiling-batched-impl.md`, `feedback/2026-04-22-coordinator-verify-qa-claims.md`. DoD: all five files pass `scripts/feedback-index.sh --check` (delivered in T2); existing `related_feedback:` link established between `orianna-signing-latency` and `orianna-signing-followups`. <!-- orianna: ok -->

- [ ] **T2** — Implement `scripts/feedback-index.sh` — POSIX-portable bash with a Node shim for YAML parsing. Reads `feedback/*.md` (not `feedback/archived/`), extracts §D1 frontmatter, writes `feedback/INDEX.md` per the §D3 template. Supports `--check` mode that validates schema without writing. kind: impl. estimate_minutes: 55. Files: `scripts/feedback-index.sh` (new), `scripts/_lib_feedback_parse.mjs` (new — Node YAML parser shim modeled on `scripts/_lib_plan_structure.sh`). DoD: script renders a valid INDEX from the five migrated entries; `--check` passes on all five; `--check` fails on deliberately-malformed fixtures (missing `severity`, invalid `category`, missing `## What went wrong` section) with the faulty field named in stderr; running twice produces zero diff (Invariant 4). <!-- orianna: ok -->

- [ ] **T3** — Install pre-commit hook `scripts/hooks/pre-commit-feedback-index.sh` that detects `feedback/*.md` diffs and regenerates INDEX. Wire into `scripts/install-hooks.sh` alongside existing hooks. kind: impl. estimate_minutes: 30. Files: `scripts/hooks/pre-commit-feedback-index.sh` (new), `scripts/install-hooks.sh` (edit). Depends on: T2. DoD: hook runs on a test commit that edits a feedback file — INDEX is regenerated and staged in the same commit; hook fails loud on a commit with malformed frontmatter pointing at §D1; `--no-verify` is NOT used anywhere in the hook (CLAUDE.md rule 14). <!-- orianna: ok -->

**Group 2 — BROADCAST layer (index surface + coordinator boot + subagent query).** 2 tasks, 75 minutes. Depends on: G1 T2 (INDEX must exist). Unlocks: live broadcast to coordinators.

- [ ] **T4** — Add boot-chain read in Evelynn + Sona `CLAUDE.md` startup sections per §D3. One line each: "Read `feedback/INDEX.md` — first 20 lines. If `count_open_high > 0`, surface top-3 high entries to Duong at first opportunity." kind: docs. estimate_minutes: 35. Files: `agents/evelynn/CLAUDE.md` (edit), `agents/sona/CLAUDE.md` (edit). DoD: fresh coordinator session (both Evelynn and Sona spawn paths) reads INDEX as part of startup; high-severity count is surfaced in the first user turn when >0; when =0 a one-line acknowledgement appears in the startup recap rather than silence. <!-- orianna: ok -->

- [ ] **T5** — Extend `.claude/agents/skarner.md` with the `feedback-search` query kind per §D3 on-demand route. Grammar: `feedback-search <category|severity|author|keyword>`. Search targets: `feedback/INDEX.md` first as the fast path, then `feedback/*.md` frontmatter+body for keyword matches, then `feedback/archived/*.md` as a last resort when the caller supplies `--include-archived`. kind: docs. estimate_minutes: 40. Files: `.claude/agents/skarner.md` (edit). DoD: Skarner's agent def lists `feedback-search` in its query-kind table with example dispatches; a dry-run query for `feedback-search review-loop` returns the orianna-signing cluster. Resolves §OQ5. <!-- orianna: ok -->

**Group 3 — ENCOURAGE layer (shared-rules inline across all paired agents).** 3 tasks, 120 minutes. Depends on: G1 complete (so an entry written from the trigger has a valid home). Unlocks: universal text-level reach.

- [ ] **T6** — Author `.claude/agents/_shared/feedback-trigger.md` per §D4 content (~35 lines). Contains: the 7 triggers, the two-mode invocation contract (coordinator-commit vs subagent-defer-for-sweep), the "do NOT write for" list, the 3-per-session budget + Lux escalation, and the Skarner on-demand query pointer. kind: docs. estimate_minutes: 35. Files: `.claude/agents/_shared/feedback-trigger.md` (new). DoD: file exists at target length; `scripts/lint-subagent-rules.sh` recognizes it as a valid shared file. <!-- orianna: ok -->

- [ ] **T7** — Extend `scripts/sync-shared-rules.sh` to resolve includes at depth 2 (§D4.1). Write xfail test first, then impl. kind: impl. estimate_minutes: 55. Files: `scripts/sync-shared-rules.sh` (edit — add pass-2 scanner for `<!-- include: _shared/feedback-trigger.md -->` markers in already-expanded content), `scripts/__tests__/sync-shared-rules.xfail.bats` (edit — add depth-2 idempotency case). Depends on: T6. DoD: running sync twice on a clean tree produces zero diff (Invariant 5); a paired agent def ends up with both its role shared content AND the feedback-trigger stanza inlined below it; depth-3+ includes produce a clear error pointing at §OQ2.

- [ ] **T8** — Add `<!-- include: _shared/feedback-trigger.md -->` marker to the bottom of each of the 10 existing `_shared/<role>.md` files (`ai-specialist`, `architect`, `breakdown`, `builder`, `frontend-design`, `frontend-impl`, `quick-executor`, `quick-planner`, `test-impl`, `test-plan`); re-run `scripts/sync-shared-rules.sh`; commit the resulting diff across every paired `.claude/agents/*.md`. kind: docs. estimate_minutes: 30. Files: all 10 files under `.claude/agents/_shared/` (edit) + the sync-produced diff on paired agent defs. Depends on: T7. DoD: `scripts/lint-subagent-rules.sh` passes; spot-check of 3 random agent defs (e.g. `.claude/agents/jayce.md`, `.claude/agents/vi.md`, `.claude/agents/karma.md`) confirms the feedback-trigger stanza is present below the role stanza. <!-- orianna: ok -->

**Group 4 — RITUAL layer (skill primitive + 3 session-lifecycle integrations + sweep).** 4 tasks, 180 minutes. Depends on: G1 T2 (schema validator), G3 T8 (agents actually see the trigger). Unlocks: live emission.

- [ ] **T9** — Author `.claude/skills/agent-feedback/SKILL.md` — the atomic write primitive per §D4A.1. Detects caller-type (coordinator-or-Lissandra vs subagent) and branches commit behavior: mode A commits immediately (`chore: feedback — <slug>`), mode B leaves file uncommitted for sweep. Includes the four-field prompt (category, severity, friction-cost-minutes, what-went-wrong+suggestion free-form), filename derivation per §D1 (Asia/Bangkok local time), frontmatter synthesis, and the three-section body structure. kind: docs. estimate_minutes: 60. Files: `.claude/skills/agent-feedback/SKILL.md` (new). DoD: dry-run against a mocked coordinator trigger produces a valid §D1 file + commit; dry-run against a mocked subagent trigger produces a valid §D1 file with no commit; caller-type detection falls back safely (unknown → mode B, no commit). Skill name `agent-feedback` (not `feedback`) to avoid collision with Claude Code's reserved `/feedback` built-in. <!-- orianna: ok -->

- [ ] **T10** — Edit `.claude/skills/end-session/SKILL.md` per §D4A.2 to insert the seven-trigger reflection step before the final commit, AND the coordinator fallback sweep per §D4A.5 at the very end (picks up any `feedback/*.md` left uncommitted by a subagent session that never reached `/end-subagent-session`). Explicit null-output rule: when all triggers clean, log "no feedback this session (all triggers clean)" in the handoff shard — silence is not acceptance. kind: docs. estimate_minutes: 40. Files: `.claude/skills/end-session/SKILL.md` (edit). Depends on: T9. DoD: reflection step text matches §D4A.2 body; sweep step is idempotent against zero uncommitted files; sweep commit uses `chore: feedback sweep — <coordinator> — <date>` prefix; skill verifies each swept entry's own `author:` frontmatter is preserved (sweep-author is coordinator; entry-authors are original subagents). <!-- orianna: ok -->

- [ ] **T11** — Edit `.claude/skills/pre-compact-save/SKILL.md` per §D4A.3 and cross-reference in `.claude/agents/lissandra.md`. Insert the seven-trigger reflection step before Lissandra's final consolidation commit. Voice invariant: feedback's `author:` is the coordinator Lissandra is impersonating (`evelynn` or `sona`), never `lissandra` — Invariant 2. kind: docs. estimate_minutes: 40. Files: `.claude/skills/pre-compact-save/SKILL.md` (edit), `.claude/agents/lissandra.md` (edit). Depends on: T9. DoD: reflection step present in both files; voice invariant stated in both with a cross-reference to Invariants §2; dry-run where Lissandra is mid-compact for Evelynn produces a feedback entry with `author: evelynn`. <!-- orianna: ok -->

- [ ] **T12** — Edit `.claude/skills/end-subagent-session/SKILL.md` to add the §D4A.5 subagent sweep step. Picks up any `feedback/*.md` files the subagent wrote mid-task via mode-B `/agent-feedback` and commits them in a single `chore: feedback sweep — <agent> — <date>` commit after the normal handoff/learnings commit, before the final session-exit report. Fallback: if this skill is not reached (session crash/timeout), the dispatching coordinator's `/end-session` sweep (T10) is the safety net. kind: docs. estimate_minutes: 40. Files: `.claude/skills/end-subagent-session/SKILL.md` (edit). Depends on: T9. DoD: sweep step present; `git status --porcelain | grep '^?? feedback/'` detection logic matches §D4A.5 body; idempotent when zero uncommitted feedback files exist (no-op, no log); double-sweep safety verified (subagent sweep then coordinator sweep finds nothing — no duplicate commit). <!-- orianna: ok -->

**Group 5 — CONSOLIDATE layer (weekly digest via audit piggyback).** 2 tasks, 85 minutes. Depends on: G1 complete + G4 complete (real entries must be emittable before a digest has anything to chew on) + a landed daily-agent-repo-audit Routine (sibling ADR §D10 edit target exists).

- [ ] **T13** — Edit the audit-routine ADR's parent-prompt §D10 to add the Sunday conditional block per §D7 (dispatch Lux-categorize + Karma-triage additionally when `day-of-week == 0`, consume outputs into `assessments/feedback-digests/$DATE.md`, mutate feedback `state:` on `graduate`/`stale` verdicts, include digest summary in commit + Evelynn inbox message). Cross-reference `architecture/audit-routine.md` (created by the sibling ADR's T4). Author `.claude/skills/feedback-consolidate/SKILL.md` — the Sunday dispatch skill Lux + Karma execute. Name explicitly `feedback-consolidate`, not `feedback` (collision with built-in) and not `agent-feedback` (collision with T9 write primitive). kind: docs. estimate_minutes: 50. Files: `plans/proposed/personal/2026-04-21-daily-agent-repo-audit-routine.md` §D10 (edit), `architecture/audit-routine.md` (edit pending sibling T4), `.claude/skills/feedback-consolidate/SKILL.md` (new). Depends on: sibling audit-routine ADR landed at `plans/in-progress/` or later. DoD: Sunday conditional block exists in sibling §D10; consolidate skill contains Lux-categorize dispatch template (group by category + similarity, flag `graduate`/`keep-open`/`stale`) AND Karma-triage dispatch template (one-paragraph problem + one-paragraph candidate solution + proposed owner for each `graduate` entry) AND the §D5 digest schema; token-budget note (~50k in / ~12k out) retained. Invariant 7 preserved: consolidate writes only to `assessments/feedback-digests/**` (never mutates `feedback/*.md` bodies, only frontmatter `state:`). <!-- orianna: ok -->

- [ ] **T14** — First live digest dry-run against the five migrated entries + any net-new week-one entries. Lux + Karma produce `assessments/feedback-digests/<first-sunday-after-launch>.md`. Evelynn + Duong review; pattern locks in or digest schema amendment graduates to a follow-up edit to this ADR. kind: meta. estimate_minutes: 35. Files: `assessments/feedback-digests/<date>.md` (new). Depends on: T13. DoD: digest follows §D5 schema; identifies the Orianna-signing cluster (entries 1 + 2 from the migration set) as `graduate` with a named candidate ADR stub pointing at recommendation A of `feedback/2026-04-21-orianna-signing-latency.md`; at least one `keep-open` and one `stale` or `low` entry disposition is exercised so the pipeline's non-graduate paths are verified live. <!-- orianna: ok -->

## Test plan

`tests_required: false` because this ADR is documentation + configuration + shell scripts. Rationale: no `apps/**` code lands; the Node shim in T2 is a thin YAML parser with no business logic; the hook logic is a bash if-then-regenerate pattern that's straightforward. Per `architecture/plan-frontmatter.md` Quick reference, opting out requires a justification in the plan body — this paragraph is that justification. <!-- orianna: ok -->

That said, three lightweight invariant checks run as part of the task DoDs and will be captured as bats tests alongside the existing `scripts/__tests__/` suite: <!-- orianna: ok -->

1. **Schema validator (G1 T2 DoD).** `scripts/feedback-index.sh --check` against:
   - Five valid fixtures (the migrated entries) → exit 0.
   - Three malformed fixtures (missing `severity`, invalid `category` enum, missing `## What went wrong` section) → exit non-zero with the faulty field named in stderr.
2. **Hook blocking (G1 T3 DoD).** A synthetic commit that edits a feedback file with malformed frontmatter → hook fails loud, commit rejected. A valid edit → INDEX is regenerated, staged, commit succeeds.
3. **Sync depth-2 idempotency (G3 T7 DoD).** Running `scripts/sync-shared-rules.sh` twice on a clean tree produces zero diff (Invariant 5). Running once on a tree where `_shared/feedback-trigger.md` has changed by one line produces the expected one-line change in each of the 10 `_shared/*.md` files AND in each paired agent def. <!-- orianna: ok -->
4. **Author-fidelity (G4 T11 DoD).** Dry-run Lissandra-impersonating-Evelynn pre-compact emits `feedback/*.md` with `author: evelynn`, never `author: lissandra` (Invariant 2). <!-- orianna: ok -->
5. **Sweep idempotency (G4 T10 + T12 DoD).** With zero uncommitted `feedback/*.md` files, both sweep steps exit cleanly with no commit. With one uncommitted feedback file, only the first sweep path that runs commits it; the second finds nothing (Invariant 1 preserved — one file-writing path, one committing path). <!-- orianna: ok -->

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
- **OQ5 — Skarner's `feedback-search` route.** Resolved in G2 T5 (query grammar: `feedback-search <category|severity|author|keyword>`, search order: INDEX → live entries → archived on `--include-archived`). Listed here only to note that the grammar is deliberately conservative; extensions (regex, frontmatter-field filters beyond the four named) are deferred until a real use case emerges.
- **OQ6 — Does Sona read this same `feedback/INDEX.md`?** Yes, per §6 G2 T4. But Sona's startup chain is in `agents/sona/CLAUDE.md` (work-concern specific); the boot-chain edit in T4 lands in both coordinator CLAUDE.md files, not just Evelynn's. <!-- orianna: ok -->
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
