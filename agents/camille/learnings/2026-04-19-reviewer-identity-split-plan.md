# 2026-04-19 — Reviewer identity split plan authored

## Trigger

PR #45 masking incident: Senna CHANGES_REQUESTED collapsed under Lucian
APPROVED because both submitted reviews via the same `strawberry-reviewers`
GitHub identity. GitHub tracks one review-state slot per user per PR; the
later submission overwrites the earlier one in the PR's overall decision
display.

## Finding

The collision is structural in GitHub's review-state model. No script-side
fix (e.g. "don't auto-approve within N seconds of a CHANGES_REQUESTED")
addresses the root cause — only per-agent identities do.

## Plan

`plans/proposed/2026-04-19-reviewer-identity-split.md` — splits Senna onto
`strawberry-reviewers-2` while Lucian stays on `strawberry-reviewers`.
Option A (single-script `--lane` flag) preferred over Option B (sibling
scripts) because Rule 6 audit surface stays singular.

Mid-authoring, Duong extended scope to fold in branch-protection
2-approvals (`required_approving_review_count: 2`,
`dismiss_stale_reviews: false`, `require_code_owner_reviews: false`) as
Phase 7. Rationale: two distinct identities make 2-approvals structurally
enforceable; Rule 18 becomes platform-enforced, not just
agent-behavioral.

## Sequencing gotcha captured in plan

Branch-protection 2-approvals MUST land AFTER the identity split. Enabling
it under a shared identity blocks every PR indefinitely — one account
cannot supply two distinct approvers.

## Other decisions

- `dismiss_stale_reviews: false` to preserve the two-lane signal across
  late author pushes. Trade-off accepted.
- `require_code_owner_reviews: false` until `CODEOWNERS` is authored
  (follow-up plan).
- `strawberry-agents` gets the 2-approval gate first for lower blast
  radius; soak period before strawberry-app.

## State verification anchors (for next reviewer of this plan)

- `scripts/reviewer-auth.sh:25` — single hardcoded AGE_FILE.
- `.claude/agents/senna.md:48,53-55` / `lucian.md:49,54-56` — shared
  identity expectations.
- `secrets/encrypted/` listing — only `reviewer-github-token.age` today,
  no lane variants.
- Branch-protection audit: see
  `agents/camille/learnings/2026-04-19-branch-protection-probe-and-rulesets.md`.
