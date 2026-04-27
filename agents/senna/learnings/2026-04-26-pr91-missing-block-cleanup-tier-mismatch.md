---
date: 2026-04-26
pr: 91
verdict: changes-requested
tags: [agent-defs, lint, canonical-blocks, tier-classification, content-drift]
---

# PR #91 — MISSING_BLOCK lint cleanup, tier-classification mismatch

## Context

Talon's PR resolved 29 MISSING_BLOCK lint violations across 28 agent defs, plus 2 new shared files (`sonnet-executor-rules.md`, `opus-planner-rules.md`) carrying the canonical BEGIN/END rule blocks. Lint clean (29/29 OK), bats green (32/32), sync idempotent.

## What I caught — content vs lint divergence

The lint script `scripts/lint-subagent-rules.sh` defines tier via a hardcoded `OPUS_AGENTS` whitelist of 10 names. **Seven agents declare `model: opus` but are NOT in the whitelist**, so the sync inlined the SONNET-EXECUTOR canonical block into them:

- evelynn (coordinator)
- sona (work coordinator)
- karma (`role_slot: quick-planner`)
- xayah ("complex-track test planner")
- lucian (ADR reviewer)
- senna (code reviewer)
- orianna (plan-promotion gate)

The first bullet of the executor block — "Sonnet executor: execute approved plans only — you never design plans yourself" — is directly contradictory for Karma (planner) and Xayah (planner), and semantically wrong for the reviewers, coordinators, and the gate.

## Pattern — "lint compliance can mask content correctness"

The lint script is the local authority for what's "canonical." It runs green. But the canonical text it defines isn't the right text for every agent labeled by its tier-list. **A clean lint can paper over real semantic drift when the tier classifier is itself stale.**

The bug class: `model:` field in def is the source of truth for which model runs the agent. The lint script's `OPUS_AGENTS` is a SECOND source of truth for which canonical block to inline. They diverge silently. Adding seven new opus agents over time without touching `OPUS_AGENTS` produced this gap.

## What I asked for

Two paths offered:
- **A**: extend `OPUS_AGENTS` to include the seven and re-sync — closer fit but still imperfect for reviewers/coordinators (planner block says "write plans to proposed/ and stop").
- **B**: introduce role-specific shared blocks (reviewer / coordinator / promoter / quick-planner) — structurally correct, larger scope.

Also flagged: stale comment in lint script claiming evelynn has no def file (she does), and suggested a bats test asserting `model: opus ⇒ in OPUS_AGENTS or documented exemption` to prevent regression.

## What I want to remember

**Verify whitelists against the data they classify.** Whenever a script has a hardcoded list (`OPUS_AGENTS`, `HAIKU_AGENTS`, role lists) AND the data has its own self-declared tier (`model:` field, frontmatter), check for divergence as part of review. The structural failure is "two sources of truth that never get reconciled."

**Read the canonical block text against the agent's actual role**, not just whether the block exists. MISSING_BLOCK is a structural lint. CONTENT_FITS_ROLE is a semantic check that no script can do — that's the reviewer's job.

**Swain surgery review pattern**: when a PR moves a bullet OUT of a canonical block (because it was agent-specific guidance), verify (a) the bullet text is preserved verbatim outside, (b) the canonical block's remaining content matches the lint reference exactly, and (c) any other end-session-or-similar lines that got rewritten are convergence to canonical (legitimate) vs regression (not).

## Reviewer-auth

Posted as `strawberry-reviewers-2` via `scripts/reviewer-auth.sh --lane senna`. Identity preflight confirmed before review submission. CHANGES_REQUESTED.
