# Coordinator Decision Feedback

This document describes the decision-capture and feedback system for coordinator sessions (Evelynn, Sona). It covers schemas, capture flow, retrieval patterns, the calibration loop, integration with the memory system, and the v2 auto-decide gating plan.

Source ADR: `plans/approved/personal/2026-04-21-coordinator-decision-feedback.md`

---

## §3 — File schemas

### §3.1 Decision log file — schema

Location: `agents/<coordinator>/memory/decisions/log/YYYY-MM-DD-<slug>.md`

```markdown
---
date: 2026-04-21
coordinator: evelynn
axes: [scope-vs-debt, explicit-vs-implicit]
duong_pick: b
coordinator_pick: a
coordinator_autodecided: false
confidence: medium
---

## Context
<1-3 sentences: what the decision was about, which plan/task it arose in>

## Why this matters
<1-3 sentences: what the outcome depends on, why the axis is relevant>
```

Rules:
- `axes` must be a subset of entries declared in `decisions/axes.md`; undeclared axes are rejected by `_lib_decision_capture.sh`.
- `duong_pick` is one of: `a`, `b`, `c`, or `hands-off-autodecide`.
- `coordinator_pick` is one of: `a`, `b`, `c`. Always present (the coordinator's recommendation, public).
- `coordinator_autodecided: true` only when Duong is in hands-off mode and the coordinator made the decision unilaterally.
- `confidence` is one of: `low`, `medium`, `high` (three-bucket subjective rating, informed by `preferences.md` sample sizes).

### §3.2 `preferences.md` — schema

Location: `agents/<coordinator>/memory/decisions/preferences.md`

One `## Axis: <axis-name>` section per declared axis. Each section contains:

```markdown
## Axis: scope-vs-debt

Samples: 17 (a: 12, b: 3, c: 2; +4 hands-off)
Match rate: 71%
Confidence: medium

Summary:
<Hand-curated prose — preserved verbatim across rollups. Only Samples/Match rate/Confidence/Notable misses lines are regenerated.>

Notable misses:
- 2026-04-21: predicted b, Duong picked a (scope was more important than expected given deadline)
```

Rollup idempotency: running `rollup_preferences_counts` twice on a clean tree produces byte-identical output. Only the four machine-managed lines (`Samples:`, `Match rate:`, `Confidence:`, `Notable misses:`) are regenerated; all `Summary:` prose is preserved.

### §3.3 `INDEX.md` — schema

Location: `agents/<coordinator>/memory/decisions/INDEX.md`

Auto-generated. One markdown table row per log file, sorted newest-first:

| Date | Slug | Axes | Duong pick | Match |
|---|---|---|---|---|
| 2026-04-21 | scope-over-deadline | scope-vs-debt | a | yes |

`Match` = `yes` if `duong_pick == coordinator_pick`, `no` otherwise, `n/a` if `coordinator_autodecided: true`.

Not eager-loaded at boot. Pulled on demand by Skarner or the coordinator when calibrating a new decision.

### §3.4 `axes.md` — schema

Location: `agents/<coordinator>/memory/decisions/axes.md`

Append-only. One section per axis:

```markdown
## scope-vs-debt
introduced: 2026-04-01
description: Whether to prioritize clean scope delivery or reduce existing debt.
options:
  a: cleanest scope, defers debt
  b: balanced — address one debt item inline
  c: debt-first, delays scope
deprecated: null   # or ISO date when retired
```

Retention rule: a deprecated axis section is never deleted — it remains in `axes.md` with `deprecated: <date>`. Historical log files tagging it are valid; new log files tagging a deprecated axis are rejected.

### §3.5 Dashboard schema-bind points

`decisions/INDEX.md` columns are a bind contract. Downstream consumers (scripts, dashboard) read the table header as authoritative. Column names may not be renamed without a version bump in this document and a migration plan.

Display enum for `confidence` column: `low | medium | high | n/a` (four buckets including n/a for hands-off).

---

## §4–§5 — Capture flow

### §4 Capture mechanism

Four moving parts:

1. **`scripts/_lib_decision_capture.sh`** (sourced-only) — exports `capture_decision_row`, `render_index_row`, `regenerate_decisions_index`, `rollup_preferences_counts`. Axis validation runs here; unknown axes exit non-zero.

2. **`scripts/capture-decision.sh`** — thin wrapper. Usage: `scripts/capture-decision.sh <coordinator> --file <log-file>`. Validates, writes to `decisions/log/`, and exits non-zero if `log/` is not bootstrapped.

3. **`scripts/memory-consolidate.sh <coordinator> --decisions-only`** — runs only the decision INDEX regen + preferences rollup. No archive move, no sessions fold, no commit.

4. **`decision-capture` skill** (`disable-model-invocation: true`) — thin wrapper over `scripts/capture-decision.sh`. The coordinator writes the full decision log file inline and invokes the skill, which validates and writes to the correct path. Stdout = final path.

### §5 Skill integration

**`/end-session` Step 6c** (coordinators only, runs after Step 6b):
1. Invoke `bash scripts/memory-consolidate.sh <coordinator> --decisions-only`.
2. Stage `decisions/INDEX.md` and `decisions/preferences.md`.
3. Edit `## Axis:` `Summary:` prose if this session's decisions warrant it.
4. Stage `decisions/axes.md` only if modified.

Step 6c ordering: MUST run after Step 6 (shard write, so `decision_source` refs are valid) and before Step 9 (commit, so all artifacts land atomically).

**`/pre-compact-save`** delegates to Lissandra, which runs Step 6c identically. See `architecture/agent-network-v1/compact-workflow.md`.

Non-coordinator agents (`/end-subagent-session`): Step 6c is a no-op.

---

## §7 — Retrieval patterns

### §7.1 Per-question axis lookup (synchronous, in-coordinator)

When the coordinator formulates a new decision question, it reads `decisions/preferences.md` (already boot-loaded, §6.1) and checks the match rate and Notable misses for the tagged axes. This is a direct read — no subagent needed.

### §7.2 Per-axis deep-dive (Skarner delegation)

When the coordinator wants historical examples for an axis (e.g. "how often does Duong pick 'b' on scope-vs-debt when there's a deadline?"), it dispatches Skarner to grep `decisions/log/` by axis tag and return file paths + excerpts.

### §7.3 Cross-coordinator or full-corpus search (also Skarner)

Skarner can search both `agents/evelynn/memory/decisions/` and `agents/sona/memory/decisions/` when the question spans concerns. Subagents MUST NOT do this eagerly.

### §7.4 NOT eager-loaded: the lazy surfaces

`decisions/INDEX.md` and individual `log/*.md` files are NOT loaded at boot. They are lazy surfaces — too high-churn and too large for every session to absorb. Only `preferences.md` and `axes.md` are boot-loaded (slow-churn, small).

---

## §8 — Calibration loop

### §8.1 Per-session fold (every `/end-session`)

Step 6c's rollup regenerates `preferences.md` sample counts and match rates from the `log/` corpus. Over time, high-sample axes produce `confidence: high` ratings; low-sample axes produce `confidence: low`. The coordinator uses confidence ratings to weight its `Predict:` line in new decisions.

### §8.2 Narrative summary update (coordinator judgement, weekly-ish)

The hand-curated `Summary:` prose in `preferences.md` is updated by the coordinator when it has enough signal to characterize an axis's pattern. Rollup never touches this prose — it is preserved byte-identical across regenerations.

### §8.3 Axis introduction/retirement (coordinator + Duong approval)

New axes are added to `axes.md` only after explicit discussion with Duong. Retired axes are marked `deprecated: <date>` (never deleted). The coordinator proposes axis changes; Duong approves (implicit or explicit per standard decision flow).

### §8.4 Overfit prevention

`preferences.md` carries `Notable misses:` entries — cases where the coordinator's prediction was wrong. These are kept and reviewed periodically (§8.2). A match rate of 100% on a high-sample axis is a signal to review — may indicate the coordinator has stopped predicting and started echoing.

### §8.5 Cold-start

On first use, `preferences.md` contains no `Samples:` data (all zero) and `Confidence: low` on all axes. The first 5–10 decisions on each axis build calibration signal. Coordinators should treat early predictions as low-confidence guesses and label them accordingly.

---

## §9 — Integration with coordinator memory and memory-flow-simplification

The `decisions/` subtree sits inside `agents/<coordinator>/memory/` alongside `last-sessions/`, `open-threads.md`, and `evelynn.md`/`sona.md`. It follows the same two-layer boot design described in `architecture/agent-network-v1/coordinator-memory.md`:

- **Eager surfaces** (boot-loaded): `preferences.md`, `axes.md` — slow churn, small, always relevant.
- **Lazy surfaces** (on-demand): `log/*.md`, `INDEX.md` — high churn, large, pulled only when calibrating a specific decision.

Subagents MUST NOT eagerly load another coordinator's `decisions/`. Cross-coordinator decision search is routed through Skarner.

The memory-flow-simplification plan (`plans/in-progress/personal/...`) governs the fold cadence for `last-sessions/` shards. Decision log files are independent of the shard fold — they are written once, never archived (except as deprecated-axis retention per §3.4).

---

## §10.5 — v2 auto-decide gating plan (out of scope, documented)

v2 would allow the coordinator to skip the Duong decision step when `confidence: high` AND `match_rate > 80%` AND `coordinator_autodecided: true` mode is active (`coordinator_autodecided_enabled: true` in coordinator config). This gate is:

- **Not implemented in v1.** The current system always presents decisions to Duong.
- **Data-collected in v1:** every `coordinator_autodecided: true` entry from hands-off mode is stored separately in `preferences.md` (`+N hands-off` parenthetical per §3.2), preserving honest match-rate numbers against explicit picks.
- **Gated on:** explicit Duong opt-in to the mode flag + Lux review of at least 20 explicit-pick samples per axis (minimum calibration floor).

See `plans/approved/personal/2026-04-21-coordinator-decision-feedback.md` §10.5 for the full gating criteria.

---

## Cross-references

- `architecture/agent-network-v1/coordinator-memory.md` — two-layer boot design
- `architecture/agent-network-v1/compact-workflow.md` — pre-compact-save + Lissandra protocol
- `plans/approved/personal/2026-04-21-coordinator-decision-feedback.md` — source ADR
- `agents/evelynn/CLAUDE.md` §Startup Sequence — Evelynn's boot order (steps 8–9: preferences + axes)
- `agents/sona/CLAUDE.md` §Startup Sequence — Sona's boot order (steps 8–9: preferences + axes)
- `.claude/skills/decision-capture/SKILL.md` — on-demand write primitive
