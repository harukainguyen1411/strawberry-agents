---
status: proposed
concern: personal
owner: swain
created: 2026-04-21
tests_required: true
complexity: complex
tags: [coordinator, evelynn, sona, preferences, learning, decisions, memory]
related:
  - plans/approved/personal/2026-04-21-memory-consolidation-redesign.md
  - agents/memory/duong.md
  - .claude/skills/end-session/SKILL.md
  - .claude/skills/pre-compact-save/SKILL.md
architecture_impact: refactor
---

# Coordinator decision-feedback & preference learning — predict, record, calibrate

## 1. Problem & motivation

Every time Evelynn or Sona presents Duong with a decision (the a/b/c format from `agents/memory/duong.md` §Decision-Presentation Format), the loop is currently lossy in two directions:

1. **No pre-commitment.** The coordinator offers options and states a recommendation, but does not record, for itself, a *prediction* of what Duong will pick. There is no artifact to be wrong against.
2. **No structured feedback corpus.** Duong's compact reply (e.g. `1a 2b 3a`) is consumed in-session and then flows into the shard/journal as prose. Nothing aggregates the pattern "for scope-vs-debt questions, Duong picks `a` 80% of the time; for aesthetics questions, he prefers `b` when `c` was recommended." Over 6 months of dense decision traffic, all this signal is sitting in transcripts, unreachable to the next boot's reasoning.

Result: the coordinator's recommendation accuracy never improves by mechanism — only by whatever personality-bleed a human reader would notice reading their own past journals. The stated goal (`agents/memory/duong.md` §Hands-off mode) of auto-deciding on behalf of Duong when confidence is high is unachievable today because there is no confidence, only vibes.

This plan builds the minimum mechanism to **predict, record, and calibrate** — the three operations any preference-learning loop requires — as local file state inside the existing two-layer memory architecture (approved `plans/approved/personal/2026-04-21-memory-consolidation-redesign.md`). No external APIs, no embeddings, no paid services. The corpus is flat markdown per-decision plus a rolled-up preference digest; confidence is a per-axis Beta-style pseudo-count, not an ML model.

## 2. Decision

Introduce a **three-file system per coordinator** plus a **one-step capture ritual** bolted onto the existing a/b/c decision-presentation flow.

### 2.1 The three files (per coordinator)

Under `agents/<coordinator>/memory/decisions/`:

- **`log/YYYY-MM-DD-<short-slug>.md`** — one file per decision point. Flat markdown, grep-able, human-editable. Written by the coordinator synchronously when Duong answers (or defers).
- **`preferences.md`** — rolled-up digest, ≤ 150 lines, hand-curated-at-close with per-axis pseudo-count confidence. Eager-loaded at boot alongside `open-threads.md` and `INDEX.md`. The *preferences* are the eager surface; raw decision logs are lazy.
- **`INDEX.md`** — auto-generated one-row-per-decision TL;DR (newest first), columns: date · slug · axis · coordinator pick · Duong's pick · match? · confidence-at-time. Lazy-loaded; Skarner reads it when on-demand retrieval is needed.

### 2.2 The capture ritual

When the coordinator presents a decision question, it MUST now:

1. **Pre-commit a prediction inline** in the same message as the options. The a/b/c format is amended to carry two additional lines per question: `Predict: <letter>` and `Confidence: <low|medium|high>` (three buckets, not a float — prevents false precision).
2. **On Duong's answer (or skip-to-concur), write the decision log file** in the same turn, before the next tool call that acts on the decision. The write is cheap (single file, 15–40 lines) and atomic.
3. **At `/end-session`**, fold new decision logs into the per-axis pseudo-count in `preferences.md`. This is the only calibration step — run once per session close, in lockstep with the memory-consolidation plan's INDEX regen.

### 2.3 What "axis" means (the only non-trivial design choice)

A preference axis is a labelled dimension of taste that recurs across decisions. Examples grounded in Duong's actual answers:

- `scope-vs-debt` — cleanness vs. speed (a vs. c in the decision-presentation format)
- `explicit-vs-implicit` — declare-it-up-front vs. infer-from-usage
- `single-writer-vs-multi` — concurrency model preferences
- `hand-curated-vs-automated` — human-judgement vs. mechanism-judgement
- `aesthetics-generic-vs-distinctive` — default look vs. visual identity
- `rollout-phased-vs-single-cutover` — migration cadence
- `tool-choice-local-vs-hosted` — build vs. buy, local vs. SaaS

Axes are **coordinator-proposed, Duong-approved** — seeded from the first 20 decisions, then stable. Each decision log tags one or more axes. `preferences.md` carries a one-paragraph summary + pseudo-count per axis. This is the mechanism by which accumulated examples become actionable predictions: when a new question hits axis X, the coordinator's recommendation leans toward the majority pick on that axis, weighted by sample size.

### 2.4 Single mechanism, dual instance

One shared schema, two physically separate stores — `agents/evelynn/memory/decisions/` and `agents/sona/memory/decisions/`. Each coordinator learns its own concern's taste. A work-concern decision ("which deploy cadence for the pipeline") does not bleed into personal-concern recommendations ("which colour for the dashboard") because the axes and the pseudo-counts are kept apart. No shared corpus — explicit and clean, and it mirrors the existing memory split (only memory and learnings are shared globally, not plans/assessments/decisions).

### 2.5 Confidence-gated auto-decide (v2, gated behind explicit switch)

Confidence threshold and auto-decide are **deliberately out of v1**. v1 collects the corpus and publishes the digest; v2 flips a switch. Rationale: there is nothing to threshold against until the corpus has ≥ N samples per axis (recommended N = 10). Launching auto-decide before the corpus is calibrated would amplify the coordinator's current biases into irreversible actions. See §10.5 for the v2 gating plan.

## 3. File structure

Concrete paths under `agents/<coordinator>/memory/` for each of Evelynn and Sona:

```
agents/<coordinator>/memory/
├── <coordinator>.md                          # unchanged
├── open-threads.md                           # unchanged (plan §3, memory-consolidation)
├── decisions/                                # NEW top-level
│   ├── preferences.md                        # NEW — rolled-up digest, eager-loaded
│   ├── INDEX.md                              # NEW — one-row-per-decision, lazy-loaded
│   ├── axes.md                               # NEW — axis definitions + provenance
│   └── log/
│       └── YYYY-MM-DD-<slug>.md              # one file per decision point
├── last-sessions/                            # unchanged (memory-consolidation plan)
│   ├── <uuid>.md
│   ├── INDEX.md
│   └── archive/
└── sessions/                                 # unchanged
```

### 3.1 Decision log file — schema

One file per decision point. YAML frontmatter + a small human-readable body. Example:

```yaml
---
decision_id: 2026-04-21-portfolio-currency-scope
date: 2026-04-21
session_short_uuid: a7f3c9e1
coordinator: evelynn
axes: [scope-vs-debt, explicit-vs-implicit]
question: "Portfolio v0 scope: CSV + handler stub, or full event-driven pipeline?"
options:
  - letter: a
    description: "CSV only + handler stub (cleanest, minimal surface)"
  - letter: b
    description: "CSV + one event emit (balanced)"
  - letter: c
    description: "Full pipeline (quickest to feature-complete, more debt)"
coordinator_pick: a
coordinator_confidence: medium
coordinator_rationale: "Duong has consistently picked `a` on scope-vs-debt when the debt is structural. ~70% match rate across last 14 decisions tagged scope-vs-debt."
duong_pick: a
duong_concurred_silently: false     # true if Duong skipped the number (see duong.md §Decision-Presentation)
duong_rationale: "Clean surface. We'll grow it deliberately."
match: true
decision_source: /end-session-shard-a7f3c9e1
---

## Context
<1-3 sentence paragraph: what was the surrounding plan/task, what was the stakes level (reversible vs. irreversible, scoped vs. cross-cutting).>

## Why this matters
<1-2 sentences: what signal this decision carries beyond the immediate pick. For axis calibration.>
```

Schema rules:

- `decision_id` is the filename without `.md`. Collision-safe via an incrementing suffix (`-2`, `-3`) handled by the capture script.
- `axes` is a list — a single decision can carry more than one axis. Used in preference rollup.
- `coordinator_pick` and `coordinator_confidence` are REQUIRED. Empty or missing values fail the capture-script validator (§4.1).
- `duong_pick` allows the special value `concurred-with-coordinator` when Duong skipped the number; in that case `duong_concurred_silently: true` and `match: true`. Record the skip — it is signal (Duong trusted the pick enough to skip).
- `match` is a computed boolean: `coordinator_pick == duong_pick` OR `duong_concurred_silently == true`.
- `decision_source` points at the shard UUID where the decision was observed — grep-back path for full context.

### 3.2 `preferences.md` — schema

Single markdown file, ≤ 150 lines, hand-curated-at-close. Structure:

```
# Preferences — <coordinator> (<concern>)

Last calibrated: YYYY-MM-DD · Total decisions: N · Axes tracked: M

## Axis: scope-vs-debt
  Samples: 17 (a: 12, b: 3, c: 2) · Match rate: 76% · Confidence: medium-high
  Summary: Duong consistently picks cleanness (`a`) when the debt is structural
  or cross-cutting. Picks `b` only when a tight turnaround is explicit. Picks `c`
  (quick-with-debt) only when the debt is visibly cheap to repay (e.g. a throwaway
  script, a scaffold pass).
  Notable misses: 2026-04-17 portfolio event scope (coordinator picked `b`, Duong
  picked `a` — coordinator under-weighted structural-debt signal).

## Axis: explicit-vs-implicit
  ...
```

Rules:

- One `## Axis: <name>` section per axis. Stable ordering — append-only for new axes, never reorder existing ones (diff stability).
- `Samples:` line is auto-regenerated by the end-session fold (§5.2).
- `Summary:` is hand-maintained by the coordinator at session close when the match rate shifts materially. Same curation model as `open-threads.md`.
- `Notable misses:` is a bullet list of up to 3 recent mispredictions (coordinator_pick ≠ duong_pick). Auto-regenerated — keeps the axis honest.
- Confidence buckets derived from sample count: `low` (n < 5), `medium` (5 ≤ n < 15), `medium-high` (15 ≤ n < 40), `high` (n ≥ 40). These are display-only; the raw `n` lives next to each axis, so the threshold is grep-able.

### 3.3 `INDEX.md` — schema

Generated, not hand-maintained. Newest first. Markdown table, one row per decision log file:

```
| Date       | Slug                                  | Axes                        | Coord | Duong | Match | Confidence |
|------------|---------------------------------------|-----------------------------|-------|-------|-------|------------|
| 2026-04-21 | portfolio-currency-scope              | scope-vs-debt, explicit-vs-implicit | a | a | yes | medium |
| 2026-04-21 | memory-index-regen-cadence            | hand-curated-vs-automated   | a     | a     | yes   | high       |
| ...        |                                       |                             |       |       |       |            |
```

Regen on every `/end-session` write (same cadence as the memory-consolidation INDEX). Lazy-loaded at boot only when Skarner is delegated to look for axis-specific history.

### 3.4 `axes.md` — schema

Hand-maintained, append-only. One section per axis:

```
# Axes — <coordinator>

Axis names are stable once added. Deprecation is additive: mark with
`deprecated: YYYY-MM-DD` in the header, do not delete.

## scope-vs-debt
  Added: 2026-04-21
  Definition: Cleanest (`a`) vs quickest-with-debt (`c`) trade-offs.
  When to tag: any decision where the options vary on surface-cleanness /
  structural-debt / long-term-maintainability.
  First decision: 2026-04-21-portfolio-currency-scope

## explicit-vs-implicit
  ...
```

Rules:

- Adding a new axis is a coordinator action at session close. Requires ≥ 2 example decisions that don't fit existing axes before adding.
- Removing an axis is explicitly forbidden. Mark deprecated; old decisions keep tagging it.

## 4. Capture mechanism

### 4.1 New helper `scripts/_lib_decision_capture.sh` (sourced-only) <!-- orianna: ok -->

POSIX bash, sourced by `scripts/capture-decision.sh`. Public functions:

- `validate_decision_frontmatter <file>` — checks required keys (`decision_id`, `date`, `coordinator`, `axes`, `question`, `options`, `coordinator_pick`, `coordinator_confidence`, `duong_pick`). Returns non-zero with `[lib-decision] BLOCK: <detail>` on stderr.
- `compute_match <coord_pick> <duong_pick> <duong_concurred_silently>` — pure stdout `true|false`.
- `infer_slug <question>` — lowercases, replaces whitespace with `-`, strips punctuation, truncates to 40 chars. Suffix collision loop `-2`, `-3` up to `-10` by checking existing files in `log/`.

### 4.2 New script `scripts/capture-decision.sh` <!-- orianna: ok -->

Single entrypoint for writing one decision log file. Invocation:

```
bash scripts/capture-decision.sh <coordinator> --file <path-to-prepared-log.md>
```

Behaviour:

1. Validate frontmatter via `validate_decision_frontmatter`.
2. Infer final path: `agents/<coordinator>/memory/decisions/log/<date>-<slug>.md`. Handle collisions by suffix loop.
3. `git add` the file.
4. Stdout: final path.
5. Exit non-zero if validation fails, file cannot be written, or `decisions/log/` does not exist (create-on-first-use is handled in T8 bootstrap, not here).

The *coordinator* writes the markdown body in its own turn; this script only validates and lands it. Keeps the schema enforcement centralised without coupling the coordinator to a template.

### 4.3 Extension of `scripts/memory-consolidate.sh` <!-- orianna: ok -->

The memory-consolidation plan's script grows one more responsibility: **decision INDEX regen + preferences rollup**, run on every `/end-session` close and on `--index-only`. New pass, strictly after the existing `last-sessions/` INDEX regen (ordering: shard INDEX first so that `decision_source` references still point at live shards before any archival move).

New pass:

1. Walk `agents/<coordinator>/memory/decisions/log/*.md` sorted by mtime descending.
2. Regenerate `decisions/INDEX.md` via the same `_lib_decision_capture.sh` row-render helpers (§4.4 defines them).
3. Regenerate the *counts* in `preferences.md`: for each axis in `axes.md`, count (a, b, c) picks among decisions tagged that axis, compute match rate (coordinator_pick vs duong_pick), regenerate the `Samples:` and `Notable misses:` lines of the corresponding `## Axis:` section in place. Summary prose is preserved verbatim.
4. On axis ordering: never reorder. New axes appended to the bottom.

Idempotency: re-running produces a byte-identical `INDEX.md` and byte-identical `Samples:` / `Notable misses:` lines. Summary prose is left alone.

### 4.4 Row renderer — `_lib_decision_capture.sh` extension <!-- orianna: ok -->

Additional functions:

- `render_index_row <decision_file>` — stdout: one markdown table row matching §3.3 schema.
- `regenerate_decisions_index <coordinator_dir> <output_file>` — walk, sort newest-first, emit header + rows.
- `rollup_preferences_counts <coordinator_dir> <preferences_md_file>` — in-place update of `Samples:` and `Notable misses:` lines; preserve all prose.

## 5. Skill changes

### 5.1 New skill — `.claude/skills/decision-capture/SKILL.md` <!-- orianna: ok -->

`disable-model-invocation: true` — invoked only by the coordinator's internal protocol, not by model choice. Thin wrapper over `scripts/capture-decision.sh`.

Argument: coordinator name. The skill reads stdin for the prepared decision markdown (the coordinator writes the full file content in-line during its turn, then pipes to the skill), validates, writes to the correct path, `git add`s, stdout = final path.

Why a skill, not just a script: the coordinator is already trained to invoke skills via the Skill tool when persistent state crosses a mechanism boundary (see `end-session`, `pre-compact-save`). Wrapping the script in a skill gives us one-stop-shop invocation + the harness can lint the call shape.

### 5.2 `.claude/skills/end-session/SKILL.md` — add Step 6c

After Step 6b (open-threads + shard INDEX regen, per memory-consolidation plan §5.1), add Step 6c for coordinators (`evelynn` OR `sona`):

1. Invoke `bash scripts/memory-consolidate.sh <coordinator> --decisions-only` (new flag: runs only the decision INDEX regen + preferences rollup from §4.3, no archive move, no sessions fold, no commit/push).
2. Stage: `git add agents/<coordinator>/memory/decisions/INDEX.md agents/<coordinator>/memory/decisions/preferences.md`.
3. If the coordinator has edits to make to any `## Axis:` `Summary:` prose (based on this session's decisions), do them now, before staging.
4. Stage `axes.md` only if modified.

Ordering: Step 6c MUST run after Step 6 (shard write) because decision_source references may reference the shard UUID. Step 6c MUST run before Step 9 (commit + push) so all four artifacts (shard, open-threads, last-sessions INDEX, decisions INDEX + preferences) land atomically in one commit.

Non-coordinator agents (Sonnet subagents via `/end-subagent-session`): Step 6c is a no-op.

### 5.3 `.claude/skills/pre-compact-save/SKILL.md` — mirror Step 6c via Lissandra

Same pattern as the memory-consolidation plan §5.2. Lissandra's agent definition (`agents/lissandra/profile.md` + `.claude/agents/lissandra.md`) gains the Step 6c sequence for parity. The skill file itself gets a one-line note. Lissandra writes the coordinator's decision-related artifacts in the coordinator's voice, same as she already does for `last-sessions/<uuid>.md`.

## 6. Agent definition changes

### 6.1 `.claude/agents/evelynn.md` and `.claude/agents/sona.md` — boot script

Both `initialPrompt`s already list the boot chain post-memory-consolidation. Add two lines at positions 8 and 9 of the static-prefix-then-dynamic-tail ordering from the memory-consolidation plan §7:

> 8. `agents/<coordinator>/memory/decisions/preferences.md` <!-- orianna: ok -->
> 9. `agents/<coordinator>/memory/decisions/axes.md` <!-- orianna: ok -->

Positions 7 (`open-threads.md`) and 10 (`last-sessions/INDEX.md`) stay as-is. New preferences/axes files slot between them because:

- `preferences.md` is hand-curated-at-close, churns slowly (summary prose changes ~weekly), so it lives in the dynamic tail but above the highest-churn file.
- `axes.md` is append-only and churns rarely (a new axis every few weeks at most), so it could live earlier in the static prefix, but we keep it adjacent to `preferences.md` for locality of reasoning.
- `last-sessions/INDEX.md` stays last (highest churn: per-session).

`decisions/INDEX.md` and individual `log/*.md` files are NOT eager-loaded. They are lazy, pulled on-demand by Skarner or by the coordinator when a new decision's axes need historical calibration.

### 6.2 `.claude/agents/evelynn.md` and `.claude/agents/sona.md` — decision-capture protocol

Add a new section to the agent definition (between the existing `initialPrompt` and the closing): a "Decision Capture Protocol" block.

Content (template, swap names for Sona):

> When presenting Duong with a decision in the a/b/c format (per `agents/memory/duong.md` §Decision-Presentation Format), every question MUST carry an inline prediction and confidence. Shape:
>
> ```
> N. <question>
>    a: cleanest but might take more time/effort
>    b: balanced
>    c: quickest, but might introduce debt
> Pick: <your recommendation + one-line why>
> Predict: <letter>
> Confidence: <low|medium|high>
> ```
>
> The `Pick:` line is your public recommendation. The `Predict:` line is your *private* forecast of what Duong will actually pick — they may differ when you are recommending one thing but expect Duong to veto based on axis history. `Confidence:` is a three-bucket subjective rating informed by `decisions/preferences.md` sample sizes and match rates on the tagged axes.
>
> When Duong answers (or skips to concur per duong.md §Decision-Presentation), before taking any action that depends on the decision:
>
> 1. Compose the decision log file body (YAML frontmatter + ## Context + ## Why this matters per §3.1 of the decision-feedback plan).
> 2. Invoke the `decision-capture` skill, piping the file contents on stdin.
> 3. On success (stdout = final path), proceed. On validation failure, repair and retry once; if a second failure, surface the error to Duong as a capture gap and proceed without the log rather than blocking the decision.

### 6.3 `.claude/agents/evelynn.md` and `.claude/agents/sona.md` — Operating Modes addendum

`agents/memory/duong.md` §Operating Modes already defines hands-on (default) and hands-off. Add one line to each coordinator's Operating Modes block:

> In both modes, the decision-capture ritual (§Decision Capture Protocol) still runs. In hands-off mode, the coordinator records `duong_pick: hands-off-autodecide` and `coordinator_autodecided: true` in the log. This preserves the learning signal (the coordinator made its own pick and it went through) without conflating it with Duong's explicit picks. Axis rollup in `preferences.md` counts hands-off autodecides separately so match-rate numbers stay honest.

`preferences.md` schema gains a parenthetical column for axes where hands-off autodecides exist: `Samples: 17 (a: 12, b: 3, c: 2; +4 hands-off)`. Kept in the same line for diff stability.

### 6.4 `agents/evelynn/CLAUDE.md` §Startup Sequence + `agents/sona/CLAUDE.md`

Add two new bullets between the current steps 7 (open-threads) and 8 (INDEX), mirroring §6.1:

- `agents/<coordinator>/memory/decisions/preferences.md` — axis-digest with sample counts and match rates (eager).
- `agents/<coordinator>/memory/decisions/axes.md` — axis definitions, append-only (eager).

Renumber subsequent entries.

### 6.5 `agents/memory/agent-network.md` — extend "Memory Consumption" section

The memory-consolidation plan §6.4 adds a Memory Consumption section. Extend it with:

- Coordinators track decision-level preferences at `agents/<coordinator>/memory/decisions/`.
- `preferences.md` is eager (boot-loaded); `log/*.md` and `INDEX.md` are lazy (on-demand).
- To search decisions by axis or keyword: delegate to Skarner; Skarner greps `log/` and returns file paths + excerpts.
- Subagents MUST NOT eagerly load another coordinator's `decisions/`.

## 7. Retrieval mechanisms (what the corpus gets used for)

The plan supports three distinct retrieval patterns, listed by scope:

### 7.1 Per-question axis lookup (synchronous, in-coordinator)

When the coordinator is about to present a new question, it consults `preferences.md` for the relevant axis. This is *eager* — `preferences.md` is boot-loaded, so the lookup is a substring read already in context. Cost: zero extra tokens beyond boot. Latency: zero extra calls.

This is the primary retrieval mechanism. Confidence and Predict directly come from this lookup.

### 7.2 Per-axis deep-dive (Skarner delegation)

When the coordinator wants to sanity-check a recommendation (e.g., the axis summary says "Duong picks `a` ~70%" but the current question feels like an edge case), it delegates to Skarner with a query like "find me the last 5 decisions tagged `scope-vs-debt` where Duong picked `b`". Skarner greps `log/` on `axes:` and `duong_pick:` fields, returns file paths + the `## Why this matters` paragraph. Cost: one subagent call. Latency: tens of seconds.

Reserved for edge cases. Not every question triggers this.

### 7.3 Cross-coordinator or full-corpus search (also Skarner)

Rare. "Has Duong ever pushed back on a 14-day retention window?" — Skarner greps across both coordinators' `log/` directories. Same mechanism as 7.2, wider scope. Returns excerpts, not summarisation.

### 7.4 Explicitly NOT used: boot-time full corpus load

Full decision log corpus is NEVER eager-loaded. At 100 decisions/month × 2 coordinators × 12 months = 2,400 files, eager load would defeat the entire purpose. The eager surface is capped at `preferences.md` (≤ 150 lines). Historical detail is always lazy.

## 8. Calibration loop — from predictions to improved predictions

### 8.1 Per-session fold (every `/end-session`)

§4.3 defines the mechanism: walk new `log/*.md` files, recompute `Samples:` and `Notable misses:` per axis in `preferences.md`. Mechanical, idempotent. Takes sub-second on a 2,400-file corpus (it's a grep + count).

### 8.2 Narrative summary update (coordinator judgement, weekly-ish)

The `Summary:` prose in each `## Axis:` section is hand-maintained. The coordinator updates it when the pattern has visibly shifted — not every close, but whenever the match rate moves ≥ 10 percentage points on an axis with ≥ 10 samples, or a new pattern emerges ("Duong now prefers `b` in scope-vs-debt when the task is a rollback"). This is the only judgement-requiring step; the counts are pure mechanism.

Why hand-curated: the same reasoning as `open-threads.md` in the memory-consolidation plan. An LLM auto-summariser would reintroduce noise and drift; the curation IS the value.

### 8.3 Axis introduction/retirement (coordinator + Duong approval)

Adding an axis is a coordinator action at session close, but **requires Duong's approval** before it becomes part of the schema. Protocol: coordinator proposes the new axis inline in its final end-session report as a dedicated a/b/c question (`Propose new axis: <name>? a: add, b: modify, c: defer`). Duong answers. If `a`, coordinator adds to `axes.md` and seeds it with the 2+ example decisions that prompted it. The proposal itself is captured as a decision log — meta-level, but uniform.

Axes are never deleted (§3.4). Deprecation is allowed: mark `deprecated: YYYY-MM-DD` in `axes.md`; no new decisions tag it, but historical counts remain and stay visible in `preferences.md`.

### 8.4 Overfit prevention

Three mechanisms:

1. **Small bucket confidence** — `low` confidence for n < 5 means the coordinator's `Predict:` line inherits low confidence on undersampled axes. No early lock-in.
2. **Notable misses are required** — auto-regenerated, visible at every boot. The coordinator can't hide from recent mispredictions.
3. **Hands-off autodecide counted separately** — §6.3 guarantees the match-rate numbers reflect Duong's explicit picks, not the coordinator's own agreement with itself.

### 8.5 Cold-start

First 20 decisions are collected under `confidence: low` across all axes. During this window, the `Predict:` line equals the `Pick:` line by default (the coordinator has no independent signal). `preferences.md` starts empty except for axes extracted from the first decisions' tagged axes.

## 9. Integration with the in-flight memory-consolidation plan

`plans/approved/personal/2026-04-21-memory-consolidation-redesign.md` (approved, not yet implemented) establishes the two-layer memory shape. This plan slots in cleanly as an additional tier under the same two-layer pattern:

| Layer | Memory-consolidation tier | Decision-feedback tier |
|---|---|---|
| Eager curated | `open-threads.md` | `preferences.md` + `axes.md` |
| Lazy auto-generated manifest | `last-sessions/INDEX.md` | `decisions/INDEX.md` |
| Lazy full detail | `last-sessions/<uuid>.md` | `decisions/log/<date>-<slug>.md` |

Boot order (final, post-both-plans):

1. `agents/<coordinator>/CLAUDE.md` (static)
2. `agents/<coordinator>/profile.md` (static)
3. `agents/<coordinator>/memory/<coordinator>.md` (slow-churn)
4. `agents/memory/duong.md` (static)
5. `agents/memory/agent-network.md` (slow-churn)
6. `agents/<coordinator>/learnings/index.md` (slow-churn)
7. `agents/<coordinator>/memory/open-threads.md` (high-churn — memory-consolidation)
8. `agents/<coordinator>/memory/decisions/preferences.md` (medium-churn — this plan)
9. `agents/<coordinator>/memory/decisions/axes.md` (slow-churn — this plan)
10. `agents/<coordinator>/memory/last-sessions/INDEX.md` (high-churn — memory-consolidation)

`axes.md` is at position 9 (not earlier) because it needs to load after `preferences.md` references axis names, so the coordinator sees definition + usage stats together. `decisions/INDEX.md` and `log/` are deliberately absent from the eager chain — Skarner delegation is the retrieval path.

Token budget (estimate, post-bootstrap):

- `preferences.md` at 10 axes × 8 lines ≈ 80 lines ≈ 2–3 KB ≈ 500–700 tokens.
- `axes.md` at 10 axes × 6 lines ≈ 60 lines ≈ 2 KB ≈ 400–500 tokens.
- Combined: ~1–1.2k tokens added to the dynamic tail. Compared to the memory-consolidation plan's ~8–9k token savings, net boot cost goes down.

Ordering dependency: **this plan depends on the memory-consolidation plan being at least in `in-progress/`** before the scripts ship, because `scripts/memory-consolidate.sh` is rewritten by that plan and re-extended by this one. Serialising the two is the cleanest path (see §10.5 rollout).

## 10. Failure modes & mitigations

| # | Failure | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | Coordinator forgets to write Predict/Confidence inline | Medium (during cold-start) | Low — no log captured that turn | The a/b/c template lives in the agent def §6.2; the skill lints the output in Step 6c and surfaces the gap at session close. Missed captures are noise, not corruption. |
| 2 | Coordinator's prediction is systematically wrong on an axis | High (expected early on) | Medium — if left uncorrected, drives bad Predict on future questions | `Notable misses:` list surfaces the gap at every boot. After 3 consecutive mispredictions on the same axis, the coordinator MUST flag this in its `/end-session` report and either (a) update the axis `Summary:` prose or (b) propose an axis split. Self-correcting mechanism. |
| 3 | Axes proliferate uncontrolled (20+ axes, fragmented counts) | Medium | Medium — dilutes per-axis signal | §8.3 requires Duong approval for new axes + a 2-decision prerequisite. Retirement is allowed. Cap soft-enforced: when `axes.md` reaches 15 live axes, the coordinator's axis-proposal a/b/c question defaults its recommendation to `c: defer`. |
| 4 | Duong disagrees with the coordinator's axis tagging for a specific decision | Medium | Low — one log mis-tagged | Duong can inline-edit the log file post-hoc; `preferences.md` rollup is recomputable at any time. Script is idempotent. |
| 5 | Capture skill fails mid-flow (disk full, git add fails) | Low | Low — decision proceeds, log missing | §6.2 protocol: retry once, then proceed without log, surface to Duong in final report. Loss of a single log is cheap. |
| 6 | v2 auto-decide fires on an axis that was overfit | N/A for v1 | High in v2 | v2 is explicitly gated (§10.5). Gate = minimum n per axis + Duong's explicit switch-on per-axis. Not a v1 risk. |
| 7 | `preferences.md` diverges from `log/` contents (stale rollup) | Low | Medium — predictions lean on wrong counts | Every `/end-session` regenerates the counts. Drift window = at most one session. Same invariant as the memory-consolidation INDEX. |
| 8 | Decision log files accumulate unboundedly | Low | Low — disk/git size | At 2,400 files/year × ~1.5 KB = 3.6 MB/year. No retention policy in v1; revisit at year 2. Grep is still sub-second at this scale. |
| 9 | Two parallel coordinator sessions race on `preferences.md` | Low | Medium — merge conflict | Same class as `open-threads.md` race in memory-consolidation plan §10. Advisory lock in `memory-consolidate.sh` (inherited) serialises the rollup. File-level conflicts surface at push-time and are fixable. |
| 10 | Coordinator auto-decides wrong (v2 only, future) | N/A v1 | High v2 | Duong's override path is simple: type the correction in plain language, coordinator writes a correction-log entry (`decision_type: override`), the miss updates the axis rollup. See §10.5. |

### 10.5 v2 auto-decide gating plan (out of scope, documented)

Not in this plan's tasks. Flagged for a later ADR:

- Precondition: axis must have ≥ 10 samples AND ≥ 70% match rate AND Duong's explicit per-axis opt-in (recorded as a decision log with `axis_autodecide_enabled: true`).
- Mechanism: coordinator presents the question as normal but appends `AutoDecide: yes (axis <name>, confidence <level>)`. Duong has a 10-second grace window to override in the next message; otherwise the coordinator proceeds.
- Overrides ALWAYS update the axis rollup and reset the autodecide eligibility (falls back to manual until another 3 consecutive matches on the axis).
- Separate plan, separate gates. Not this one.

## 11. Out of scope

Explicitly excluded from this plan; revisit criteria noted per item:

- **Auto-decide in v1** — per §10.5, gated behind a future ADR once the corpus has ≥ 10 samples per axis across both coordinators.
- **Cross-coordinator preference sharing** — Evelynn and Sona maintain separate preferences. Concerns differ; taste on "deploy cadence" is not the same in personal vs. work contexts. Revisit if a pattern clearly applies to both (unlikely before 50+ decisions on each side).
- **LLM-based axis auto-tagging** — axes are coordinator-tagged at capture time. An LLM auto-tagger would reintroduce the same noise problem Lux's memory-consolidation recommendation identifies. Coordinator judgement is cheap (one or two axis names per decision) and self-auditable via the log.
- **LLM-based summary auto-generation for `preferences.md`** — same reasoning. Hand-curated > auto-generated.
- **Vector embeddings or semantic search across decisions** — violates the no-paid-API constraint, adds operational complexity, and at 2,400 decisions/year grep is sub-second. Revisit at 10× scale.
- **Per-decision confidence as a float** — rejected. Three buckets (low/medium/high) prevent false precision and match the way Duong actually reasons about these.
- **Decision log retention / archival** — v1 is append-forever. Disk impact at year 2 is negligible (<10 MB). Revisit when counts cross 10k files.
- **Subagent decision capture** — subagents don't present a/b/c decisions to Duong directly (they get routed through the coordinator). If a subagent inadvertently captures a decision, it goes in the coordinator's log (attributed via `decision_source`).
- **A dashboard / web UI for decision browsing** — grep + `cat` is the query interface for v1. If Duong finds himself repeatedly running the same searches, surface a table in the next retrospection-dashboard iteration.
- **Per-topic or per-project decision namespaces** — axes subsume topical grouping. A `deployment-cadence` axis captures all deployment-cadence decisions; no need for a separate namespace.

## 12. Tasks

- [ ] **T1** — Write xfail tests for `scripts/_lib_decision_capture.sh` frontmatter validation + slug inference + match computation. estimate_minutes: 40. Files: `scripts/test-decision-capture-lib.sh` (new). DoD: fixture-driven assertions for valid/invalid frontmatter, collision-suffix slug generation, match truth-table; all failing xfail; committed before T2 (Rule 12). <!-- orianna: ok -->
- [ ] **T2** — Build `scripts/_lib_decision_capture.sh` + `scripts/capture-decision.sh`. estimate_minutes: 50. Files: `scripts/_lib_decision_capture.sh` (new), `scripts/capture-decision.sh` (new). DoD: all T1 tests pass; `validate_decision_frontmatter`, `compute_match`, `infer_slug`, `render_index_row`, `regenerate_decisions_index`, `rollup_preferences_counts` implemented per §4.1–§4.4; POSIX bash; idempotent rollup verified on a 5-file fixture.
- [ ] **T3** — Write xfail tests for `memory-consolidate.sh --decisions-only` extension. estimate_minutes: 35. Files: `scripts/test-memory-consolidate-decisions.sh` (new). DoD: fixture with 12 decision logs across 3 axes; assertions on INDEX row ordering, `Samples:` line counts, `Notable misses:` selection (last 3 misses per axis), summary-prose preservation; all xfail; committed before T4. <!-- orianna: ok -->
- [ ] **T4** — Extend `scripts/memory-consolidate.sh` with decision pass + `--decisions-only` flag. estimate_minutes: 45. Files: `scripts/memory-consolidate.sh`. DoD: T3 tests pass; pass runs strictly after `last-sessions/` INDEX regen; `--decisions-only` returns sub-second on the 12-file fixture; advisory lock shared with existing passes.
- [ ] **T5** — Write xfail tests for `decision-capture` skill shape + `/end-session` Step 6c integration. estimate_minutes: 35. Files: `scripts/test-decision-capture-skill.sh` (new), `scripts/test-end-session-step-6c.sh` (new). DoD: §5.1 skill file shape asserted; §5.2 Step 6c ordering (after 6b, before Step 9) asserted by grep; all xfail; committed before T6. <!-- orianna: ok -->
- [ ] **T6** — Create `.claude/skills/decision-capture/SKILL.md` + update `.claude/skills/end-session/SKILL.md` with Step 6c. estimate_minutes: 30. Files: `.claude/skills/decision-capture/SKILL.md` (new), `.claude/skills/end-session/SKILL.md`. DoD: §5.1 + §5.2 shapes in place; T5 tests pass; skill is `disable-model-invocation: true`.
- [ ] **T7** — Update Lissandra protocol for Step 6c parity. estimate_minutes: 20. Files: `.claude/agents/lissandra.md`, `agents/lissandra/profile.md`, `.claude/skills/pre-compact-save/SKILL.md` (one-line note). DoD: §5.3 changes landed; dry-run pre-compact-save on a test session regenerates decisions INDEX + preferences identically to `/end-session`.
- [ ] **T8** — Bootstrap `decisions/` directory trees + seed `axes.md` and empty `preferences.md` for both coordinators. estimate_minutes: 35. Files: `agents/evelynn/memory/decisions/axes.md` (new), `agents/evelynn/memory/decisions/preferences.md` (new, empty template), `agents/evelynn/memory/decisions/log/.gitkeep` (new), `agents/sona/memory/decisions/axes.md` (new), `agents/sona/memory/decisions/preferences.md` (new), `agents/sona/memory/decisions/log/.gitkeep` (new). DoD: four initial axes pre-seeded in each `axes.md` (`scope-vs-debt`, `explicit-vs-implicit`, `hand-curated-vs-automated`, `rollout-phased-vs-single-cutover`); `preferences.md` skeleton has a `## Axis:` section per seeded axis with zero samples; subsequent decisions populate counts via T4's rollup. <!-- orianna: ok -->
- [ ] **T9** — Update `.claude/agents/evelynn.md` + `.claude/agents/sona.md`: boot chain (§6.1) + Decision Capture Protocol (§6.2) + Operating Modes addendum (§6.3). estimate_minutes: 40. Files: `.claude/agents/evelynn.md`, `.claude/agents/sona.md`. DoD: boot order §9 in both defs; Decision Capture Protocol section present with the a/b/c+Predict+Confidence template and the 3-step capture protocol; Operating Modes addendum addresses hands-on/hands-off parity.
- [ ] **T10** — Update `agents/evelynn/CLAUDE.md` + `agents/sona/CLAUDE.md` Startup Sequence (§6.4) + extend `agents/memory/agent-network.md` Memory Consumption section (§6.5). estimate_minutes: 25. Files: `agents/evelynn/CLAUDE.md`, `agents/sona/CLAUDE.md`, `agents/memory/agent-network.md`. DoD: §6.4 and §6.5 edits landed; boot order matches §9; subagent-facing consumption doc reads clean on a fresh pass.
- [ ] **T11** — Add `architecture/coordinator-decision-feedback.md` documenting the final shape. estimate_minutes: 40. Files: `architecture/coordinator-decision-feedback.md` (new). DoD: sections covering schemas (§3), capture flow (§4–§5), retrieval patterns (§7), calibration loop (§8), integration with `coordinator-memory.md` (§9), v2 gating summary (§10.5); cross-referenced from `agents/evelynn/CLAUDE.md` and `agents/sona/CLAUDE.md`. <!-- orianna: ok -->
- [ ] **T12** — Dogfood + evidence: run a full session with the new capture ritual, produce 3+ decision logs, confirm preferences.md rolls up correctly, confirm boot-prefix cache still holds for the static prefix. estimate_minutes: 30. Files: none new. DoD: 3+ `log/*.md` files exist on Evelynn side after one session; `preferences.md` Samples: lines are populated; boot token count for positions 8+9 measured (target: ≤ 2 KB combined, per §9 estimate); evidence captured in the implementation PR body.

Total estimate: 425 minutes.

## Test plan

Xfail-first commits (T1, T3, T5) land on the feature branch before their implementation commits (T2, T4, T6). Invariants the test harness protects:

- **Schema invariant** — Every decision log file carries a valid frontmatter per §3.1; validator rejects missing required fields, malformed axes list, or missing coordinator_pick / coordinator_confidence (§9.1 of the validator tests in T1).
- **Rollup idempotency invariant** — Running `memory-consolidate.sh --decisions-only` twice in a row produces byte-identical `INDEX.md`, byte-identical `Samples:` / `Notable misses:` lines in `preferences.md`, and does not touch the hand-curated `Summary:` prose (§3.2 + §4.3).
- **Ordering invariant** — `/end-session` Step 6c runs strictly after Step 6b and before Step 9, so the decision INDEX regen sees the shard written in Step 6 and the commit in Step 9 contains all four artifacts. Shape test via grep (T5).
- **Axis-introduction gate invariant** — A new axis cannot be tagged on a decision log without existing in `axes.md` at rollup time; rollup script refuses and fails loud (§4.3).
- **Hands-off separation invariant** — Decisions with `duong_concurred_silently: true` vs. `coordinator_autodecided: true` (v2-ready field, always false in v1) are counted in separate buckets in the Samples: line so match-rate is not inflated (§6.3, T4 tests).
- **No-orphan invariant** — `capture-decision.sh` refuses to run if `agents/<coordinator>/memory/decisions/log/` does not exist, preventing typos from silently writing to the wrong path.
- **Eager-boundary invariant** — Only `preferences.md` and `axes.md` are eager-loaded. Grep test (T5) asserts the boot chain in `.claude/agents/evelynn.md` and `.claude/agents/sona.md` does not reference `INDEX.md` or `log/` for the decisions tier.
- **Capture-ritual shape invariant** — The Decision Capture Protocol block in each coordinator's agent-def references both `Predict:` and `Confidence:` lines with correct bucket enum.

Test harnesses live alongside existing scripts (`scripts/test-*.sh`) and are invoked by the pre-push hook chain. Pre-push TDD gate (`scripts/hooks/pre-push-tdd.sh`) enforces xfail-before-impl on the branch.

## Rollback

Low-risk, local-only rollback. No external integration, all additive (no schema mutation, no destructive file moves).

1. Revert the implementation PR commits in reverse order (merge, not rebase — Rule 11):
   - Revert T12 evidence commit (no-op).
   - Revert T9 + T10 + T11 (agent-def / CLAUDE.md / architecture edits).
   - Revert T8 bootstrap (removes seeded `decisions/` files — safe because pre-change state had no such dir).
   - Revert T6 + T7 (skill + Lissandra changes).
   - Revert T4 (strip the decision pass from `memory-consolidate.sh`; keep the memory-consolidation-plan passes).
   - Revert T2 + T3 + T1 (scripts + tests).
2. Any `log/*.md` files written before rollback stay in git history (immutable). No data loss. If Duong wants to resurrect later, `git checkout` of the relevant files onto a new plan restores the corpus.
3. No push to prod, no external system to reset.

Unique rollback wrinkle: if T4 extension is already live and `log/*.md` files have accumulated, rolling back T4 leaves the logs orphaned (no rollup runs). This is benign — the logs are still valid per-file and grep-able; the `preferences.md` file just stops updating. Coordinator continues to function without auto-prediction until T4 is re-applied.

## Open questions

- **OQ1** — Should the initial seed of `axes.md` (T8) include 4 axes or a smaller kernel (e.g., just `scope-vs-debt`)? Recommendation: **4 seeded axes**. Fewer seeds force the coordinator into "propose new axis" mode in the first week, which is noisy. Four concrete starters (scope-vs-debt, explicit-vs-implicit, hand-curated-vs-automated, rollout-phased-vs-single-cutover) cover ~60% of decisions observed in the current `agents/memory/duong.md` + recent shards. Surface to Duong if he wants a different opening set.
- **OQ2** — Should `preferences.md` be boot-loaded before `axes.md` (current order) or after? Recommendation: **preferences before axes**, because the summary prose in `preferences.md` references axis names and the coordinator can still grep `axes.md` for exact definitions. Reversed order would make a cold read of `preferences.md` reference undefined-yet names. Flag if Duong finds the reversed order clearer on first pass.
- **OQ3** — `Predict:` vs. `Pick:` divergence: should divergence be *allowed* (coordinator recommends `a` but privately predicts `b`)? Recommendation: **allowed**. The two serve different purposes: `Pick:` is the coordinator's independent judgement of the best answer; `Predict:` is the forecast of Duong's answer. When they diverge, the coordinator is implicitly saying "I think option X is correct but I expect you to choose Y based on our history" — that is a valuable piece of information for Duong to see. An enforcement rule that `Predict == Pick` collapses the two into one, losing that signal.
- **OQ4** — Should decision capture be blocking or non-blocking on the coordinator's turn? I.e., if `capture-decision.sh` fails (validation, git add, etc.), does the coordinator proceed anyway? Recommendation: **non-blocking with one retry + loud report**. See §10 failure mode #5. A failed capture is a tolerable gap (one missing data point); blocking the decision would be hostile to the primary UX (decisions must complete promptly). Flag if Duong has a different risk tolerance.
- **OQ5** — Ordering vs. memory-consolidation plan: should this plan be held until the memory-consolidation plan reaches `implemented`, or can the two be worked in parallel? Recommendation: **serial — wait for memory-consolidation to hit `in-progress/` minimum**. The `memory-consolidate.sh` script is rewritten by that plan and re-extended by this one. Attempting both in parallel means twin-branch merge pain on a single script. Serial = cleaner. Flag if Duong wants them collapsed into one combined rollout.
