---
name: feedback-consolidate
description: Weekly Sunday consolidation — Lux categorizes open feedback entries (graduate/keep-open/stale), Karma drafts action stubs for graduated entries, Evelynn commits the digest to assessments/feedback-digests/. Runs as an extra dispatch block inside the Sunday daily-agent-repo-audit routine. Token budget ~50k in / ~12k out.
disable-model-invocation: false
---

# /feedback-consolidate — Weekly Feedback Consolidation

## When to use

- Sunday weekly run, dispatched from the daily-agent-repo-audit routine (§D7 of the feedback-system ADR).
- Ad-hoc: when Duong explicitly requests a mid-week rollup.

## When NOT to use

- Daily runs — the signal volume is too low for useful cluster analysis.
- As a replacement for `/agent-feedback` (the write-primitive skill). This skill reads and triages; `/agent-feedback` writes.

## Invariant 7 (enforced)

This skill writes ONLY to `assessments/feedback-digests/**`. It NEVER mutates `feedback/*.md` bodies. Permitted frontmatter mutation: `state:` field only (set to `graduated`, `stale`, or `keep-open`) and `graduated_to:` field (set when a graduated entry produces a plan stub). All other feedback file fields are read-only to this skill.

## Arguments

`$ARGUMENTS` (optional): ISO date string `YYYY-MM-DD` to override the digest date (defaults to today). Useful for backdated runs.

---

## Protocol

### Step 1 — Gather open entries

Read `feedback/INDEX.md`. Collect all entries where `state:` is absent or `open`. If INDEX is stale or missing, fall back to `ls feedback/*.md` and parse frontmatter directly.

Compute:
- `feedback_window`: `<oldest-entry-date>..<newest-entry-date>` from the collected set.
- `entries_processed`: count of files scanned.

### Step 2 — Dispatch Lux (categorize + dedupe)

Spawn Lux via the Agent tool with the following prompt shape:

```
[concern: personal]

Categorize these open feedback entries for the weekly digest.

Entries (file paths):
<list of feedback/*.md paths>

For each entry, assign one verdict:
- graduate: worth a candidate ADR (recurring pain, actionable, high or medium severity)
- keep-open: valid friction, not yet actionable (low frequency, low severity, or waiting on a prior plan)
- stale: superseded, resolved, or no longer reproducible

Deduplication rule: entries sharing ≥3 non-stopword tokens AND same category → cluster under the highest-severity head; satellites get verdict "stale (clustered under <head-slug>)".

Return:
- A markdown table: slug | verdict | reason (one line)
- A cluster analysis table: category | count | high | medium | low
- For each "graduate" entry: a 2-paragraph problem+solution draft (problem ≤150 words, solution ≤150 words) + proposed owner role.

Token budget: ~30k in / ~8k out.
```

Wait for Lux's structured return before proceeding.

### Step 3 — Dispatch Karma (triage graduated entries)

For each entry Lux marked `graduate`, spawn Karma via the Agent tool:

```
[concern: personal]

Triage this graduated feedback entry into an action stub.

Feedback file: <path>
Lux verdict: graduate
Lux problem draft: <paste>
Lux solution draft: <paste>

Produce:
- One-paragraph problem statement (plain language, no jargon)
- One-paragraph candidate solution (concrete first step, ≤2 follow-up steps)
- Proposed owner (role name from the agent roster, not a specific agent)
- Estimated complexity: quick | normal | complex

This stub will be reviewed by Evelynn and Duong before becoming a proposed plan.

Token budget: ~5k in / ~2k out.
```

Collect all Karma stubs before proceeding.

### Step 4 — Compose digest

Write `assessments/feedback-digests/<YYYY-MM-DD>.md` using the following schema exactly:

```markdown
---
date: <YYYY-MM-DD>
run_id: <routine-execution-id or "manual-<timestamp>" for ad-hoc>
feedback_window: <oldest>..<newest>
entries_processed: <N>
entries_graduated: <N>
entries_kept_open: <N>
entries_marked_stale: <N>
---

# Feedback digest — week of <feedback_window>

## Graduated (candidate ADRs)

### <N>. <Title> (<M> entries clustered)
- **Source feedback:** `feedback/<slug>.md`[, ...]
- **Problem:** <Karma's problem paragraph>
- **Candidate solution:** <Karma's solution paragraph>
- **Proposed owner:** <role>
- **Estimated complexity:** <quick|normal|complex>

## Kept open (not yet actionable)

- `feedback/<slug>.md` — <one-line reason>

## Marked stale (archived this run)

- `feedback/<slug>.md` — <one-line reason>

## Cluster analysis (Lux)

| Category | Count | High | Medium | Low |
|---|---|---|---|---|
| <category> | <N> | <H> | <M> | <L> |

## Raw sources
- `feedback/INDEX.md` snapshot at digest time: (INDEX sha256 or "INDEX not available")
- Entries processed: (list of filenames, one per line)
```

### Step 5 — Mutate feedback frontmatter

For each entry in the collected set:
- Set `state: graduated` if Lux verdict = graduate. Also set `graduated_to: assessments/feedback-digests/<date>.md#graduated`.
- Set `state: stale` if Lux verdict = stale. Move the file to `feedback/archived/<slug>.md` via `git mv`.
- Set `state: keep-open` if Lux verdict = keep-open.

Stage all mutated files:
```
git add feedback/*.md feedback/archived/*.md assessments/feedback-digests/<date>.md
```

### Step 6 — Regenerate INDEX

```
bash scripts/feedback-index.sh
git add feedback/INDEX.md
```

### Step 7 — Commit

```
chore: feedback digest <YYYY-MM-DD> — <N> graduated, <N> kept-open, <N> stale
```

Include in commit body:
- `Digest: assessments/feedback-digests/<date>.md`
- One line per graduated entry: `  graduate: feedback/<slug>.md → <title>`

Push. On pre-push rejection: stop, do not retry, report verbatim.

### Step 8 — Report

Return to coordinator:
- Digest path
- Commit SHA
- Summary line: `<N> graduated | <N> kept-open | <N> stale`
- List of graduated entries with proposed owners

---

## Failure modes

- **Lux unavailable or returns malformed table** — abort, do not write partial digest. Report to Evelynn.
- **Karma fails on a graduated entry** — write digest with that entry's stub marked `(Karma stub unavailable — manual triage needed)`. Do not block the commit.
- **INDEX stale** — fall back to direct file scan; note "INDEX fallback" in the digest `## Raw sources` section.
- **No open entries** — write a minimal digest with all counts = 0. Still commit (audit trail matters).

---

## Related

- Write primitive: `.claude/skills/agent-feedback/SKILL.md`
- Feedback schema: `plans/approved/personal/2026-04-21-agent-feedback-system.md` §D1
- Sunday audit integration: `plans/approved/personal/2026-04-21-agent-feedback-system.md` §D7
- Output directory: `assessments/feedback-digests/`
