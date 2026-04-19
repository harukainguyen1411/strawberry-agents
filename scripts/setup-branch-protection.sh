#!/usr/bin/env bash
# Apply ruleset-based branch protection for a strawberry repo.
# Run as the repo owner / a token with Administration:write.
#
# Usage:
#   bash scripts/setup-branch-protection.sh [OWNER/REPO]
#
#   Defaults:
#     REPO env var, then Duongntd/strawberry (private planning repo).
#     For strawberry-app:  bash scripts/setup-branch-protection.sh harukainguyen1411/strawberry-app
#
# NOTE: This script uses the Rulesets API (not classic branch protection).
# Classic branch protection (PUT /branches/main/protection) is retired.
#
# bypass_actors: harukainguyen1411 (ID 273533031) for strawberry-app.
#   For Duongntd/strawberry, swap in Duongntd's user ID.
# bypass_mode: "pull_request" — owner must still open a PR for audit trail,
#   but skips status-check and review requirements on that PR.
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

OWNER="${REPO%%/*}"

# Pick bypass actor based on repo owner.
# harukainguyen1411 user ID 273533031 — strawberry-app owner.
# Duongntd: fetch at runtime for the private planning repo.
if [ "$OWNER" = "harukainguyen1411" ]; then
  BYPASS_ACTOR_ID=273533031
else
  BYPASS_ACTOR_ID="$(gh api /users/Duongntd --jq '.id')"
fi

echo "=== Apply ruleset branch protection: $REPO main ==="
echo "Bypass actor ID: $BYPASS_ACTOR_ID (bypass_mode: pull_request)"

# Write ruleset JSON to a temp file; substitute the bypass actor ID.
TMPFILE="$(mktemp /tmp/ruleset-XXXXXX.json)"
trap 'rm -f "$TMPFILE"' EXIT

cat > "$TMPFILE" <<JSON
{
  "name": "main-branch-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": { "include": ["refs/heads/main"], "exclude": [] }
  },
  "bypass_actors": [
    { "actor_id": ${BYPASS_ACTOR_ID}, "actor_type": "User", "bypass_mode": "pull_request" }
  ],
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": true,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "xfail-first check" },
          { "context": "regression-test check" },
          { "context": "unit-tests" },
          { "context": "Playwright E2E" },
          { "context": "QA report present (UI PRs)" }
        ]
      }
    }
  ]
}
JSON

gh api "repos/$REPO/rulesets" \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  --input "$TMPFILE"

echo "Done. Ruleset applied."

echo ""
echo "=== Verify ==="
gh api "repos/$REPO/rulesets" \
  --jq '.[] | {id, name, enforcement, target}'

echo ""
echo "=== Auto-delete branches on merge (idempotent) ==="
gh repo edit "$REPO" --delete-branch-on-merge
echo "Done."

echo ""
echo "Classic protection endpoint (expect 404 — rulesets live separately):"
gh api "repos/$REPO/branches/main/protection" 2>&1 || echo "  -> 404 expected (OK)"
