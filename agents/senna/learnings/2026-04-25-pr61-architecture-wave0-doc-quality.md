# PR #61 — Architecture Wave 0 doc-quality review (APPROVE)

**Date:** 2026-04-25
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/61
**Branch:** architecture-consolidation-wave-0
**Commit reviewed:** f37af0bd
**Verdict:** APPROVE with non-blocking nits

## Scope reminder
Doc-only refactor, `tests_required: false`. My code-quality lane reduces to doc-quality:
ambiguity, contradictions, actionability of policy text. ADR/plan fidelity is Lucian's
lane — I deliberately stayed out of "does the wording match Swain's plan verbatim".

## Top findings

1. **§7.1/§7.2 recursion ambiguity (Important).** "MUST land directly under
   `architecture/agent-network-v1/`" plus "if it's in `architecture/agent-network-v1/`,
   it's law" — "directly" reads as forbidding subfolders, but `archive/v1-orianna-gate/`
   shows nesting is a precedent elsewhere. Pick one: explicit recursion or explicit flat
   layout.
2. **Lock-Bypass trailer underspecified (Important).** "measurement-week" undefined inside
   the agent-network-v1 README; no link to the cornerstone canonical-v1 plan; enforcement
   mechanism unstated. A future agent reading only this README cannot determine
   (a) whether the window is currently active, (b) whether the trailer is hook-enforced.
3. **§7.1 should mention `agents/memory/agent-network.md` carve-out (Suggestion).** The
   dual-source split (protocol vs live roster) is only resolved at the bottom of the
   agent-network-v1 README. A §7.1-only reader would conclude all agent-network truth
   lives under `agent-network-v1/`.
4. **§5.4 `<canonical-path>` path-base unstated (Suggestion).** Plan W3 DoDs use
   repo-root-relative paths; archive README should say so explicitly.

## What was solid
- §7.2 four-bullet decision tree is actionable for future doc authors.
- Cross-references between the four READMEs are consistent — no contradictions.
- Placeholder markers (`[placeholder — lands W{1,2,3}]`) are uniform and map to plan §9.
- §5.4 archive-marker contract handles both the canonical-replacement and
  no-canonical-replacement cases — verified against W3 task DoDs.
- Wave 0 stayed in its lane: `.gitkeep` + READMEs only, no content moves.

## Reviewer-auth notes
- Personal concern → `scripts/reviewer-auth.sh --lane senna gh pr review ...`.
- Preflight `gh api user --jq .login` returned `strawberry-reviewers-2`. Good.
- Submission landed under `strawberry-reviewers-2` against commit `f37af0bd`.
  Confirmed via `gh pr view 61 --json reviews` post-submission.

## Pattern worth carrying forward
For doc-only PRs where the policy text will be cited by future agents months later, the
useful test is "can a reader who lands on this section alone, with no other context,
make the right call?" That framing produced findings #1 (recursion) and #3 (carve-out)
that pure copy-edit reviewing would have missed.
