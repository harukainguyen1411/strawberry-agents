---
date: 2026-04-18
role: caitlyn
topic: coordinator patterns — ground-truth verification, review-branch vs main drift
---

# Ground-truth verification as first move, not fallback

Today I managed a ~12-PR review/merge workstream where reviewer-side and my-side state kept diverging. Multiple times I pushed back on a reviewer's finding as "stale view," and multiple times I was wrong — they were comparing against main (the correct baseline for "does this PR fix the bug on main?"), I was comparing against the PR branch (the correct baseline for "is the fix present on this branch?"). Both views are valid for different questions.

The worst case: PR #159 (Viktor's I1 deploy script) merged to main with ZERO reviews via admin bypass (rule 18 breach). Jhin's review against #180 (the fix PR) was reading main and correctly flagging "the bug is still there." I was reading #180's branch and wrongly telling him "the fix is already present." Both true. He was reviewing the right thing; I was fighting a phantom.

## Patterns I should carry forward

1. **When a reviewer flags a "still open" finding, check where they're looking.** `git show origin/main:<path>` and `git show origin/<pr-branch>:<path>` may diverge. The reviewer's view might be correct for their baseline even when mine (branch) differs.

2. **Verify empirically FIRST, not after back-and-forth.** On two separate occasions today I pushed back on findings with "stale view" framing, then ran `git show` to verify, then discovered I was wrong. Should have run `gh pr view`, `git show`, `gh api repos/.../pulls/<n>` as the FIRST step, not after three rounds of messaging.

3. **Reviewer-state divergence has real process fixes.** Both Jhin and Azir self-diagnosed and committed to `git fetch origin && git show origin/<branch>:<path>` (Jhin) / `api/pulls/<n>` HEAD check (Azir) before any re-review. That's the right fix — not more coordinator messaging, but a reviewer practice.

4. **`gh pr view --json reviews` returns empty even when substantive LGTMs exist as comments.** Multiple PRs today had reviewer LGTMs in comment form but `reviewDecision: ""` + `reviewCount: 0` per GH API. Formal PR review submission (with APPROVE event) vs comment-only approval is a distinction that matters at merge-gate time. Worth flagging to Duong when batching merges — rule 18 enforcement may not see comment-LGTMs.

5. **Adopted review policy worth preserving across sessions:** "Architecture LGTM extends to future tips of the same PR absent architectural changes. ADR-surface concerns (route semantics, auth model, data model, IAM, deploy topology, API contract) warrant explicit re-review; everything else the prior LGTM carries." Azir adopted this today; cuts rescan-on-every-typo-fix friction.

## What I'd do differently

- On the FIRST "reviewer sees X, I see Y" divergence, run both `git show origin/main:<path>` AND `git show origin/<branch>:<path>` before replying. State both findings. Let the reviewer and I together figure out which baseline they care about.
- Don't frame reviewer disagreement as "stale view" until I've verified it genuinely is one. "Phantom" and "stale" were my words for my own confusion multiple times today. Retract faster.
- When a fix PR exists for a bug on main, acknowledge the reviewer's review is doing "is main still broken?" assessment, not "is the fix branch correct?" assessment.
