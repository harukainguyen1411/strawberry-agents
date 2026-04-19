#!/usr/bin/env bash
# Apply classic branch protection for a strawberry repo.
# Run as the repo owner / a token with Administration:write.
#
# Usage:
#   bash scripts/setup-branch-protection.sh [OWNER/REPO]
#
#   Defaults:
#     REPO env var, then derives from git remote origin.
#     For strawberry-app:  bash scripts/setup-branch-protection.sh harukainguyen1411/strawberry-app
#
# NOTE: This script uses classic branch protection (PUT /branches/main/protection).
# Rulesets were tried and abandoned — the GitHub ruleset UI bypass is broken for the
# `pull_request` rule type on personal repos (GitHub community discussion #113172, open
# for ≥1 year). Even with RepositoryRole/admin bypass + bypass_mode: "always" +
# current_user_can_bypass: "always" returned by the API, the UI merge button remained
# blocked for `pull_request` rule type. Classic protection with enforce_admins: false
# is the reliable workaround.
#
# Tradeoff: enforce_admins: false grants bypass to ALL admins (any admin can merge
# without satisfying checks). Since harukainguyen1411 is currently sole admin, effective
# access is identical to a per-user bypass. Acceptable for now; review if admin roster
# changes.
set -euo pipefail

_derive_repo_from_remote() {
  local remote_url
  remote_url="$(git remote get-url origin 2>/dev/null)" || return 1
  echo "$remote_url" | sed -E 's|.*github\.com[:/]||; s|\.git$||'
}

if [ -n "${1:-}" ]; then
  REPO="$1"
elif [ -n "${REPO:-}" ]; then
  : # use REPO env var as-is
elif [ -n "${GITHUB_REPOSITORY:-}" ]; then
  REPO="$GITHUB_REPOSITORY"
else
  REPO="$(_derive_repo_from_remote)" || {
    echo "ERROR: cannot determine repo slug. Pass OWNER/REPO as \$1." >&2
    exit 1
  }
fi

echo "=== Apply classic branch protection: $REPO main ==="
echo "enforce_admins: false (admin role bypass — see comment at top of script)"

# Write protection JSON to a temp file.
TMPFILE="$(mktemp /tmp/protection-XXXXXX.json)"
trap 'rm -f "$TMPFILE"' EXIT

cat > "$TMPFILE" <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "xfail-first check",
      "regression-test check",
      "unit-tests",
      "Playwright E2E",
      "QA report present (UI PRs)"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_last_push_approval": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_conversation_resolution": true,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON

gh api "repos/$REPO/branches/main/protection" \
  -X PUT \
  -H "Accept: application/vnd.github+json" \
  --input "$TMPFILE"

echo "Done. Classic protection applied."

echo ""
echo "=== Verify ==="
gh api "repos/$REPO/branches/main/protection" \
  --jq '{enforce_admins:.enforce_admins.enabled, checks:.required_status_checks.contexts, reviews:.required_pull_request_reviews.required_approving_review_count}'

echo ""
echo "=== Auto-delete branches on merge (idempotent) ==="
gh repo edit "$REPO" --delete-branch-on-merge
echo "Done."
