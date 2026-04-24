# Archive Repo PR Viability Check

**Date:** 2026-04-24
**Triggered by:** PR #187 opened on `Duongntd/strawberry`, closed unmerged — billing-blocked CI, no reviewer-auth token scope.

## Lesson

Before opening a PR on any repo outside the primary `harukainguyen1411/strawberry-agents` / `harukainguyen1411/strawberry-app` pair, verify:

1. **CI is not billing-blocked** — check GitHub Actions status / spending limit; a billing block produces empty logs with 1-2s runtimes on every check.
2. **reviewer-auth token has scope on this repo** — `scripts/reviewer-auth.sh` PATs are scoped to specific repos; `strawberry-reviewers` / `strawberry-reviewers-2` do not automatically have access to archive repos.
3. **The repo is the correct target** — archive / sibling repos (e.g. `Duongntd/strawberry`) are read-only territory unless Duong has explicitly activated them for agent work.

If any check fails: close the PR immediately, migrate the work to the correct primary repo, and open there.

## Incident summary

Talon opened PR #187 on `Duongntd/strawberry` (now an archive of the old MCP source). Lucian attempted to review and surfaced the structural routing problem: billing-blocked CI (no check runs), no reviewer-auth token scope. The correct resolution — close PR, fold fix into strawberry-agents PR — was immediate once identified. Senna's review abort was clean. No work was lost; only review-cycle time.

## Application

Embed repo-viability check in any delegation that involves opening a PR outside the primary pair. Quick three-point checklist: CI live? Reviewer-auth scoped? Is this the right repo?

| last_used: 2026-04-24
