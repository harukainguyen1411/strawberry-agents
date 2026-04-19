# Branch protection on harukainguyen1411/strawberry-agents requires harukainguyen1411 account

Date: 2026-04-19

## Constraint

`gh api -X PUT repos/harukainguyen1411/strawberry-agents/branches/main/protection` requires admin
permission. Duongntd has pull/push/triage only on this repo — `admin: false`. The call will fail.

This mirrors the strawberry-app pattern: both repos are owned by harukainguyen1411 and all
branch-protection writes must originate from that account.

## Current state of strawberry-agents

- Classic branch protection: 404 (not present).
- Rulesets: 403 (GitHub Pro required for private repos).
- No prior protection to read-modify-write. Phase 7 payload can be applied fresh.

## Pre-rollout snapshot for strawberry-agents

Because classic protection 404s and rulesets 403, the pre-rollout "snapshot" is effectively empty.
harukainguyen1411 should document this before applying and use the fallback note:
"no prior protection in force — applying net-new".

## Payload (from plan § Phase 7)

```json
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 2,
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false
}
```

Note: `required_status_checks: null` because no prior checks to preserve (no CI on this repo).
