# Dual-reviewer discipline — always dispatch Senna+Lucian in parallel, never Senna alone

**Date:** 2026-04-24
**Severity:** medium
**Session:** 84b7ba50 (post-compact round 4)

## What happened

Four consecutive work PRs (#114, #115, #116, #117) were dispatched for review with Senna only. Lucian was not included. Duong flagged the slip. The pattern: when moving fast through a wave of similar PRs (load_dotenv hygiene, deploy hardening), the dispatch prompt was drafted for one reviewer and not duplicated.

## Root cause

No structural enforcement on the dispatch side. The reviewer flow in `agents/sona/CLAUDE.md` says "Dispatch Senna / Lucian" but there is no checklist or template that enforces both per dispatch turn.

## Standing rule

Every work-repo PR dispatch to reviewers must include both Senna AND Lucian in the same turn. The only exception is a PR where one reviewer has already returned a verdict and the re-dispatch is specifically a second-pass for the other. "Senna first, Lucian after Senna returns" is wrong — they must run in parallel.

If the PR is trivial and Duong explicitly says one reviewer is sufficient, note the exception in open-threads.

## Codification needed

Evelynn inbox'd to add an explicit enforcement note to `agents/sona/CLAUDE.md` reviewer section: "Both Senna AND Lucian must be dispatched in the same turn for every work-repo PR review."
