# PR #65 architecture-consolidation Wave 2 — REQUEST CHANGES on Lock-Bypass log path drift

**Date:** 2026-04-25
**PR:** harukainguyen1411/strawberry-agents#65
**Plan:** `plans/approved/personal/2026-04-25-architecture-consolidation-v1.md` (Aphelios W2 breakdown, T.W2.1–T.W2.8)
**Sister ADR:** `plans/approved/personal/2026-04-25-retrospection-dashboard-and-canonical-v1.md` §Q6 (canonical-v1 lock spec)
**Verdict:** REQUEST_CHANGES via `strawberry-reviewers` (Lucian lane)
**Review:** https://github.com/harukainguyen1411/strawberry-agents/pull/65

## Findings

- **B1 (block):** Lock-Bypass audit log path drifts from cornerstone ADR. New `git-workflow.md` says `agents/<coordinator>/audit/lock-bypass-<YYYY-MM-DD>.md`; cornerstone §Q6 says `architecture/canonical-v1-bypasses.md`. Different ownership semantics (per-coordinator scatter vs single architecture-rooted manifest); also breaks the dashboard's "bypass log on home page" claim from cornerstone §6.
- **B2 (block):** Rules 14 and 19 missing from `pr-rules.md` cite list. Delegation contract specified 5/12/13/14/15/16/17/18/19/21; actual file cites 4/5/11/12/13/15/16/17/18/21. Rule 14 (`--no-verify` ban) is load-bearing for the §Q6 contract in the sister `git-workflow.md` doc.
- **D1 (drift):** Stale `[placeholder — lands W1/W2]` markers leaked into `apps/README.md` (3 entries) and `archive/README.md` (1 entry for `pre-network-v1/` populated by this PR). Commit `dbeea844` correctly cleaned `agent-network-v1/README.md` but missed sibling READMEs.

## Pass items

- All 8 commits map 1-to-1 to plan T.W2.* tasks; one commit per rewrite per OQ-7 cadence.
- All `chore:` prefix per Rule 5 (architecture/ scope).
- `pr-rules.md` correctly drops TeamCreate/Katarina/Lissandra-as-reviewer; current Senna+Lucian model documented.
- `plan-frontmatter.md` is v2-only; v1-Orianna fields archived to existing `archive/v1-orianna-gate/` precedent.
- `agents.md` is 30-line OQ-A1 default roster.
- `communication.md` captures Slack pointer-only policy as load-bearing 2026-04-25 decision.
- Rule 21 honored: no AI markers, no Co-Authored-By; `Human-Verified: yes` + `QA-Waiver:` in PR body.

## Reviewer technique notes

- **Cross-plan ADR fidelity check.** When a wave PR documents a contract owned by a *sister* cornerstone plan (here: §Q6 canonical-v1 lock), open both plans and diff the contract surface line-by-line. Path strings, trailer names, and audit-log locations are common drift points — they "look right" in isolation but silently redefine the cornerstone spec. Fast technique: `grep -n -A 30 "Q6\|Lock-Bypass" <cornerstone-plan>` then `grep -n "Lock-Bypass" <new-canonical-doc>` and compare paths verbatim.
- **Delegation-prompt cite-list verification.** When the delegation prompt enumerates rule numbers (e.g. "cites Rules 5/12/13/14/15/16/17/18/19/21"), grep the actual file: `grep -nE "Rule [0-9]+" <file>` and compare to the prompt list. Don't accept "all the important rules are there" — the prompt named the contract.
- **Sibling-README placeholder sweep.** Wave-N rewrites typically fix the canonical README cleanly but miss siblings. After confirming the canonical README is clean, always grep ALL README.md files under the affected subtree: `grep -nE "placeholder|lands W" architecture/**/README.md`. Cheap O(1) check.
- **PR-body archive claims vs commit RENAMEs.** When the PR body lists "old file archived at ..." for N rewrites, count `RENAMED` entries in `gh pr view --json files`. Should be N. Mismatch implies missing or extra archive moves.
- **Cross-wave dependency honored without overlap.** W2 author-and-archive shouldn't pull in W3 whole-file archives. Verifying T.W3.1 source files (`agent-network.md`, `agent-system.md`) remain at original locations confirms wave boundaries are respected — the cross-wave `blockedBy` chain in the plan is structural, not informational.

## Cornerstone-spec discipline (new)

When two cornerstone plans interact via a shared contract (here: consolidation plan documents the lock surface; cornerstone plan defines the lock semantics), neither plan is allowed to silently amend the other. The smaller PR (W2 doc rewrite) MUST mirror the larger plan's spec verbatim, OR an explicit amendment to the larger plan must precede the divergent doc. "Both plans are approved 2026-04-25" is not a license to redefine — it's the opposite: both authors saw the same spec and one of them rewrote it.
