#!/usr/bin/env bash
# Setup branch protection for strawberry repo.
# Run as Duongntd (repo owner) after all required CI workflows exist on main.
# Usage: bash scripts/setup-branch-protection.sh
#
# DO NOT RUN until PR #117 (tdd-hooks-and-ci) and PR #126 (bash-guard fix)
# are merged so the required check contexts actually exist in GitHub Actions.
set -euo pipefail

REPO="${REPO:-Duongntd/strawberry}"

echo "=== Step 1: Wire full branch protection on main ==="
cat > /tmp/bp.json << 'JSON'
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
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "require_last_push_approval": true
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
gh api "repos/$REPO/branches/main/protection" \
  -X PUT \
  -H "Accept: application/vnd.github+json" \
  --input /tmp/bp.json
rm /tmp/bp.json
echo "Done. Branch protection with required checks and review enforcement wired."

echo ""
echo "=== Step 2: Add second account (harukainguyen1411) as collaborator ==="
echo "Run manually if not already done:"
echo ""
echo "  gh api repos/$REPO/collaborators/harukainguyen1411 -X PUT -H 'Accept: application/vnd.github+json' -f permission=push"
echo ""

echo "=== Step 3: Configure agent CLI sessions under harukainguyen1411 ==="
echo "Create a fine-grained PAT for harukainguyen1411 with:"
echo "  - Repository access: $REPO"
echo "  - Permissions: Contents (read/write), Pull requests (read/write)"
echo ""
echo "Then in agent sessions that need to review PRs:"
echo "  gh auth login --with-token < token-file.txt"
echo "Or set GH_TOKEN in the agent session environment."

echo ""
echo "=== Step 4: Enable auto-delete branches on merge ==="
gh repo edit "$REPO" --delete-branch-on-merge
echo "Done. Branches will auto-delete after merge."

echo ""
echo "=== Step 5: Verify ==="
echo "Run scripts/verify-branch-protection.sh for a throwaway-PR smoke test."
echo ""
echo "Quick API check:"
echo "  gh api repos/$REPO/branches/main/protection | jq '.required_status_checks, .required_pull_request_reviews, .enforce_admins'"
