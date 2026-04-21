# Main Branch Protection Payload — 2026-04-21

## Prerequisites

Apply this payload only after ALL of the following have merged to main:

1. **PR #9** (`ops/delete-auto-rebase`) — removes `auto-rebase.yml`
2. **PR #10** (`ops/delete-vestigial-workflows-round2`) — removes `auto-label-ready.yml`, `pr-lint.yml`, `release.yml`, `validate-scope.yml`

After both PRs merge, only `tdd-gate.yml` remains in `.github/workflows/`. That workflow reports exactly two check names to GitHub's check-runs API: `xfail-first check` and `regression-test check`.

## Sequencing Note

PR #7 (`orianna-work-repo-routing`) should merge before applying branch protection — it is content-blocking (the Orianna routing fix) and its CI is currently in-progress after billing unblock. Do not apply protection until PR #7 is merged, otherwise the new protection may block it on a check that won't pass on the stale run.

Recommended merge order:
1. PR #7 (`orianna-work-repo-routing`) — content, merge first
2. PR #9 (`ops/delete-auto-rebase`) — ops, can merge alongside #10
3. PR #10 (`ops/delete-vestigial-workflows-round2`) — ops, can merge alongside #9
4. Apply this branch protection payload

## Check Name Verification

Check names verified against:

- `tdd-gate.yml` job `name:` fields (source of truth for what GitHub registers):
  - Job `xfail-first` → `name: xfail-first check`
  - Job `regression-test` → `name: regression-test check`

- Live `gh pr checks` output on PR #7 after billing-unblock rerun (2026-04-21):
  - `xfail-first check` — PASS
  - `regression-test check` — PASS

These two strings match exactly what the GitHub check-runs API reports. Any mismatch would cause branch protection to require a check that never appears, permanently blocking merges.

## Application Commands

Run these as `harukainguyen1411` (admin identity). `Duongntd` does not have admin on this repo.

### Step 1 — Verify prerequisites are merged

```bash
gh pr list --repo harukainguyen1411/strawberry-agents --state open
# Should show no PR #7, #9, or #10 in the output (all merged)
```

### Step 2 — Verify only tdd-gate.yml remains

```bash
ls path/to/strawberry-agents/.github/workflows/
# Expected: tdd-gate.yml only
```

### Step 3 — Apply protection

```bash
gh api --method PUT repos/harukainguyen1411/strawberry-agents/branches/main/protection --input - <<'PAYLOAD'
{
  "required_status_checks": {
    "strict": true,
    "checks": [
      { "context": "xfail-first check" },
      { "context": "regression-test check" }
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false
}
PAYLOAD
```

### Step 4 — Verify applied correctly

```bash
gh api repos/harukainguyen1411/strawberry-agents/branches/main/protection \
  --jq '{required_checks: .required_status_checks.checks, enforce_admins: .enforce_admins.enabled, approving_reviews: .required_pull_request_reviews.required_approving_review_count}'
```

Expected output:
```json
{
  "required_checks": [
    {"context": "xfail-first check", "app_id": null},
    {"context": "regression-test check", "app_id": null}
  ],
  "enforce_admins": true,
  "approving_reviews": 1
}
```

## Notes

- `"checks"` array (with `context` objects) is required for the modern protection API. The older `"contexts"` array (flat strings) is deprecated — use `--input -` with JSON body, not `--field`, as `--field` cannot express nested objects.
- `restrictions: null` — no push restrictions (public repo or team-managed access is sufficient).
- `enforce_admins: true` — admins are also subject to the protection. Duong can override via the GitHub UI break-glass procedure documented in `plans/approved/2026-04-17-branch-protection-enforcement.md` §3.
- The stale `.github/branch-protection.json` doc has been updated in PR #10 to clear its orphaned `validate-scope` and `preview` contexts. This file is documentation only — it has no effect on live branch protection.
