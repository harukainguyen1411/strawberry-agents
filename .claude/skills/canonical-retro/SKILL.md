---
name: canonical-retro
description: Saturday weekend retro for the canonical-vN lock. Evelynn invokes this skill at 09:00 Asia/Bangkok every Saturday during a lock-week. The skill dispatches Lux (rule-quality grading), Karma (test-plan + impl pulse), and Swain (architecture-impact ADR authoring) over the past week's events.jsonl slice, the open feedback/INDEX.md entries, and the bypass log. Output is a Swain-authored canonical-v(N+1)-rationale.md ADR draft in plans/proposed/personal/.
disable-model-invocation: false
allowed-tools: Bash Read Write Edit Glob Grep Agent
---

# /canonical-retro — weekend lock retro

You are Evelynn (or a coordinator with equivalent authority). This skill is the Saturday cadence for the active canonical-vN lock — review the bypass log, the dashboard's lock-violation surface, and the week's feedback, then dispatch Swain to draft the next-version rationale ADR. Lux and Karma feed Swain in parallel.

The skill is read-only on the lock manifest itself. It does not move the lock-tag — that happens when the rationale ADR is approved and Phase-N+1 ships.

## Argument

`$ARGUMENTS` may be a target ISO week (`YYYY-Www`), or empty for the current week. Use `date -u +%G-W%V` if empty.

## Step 0 — Pre-flight

Read these in a single batch via the Read/Glob tools:

- `architecture/canonical-v1.md` — the active manifest (verify exists; refuse with `canonical-retro: lock manifest missing — run T.COORD.3 first` otherwise).
- `architecture/canonical-v1-bypasses.md` — bypass log; collect rows whose `date` is in `$WEEK`.
- `feedback/INDEX.md` — feedback entries open as of the week's Friday cutoff.
- The week's `events.jsonl` slice from `tools/retro/dist/events-$WEEK.jsonl` if produced by Phase-2 ingest; otherwise note its absence and proceed without.

If `architecture/canonical-v1.md` is absent, abort. If the bypass log is absent, abort. The other inputs are advisory — proceed if missing but flag in the dispatch prompt.

## Step 1 — Dispatch chain

Spawn three teammates (or background agents, per the active dispatch mandate) into a fresh team `canonical-retro-$WEEK`. Send them in parallel; collect their outputs before Swain authors.

### Lux — rule-quality grading

```
[concern: personal][project: agent-network-v1]

Grade the lock-set rules in CLAUDE.md (rules 1–N) and the agent-def + _shared/ corpus enumerated in architecture/canonical-v1.md against the past week's events.jsonl signal at tools/retro/dist/events-$WEEK.jsonl.

For each rule, emit: (a) trigger count, (b) bypass count, (c) violation count, (d) one-line judgement (keep / revise / retire).

Output: assessments/canonical-retro/$WEEK-lux-rule-grades.md. SendMessage me with the file path when done.
```

### Karma — test-plan + impl pulse

```
[concern: personal][project: agent-network-v1]

Sweep the past week's plan-promotions, PR merges, and xfail flips in events-$WEEK.jsonl. Identify any cross-plan test-coverage gaps that the lock would have prevented if it had been more restrictive (or missed because it was over-restrictive).

Output: assessments/canonical-retro/$WEEK-karma-test-pulse.md. SendMessage me with the file path when done.
```

### Swain — architecture-impact ADR (gated on Lux + Karma)

After both peers report, dispatch Swain:

```
[concern: personal][project: agent-network-v1]

Author plans/proposed/personal/$DATE-canonical-v$NEXT-rationale.md — the rationale ADR for advancing the lock from v$CURR to v$NEXT.

Read inputs in this order:
1. architecture/canonical-v1.md (active manifest)
2. architecture/canonical-v1-bypasses.md (week's bypass rows)
3. assessments/canonical-retro/$WEEK-lux-rule-grades.md
4. assessments/canonical-retro/$WEEK-karma-test-pulse.md
5. feedback/INDEX.md (open entries, Friday-cutoff)

Output sections (template — keep ≤200 lines):
- ## Context (what changed in $WEEK)
- ## Bypass roll-up (severities, reconciliation status)
- ## Rule grade summary (Lux's keep/revise/retire calls — consolidated)
- ## Proposed v$NEXT changes (path additions/removals/SHAs to refresh)
- ## Migration cost (paths churned, blast radius)
- ## Decision (advance / hold / amend-in-place)

Frontmatter: tags include canonical-vN, retro, lock-advance. Owner: Swain. Stage: proposed.

When done, SendMessage me with the rationale path. Do NOT promote it past proposed/ — that's Orianna's job after Duong reviews.
```

## Step 2 — Reconcile bypass log

For every bypass log row whose `sha` is cited in the Swain ADR's "Bypass roll-up" section, set its `reconciled-by` cell to the ADR's filename. Use Edit tool, one row at a time. Commit:

```
chore: T.COORD.4 — canonical-retro $WEEK reconciliation
```

Direct to main (plan-state edit, no PR review needed).

## Step 3 — Brief Duong

SendMessage to the coordinator-of-record (Duong via the active session) summarizing:

- Number of bypasses reconciled.
- Swain's `## Decision` line (advance / hold / amend-in-place).
- Path to the rationale ADR.
- Any Lux/Karma findings flagged `severity: high`.

Hand off — Duong reviews the ADR and decides whether to dispatch Orianna for promotion to `approved/`. The skill exits here; lock-tag advancement (`canonical-v2` annotated tag) happens when Phase-(N+1) ships.

## Failure modes

- Manifest missing → abort, surface T.COORD.3 prereq.
- Bypass log missing → abort, surface canonical-v$CURR setup gap.
- Swain output missing required sections → re-dispatch once with explicit re-spec, then surface to Duong if still incomplete.
- Lux or Karma silent for >30min → proceed with Swain-only dispatch and note the missing inputs in the rationale ADR's "Context" section.

## When to invoke

Saturday 09:00 Asia/Bangkok during any active lock-week. The Phase-3 dashboard's stale-banner threshold (>14 days since last retro per TP3.T3) is the upstream nudge; the skill itself is idempotent within a week — re-running for the same `$WEEK` overwrites the assessments and updates the bypass log reconciliation rows in place.
