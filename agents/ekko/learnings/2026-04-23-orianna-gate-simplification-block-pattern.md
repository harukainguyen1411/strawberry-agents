# Orianna gate — prospective path suppressor discipline in meta-plans

Date: 2026-04-23
Topic: orianna gate block on plans that describe the gate itself

## What happened

Attempted to promote `plans/proposed/personal/2026-04-22-orianna-gate-simplification.md` (a plan that *redesigns the Orianna gate itself*). The gate returned 16 block findings, all in the same category: prospective or hypothetical file paths cited in the plan body without `<!-- orianna: ok -->` inline markers.

## Pattern

Plans that talk *about* the gate infra (or any file-creation plan) are especially prone to this class of block. The plan already had some correct `<!-- orianna: ok -->` markers, but missed:

1. Repeated citations of the same prospective path on different lines — each occurrence needs its own marker
2. Glob patterns with `/**` (e.g. `plans/proposed/**`) — either add a marker or rewrite to a bare directory citation
3. Hypothetical example paths used to explain logic (e.g. `plans/{proposed,approved}/personal/{foo,bar}.md`) — must be suppressed even if clearly illustrative

## Lesson

When authoring a plan that creates new files/scripts, add `<!-- orianna: ok -->` on **every line** that mentions a prospective path — not just the first occurrence. A single missed occurrence blocks the whole sign.

## Remediation path for this specific plan

Lines flagged (approx): 28, 39, 55, 62, 63, 64, 66, 91, 93, 96. Add `<!-- orianna: ok -->` to each, or rephrase glob patterns as bare directory references. Re-run:

```
bash scripts/orianna-sign.sh plans/proposed/personal/2026-04-22-orianna-gate-simplification.md approved
bash scripts/plan-promote.sh plans/proposed/personal/2026-04-22-orianna-gate-simplification.md approved
```
