---
name: reviewer-identity-masking-and-lane-split
description: When two reviewer roles post via one GitHub identity, the latest review silently overwrites the earlier one — GitHub's decision collapses onto the one identity's latest state. Fix is another identity, not rule relaxation.
type: feedback
---

# Reviewer-identity masking and the two-lane split

## What happened

PR #45 round 2 (2026-04-19, ~12:23 UTC):
- Senna posted CHANGES_REQUESTED at 12:23:56 flagging a critical composable bug (`parseResult.value = useCsvParser().result.value` constructs a fresh instance; parseResult always null on step 2).
- Lucian posted APPROVED at 12:24:09 — 13 seconds later.
- Both posted as `strawberry-reviewers` via `scripts/reviewer-auth.sh`.
- GitHub's overall `reviewDecision` returned APPROVED, because the LATEST review from each distinct reviewer counts, and since both were the same identity, Lucian's later APPROVED was the authoritative state.
- If I had merged on `reviewDecision` alone, the PR would have shipped a guaranteed-broken user flow.

## Why

GitHub PR review model per-identity: latest review wins. With N reviewers sharing one account, GitHub cannot distinguish their verdicts — it sees a single reviewer whose latest posture is whatever the last poster set. There is no "both must approve" semantic at the identity layer; the 2-approval branch-protection gate depends on `reviews[*].author.login` being distinct across approvals.

## Pattern to remember

When a policy gate with two binding clauses collapses, the fix is usually another identity, not rule relaxation.

Prior instance: Rule 18 (non-author-approver) and Rule 18 (no admin-bypass) both binding on an agent-account PR. Introducing `strawberry-reviewers` as a distinct identity satisfied both structurally. Today's pattern is the same shape, one level in: `strawberry-reviewers` was holding Senna AND Lucian lanes, collapsing their verdicts. Introducing `strawberry-reviewers-2` for Senna fixes it.

Generalization: if you find yourself writing "Person A shouldn't step on Person B's verdict" as a behavioral rule, check whether A and B are forced to share a credential. If so, the fix is another credential, not another rule.

## How to apply

1. **On any review-pair PR**: don't trust `reviewDecision` alone when both reviewers post via the same bot identity. Read review bodies + check state of each distinct author.login. This is the fallback until branch-protection 2-approval + distinct identities both land.
2. **On any new policy with two binding clauses**: ask whether all actors can satisfy both clauses simultaneously. If satisfying one forces the other to violate (e.g. "must be non-author" + "must not admin-bypass" when all agents share one auth), the credential model is wrong before the rule is.
3. **Before writing behavioral rules to resolve identity conflicts**: try splitting the identity first. Rules drift; identities are structural.

## The two-lane implementation (reference)

- `strawberry-reviewers-2` created by Duong (email `duongntd99+strawberryreviewers@gmail.com`), accepts collaborator invites on both strawberry-app and strawberry-agents.
- `scripts/reviewer-auth.sh --lane senna` decrypts `secrets/encrypted/reviewer-github-token-senna.age` → auth as `strawberry-reviewers-2`.
- Default lane (no `--lane`) decrypts `reviewer-github-token.age` → auth as `strawberry-reviewers` (Lucian).
- `.claude/agents/senna.md` and `lucian.md` updated to make the lane explicit in their review-step instructions.
- 2-approval gate on strawberry-app branch protection: `required_approving_review_count: 2`, `dismiss_stale_reviews: false`.
- strawberry-agents still discipline-only: GitHub Free doesn't expose branch protection on private repos.
