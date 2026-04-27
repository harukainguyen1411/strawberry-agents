---
name: decision-capture
disable-model-invocation: true
description: >
  Capture a coordinator decision log file. Validates YAML frontmatter,
  writes to the correct decisions/log/ path, git-adds. Stdout: final path.
  Argument: coordinator name. Reads prepared decision markdown from a file path.
---

# Decision Capture Skill

This skill wraps `scripts/capture-decision.sh`. Invoke when a coordinator needs to
persist a decision log file after Duong has answered an a/b/c question.

## Usage

```
bash scripts/capture-decision.sh <coordinator> --file <path-to-prepared-log.md>
```

- `<coordinator>` — `evelynn` or `sona`
- `--file <path>` — path to a temp file containing the full decision markdown (YAML frontmatter + ## Context + ## Why this matters)

On success: stdout emits the final path (`agents/<coordinator>/memory/decisions/log/<date>-<slug>.md`).
On failure: stderr emits `[capture-decision] BLOCK: <reason>`. Exit non-zero.

## Invariant

`decisions/log/` MUST exist before invoking this skill. If it does not exist, the script exits with
`[capture-decision] BLOCK: decisions/log/ does not exist`. Bootstrap via T8 before first use.

## Retry rule

Per §6.2: on validation failure, repair the frontmatter and retry once. If a second failure, surface
to Duong as a capture gap and proceed without the log — never block the decision.

## DB write — decisions table projection

After the markdown shard is written and git-added, `capture-decision.sh` inserts a row into the `decisions` table. Default DB path: `~/.strawberry-state/state.db`; override via `STRAWBERRY_STATE_DB` env var (ADR §D2).

The write is non-fatal: if the DB is unreachable or `_lib_db.sh` is absent, a warning is emitted to stderr and the skill continues. Markdown shard is source of truth.

Idempotent: `INSERT OR IGNORE` on `UNIQUE(coordinator, slug, decided_at)` — re-running the skill on the same `decision_id` and date does not produce a constraint failure.

## STRAWBERRY_MEMORY_ROOT shim

When `STRAWBERRY_MEMORY_ROOT` is set, coordinator memory is resolved under that root instead of the
repo's `agents/` tree. Used by integration tests; do not set in production.

## Schema reference

Decision log frontmatter (required fields):

```yaml
---
decision_id: YYYY-MM-DD-<slug>        # = filename stem
date: YYYY-MM-DD
session_short_uuid: <uuid>
coordinator: evelynn|sona
axes: [axis-slug-one, axis-slug-two]  # YAML list, one or more axes from axes.md
question: "Full decision question text"
options:
  - letter: a
    description: "Cleanest option"
  - letter: b
    description: "Balanced option"
  - letter: c
    description: "Quickest with debt"
coordinator_pick: a|b|c
coordinator_confidence: low|medium|medium-high|high
coordinator_rationale: "One-sentence why"
duong_pick: a|b|c|hands-off-autodecide
duong_concurred_silently: false|true
coordinator_autodecided: false|true
match: true|false|hands-off
decision_source: /end-session-shard-<uuid>
---
## Context
<2-3 sentences on the decision context>

## Why this matters
<1-2 sentences on the significance>
```

Bind-contract fields (dashboard reads these — renaming or removing is a breaking change):
- `axes` (YAML list)
- `match` (boolean or "hands-off")
- `coordinator_confidence` (enum: low|medium|medium-high|high)
- `decision_id` (string = filename stem)
