# PR #42 — reviewer-auth concern split (APPROVE)

Date: 2026-04-24
Repo: harukainguyen1411/strawberry-agents
Branch: talon/reviewer-auth-concern-split
Plan: plans/approved/personal/2026-04-24-reviewer-auth-concern-split.md
Verdict: APPROVE (with 4 non-blocking suggestions)
Review URL: https://github.com/harukainguyen1411/strawberry-agents/pull/42

## Summary

PR adds a work-scope refusal guard to `scripts/reviewer-auth.sh` (exit 4 before
PAT decrypt), splits Senna/Lucian agent-def Identity + Review Process sections
into personal-vs-work concern branches, reconciles `agents/memory/agent-network.md`
Two-Identity Model, and adds an xfail→green test.

## Verification done

- Ran `scripts/tests/test-reviewer-auth-scope-guard.sh` against branch tip — 4/4 pass.
  - work-scope exits 4
  - work-scope output references post-reviewer-comment.sh
  - reviewer-auth.env not touched (guard runs before decrypt)
  - personal-scope exits 0 under ANONYMITY_DRY_RUN=1
- Grepped senna.md + lucian.md for orphan "always" reviewer-auth language — clean.
  Remaining "always" hits are unrelated (step-4 "Always explain WHY", Rule 11
  "always merge").
- Confirmed exit-code hygiene: 1 (missing PAT), 2 (usage), 3 (legacy anonymity,
  no longer reachable from reviewer-auth.sh directly), 4 (work-scope refusal).
- Confirmed scope detection `[:/]missmp/|^missmp/` — case-sensitive match on
  `headRepository.nameWithOwner`, works today since GitHub normalizes org case.

## Suggestions posted (non-blocking)

1. Scope regex case-insensitivity for future-proofing (use `grep -qiE`).
2. Vestigial `_lib_reviewer_anonymity.sh` source — `anonymity_scan_text` no longer
   called from reviewer-auth.sh after T4; either drop the source or move the
   inline scope-match into a lib helper.
3. Stale section comment "Work-scope anonymity scan (T3)" — relabel to
   "Work-scope refusal guard (T4)".
4. Cosmetic: Unicode minus-sign (U+2212) in `reviewer-github-token[−senna].age`
   prose in agent-network.md; real filename is ASCII.

## Meta / reviewer lane

- Preflight `strawberry-reviewers-2` confirmed before submit.
- Lucian pre-approved at 08:10:37Z; my APPROVE landed at 08:11:34Z. Separate
  review slots as intended — no masking per the post-PR-#45 concern-split model.
- Signature `-- reviewer` used (neutral) — even though this is personal-scope
  agent-system infra, the anonymity lib would have also accepted `— Senna`.
  I chose neutral since the PR body itself discusses cross-concern protocol
  and the body references agent names copiously; neutral signature keeps my
  review body clean of self-reference.

## Key invariants this PR protects

1. PAT never decrypts for a work-scope invocation of reviewer-auth.sh — defense
   in depth against an agent following stale instructions.
2. `[concern: work]` dispatches cannot accidentally authenticate as
   `strawberry-reviewers{,-2}` on a `missmp/*` repo.
3. Rule 18 (b) remains satisfied: personal → structural (separate identity);
   work → manual Duong approve from harukainguyen1411 after post-reviewer-comment.sh.
