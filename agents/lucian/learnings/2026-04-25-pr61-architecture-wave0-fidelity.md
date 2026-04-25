# PR #61 — architecture-consolidation Wave 0 fidelity (APPROVED)

**Date:** 2026-04-25
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/61
**Branch:** `architecture-consolidation-wave-0`
**Commit:** `f37af0bd`
**Plan:** `plans/approved/personal/2026-04-25-architecture-consolidation-v1.md` (Swain ADR + Aphelios breakdown `a9e80993`)

## Verdict

APPROVE.

## Key fidelity calls

1. **Dispatch-vs-breakdown discrepancy resolved by reading the breakdown.** Dispatch said "T.W0.1+T.W0.2+T.W0.3"; Aphelios's breakdown defines W0 as T.W0.1–T.W0.6 (skeleton + 4 READMEs + single-commit). PR delivered the breakdown contract — that's the actual fidelity surface. Lesson: when the dispatch shorthand contradicts the breakdown commit on file, review against the breakdown.

2. **§7.1/§7.2/§7.3 ADR-to-README mapping.** Plan §7 has three tight subsections; rewritten `architecture/README.md` carries them near-verbatim with cosmetic phrasing tweaks (≤10% drift per T.W0.2 DoD). Adding extra detail (e.g. "do not create new files at root") is acceptable expansion if it's consistent with the source rule, not a redefinition.

3. **OQ-1 resolution propagation.** Plan §7.3 originally listed `mcp/` as an indexed subdir; OQ-1 resolved 2026-04-25 to drop `architecture/mcp/`. README correctly omits it. Watch this kind of "resolution-after-original-spec" pattern in future fidelity reviews — easy to miss if you only diff against the §7.3 verbatim text without scanning §10 OQs.

4. **Lock-Bypass clause partial documentation — drift note, not block.** Cornerstone §Q6 spec has three parts: trailer + log file + no `--no-verify`. The PR's agent-network-v1/README.md only carries the trailer clause. Non-blocking because (a) lock isn't active yet (canonical-v1.md not shipped), (b) README is a pointer not the spec, (c) cornerstone §Q6 remains authoritative. Surfaced as W2/W3 follow-up. Pattern: when a "scoped pointer" doc references a contract owned by another plan, the pointer should either be complete or explicitly defer to the owning plan ("see cornerstone §Q6 for full spec").

5. **Scope-creep check via positive enumeration.** Verified all 16 canonical-keep files still at `architecture/` root awaiting W1 by `for f in <list>; do test -f architecture/$f; done`. Faster than full-tree diff and catches the specific drift that matters (W1 files moved early).

## Process notes

- `scripts/reviewer-auth.sh gh api user --jq .login` returned `strawberry-reviewers` (default lane, correct for personal-concern Lucian).
- Reviewed via `scripts/reviewer-auth.sh gh pr review 61 --approve --body-file ...`. Review state confirmed APPROVED.

## Cross-link

- Cornerstone plan §Q6 spec: `plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md`
- Aphelios breakdown commit: `a9e80993`
