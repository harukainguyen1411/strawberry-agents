# PR #26 — cross-repo-workflow three-gate tautology cleanup

**Date:** 2026-04-22
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/26
**Branch:** `fix/cross-repo-workflow-three-gate-tautology`
**Verdict:** approve

## Context

Post-merge advisory from PR #24 (Rule-18 amendment) flagged that
`architecture/cross-repo-workflow.md` had re-introduced a three-gate list —
(a) checks green, (b) non-author approval, (c) no branch-protection bypass —
where (c) was just a restatement of the sentence opener ("agents must not use
`--admin` or any branch-protection bypass"). My own previous learning
(`2026-04-22-pr24-rule18-rereview.md` line 23) had noted it as "safe to leave or
clean up later." PR #26 is the cleanup.

## What I checked

1. **Diff scope** — 3+/3−, single file, docs-only. Surgical.
2. **Grammar / connective switch** — Oxford-comma list → plain conjunction.
   Reads clean.
3. **Alignment with CLAUDE.md rule 18** — rule 18 itself is two gates (a)/(b).
   This doc now mirrors it. No drift.
4. **Dangling `(c)` / three-gate sweep across repo:**
   - Live architecture docs: none remain.
   - `plans/pre-orianna/proposed/2026-04-17-branch-protection-enforcement.md:155`
     — historical pre-orianna plan, immutable archive. Leave.
   - `agents/evelynn/transcripts/*` — multiple hits, historical session logs.
     Correctly not touched.
   - `plans/in-progress/personal/2026-04-22-rule-18-self-merge-amendment.md`
     — active amendment plan, already two-gate framed. Consistent.
   - My own prior learning note flagging this PR's pre-state — not a live
     contradiction, this PR is the cleanup.

## Lane discipline

Posted via `scripts/reviewer-auth.sh --lane senna`. Preflight returned
`strawberry-reviewers-2` as expected. After submission, PR shows two APPROVED
reviews from distinct authors (`strawberry-reviewers` = Lucian,
`strawberry-reviewers-2` = Senna), confirming the dual-lane separation is
working — no review-slot collapse.

## Takeaway

Post-merge advisories that flag "safe to clean up later" doc redundancies
eventually do come back as small follow-up PRs. Worth reviewing quickly — they
surface exactly where the canonical invariant doc (CLAUDE.md) and the
day-to-day reference doc (`architecture/*.md`) drift, and catch them before
the next reader is confused by "which list is authoritative?" The answer is
always CLAUDE.md; the architecture doc should mirror it, not extend it with
enumerated restatements.
