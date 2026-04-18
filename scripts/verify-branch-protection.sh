#!/usr/bin/env bash
# Smoke-test the branch protection configuration by opening a throwaway PR.
# Run manually by Duong after scripts/setup-branch-protection.sh has been executed.
# DO NOT run in an agent session — this script requires interactive GitHub auth
# and human judgment at each verification step.
#
# Usage: bash scripts/verify-branch-protection.sh
set -euo pipefail

REPO="${REPO:-Duongntd/strawberry}"
BRANCH="chore/bp-smoke-test-$(date +%Y%m%d-%H%M%S)"

echo "=== Branch Protection Smoke Test ==="
echo "Repo: $REPO"
echo "Branch: $BRANCH"
echo ""

echo "--- Step 1: Create throwaway branch and push an empty commit ---"
echo "Run the following manually (agents must use scripts/safe-checkout.sh, not raw git checkout):"
echo "  bash scripts/safe-checkout.sh $BRANCH"
echo "  git commit --allow-empty -m 'chore: branch-protection smoke test — delete this branch'"
echo "  git push -u origin $BRANCH"
echo "Then re-run this script from Step 2 onward, or proceed manually below."
echo ""

echo "--- Step 2: Open a draft PR ---"
PR_URL=$(gh pr create \
  --title "chore: branch-protection smoke test (delete me)" \
  --body "QA-Waiver: smoke-test PR — verifying branch protection gates. Delete after verification." \
  --draft \
  --base main \
  --head "$BRANCH")
echo "PR opened: $PR_URL"
echo ""

echo "--- Step 3: Expected observations (verify manually) ---"
echo "a) All 5 required checks should appear as 'pending' or 'waiting':"
echo "   - xfail-first check"
echo "   - regression-test check"
echo "   - unit-tests"
echo "   - Playwright E2E"
echo "   - QA report present (UI PRs)"
echo ""
echo "b) 'Merge pull request' button should be DISABLED:"
echo "   'Required status checks have not passed yet'"
echo ""
echo "c) 'Review required' badge visible — needs 1 approving review."
echo ""
echo "d) Attempt admin merge — should be REJECTED:"
echo "   gh pr merge $PR_URL --admin"
echo "   Expected: error: GraphQL: Required status checks are not passing..."
echo ""
echo "--- Step 4: Verify API reflects full protection config ---"
gh api "repos/$REPO/branches/main/protection" \
  | jq '{
      required_status_checks: .required_status_checks.contexts,
      strict: .required_status_checks.strict,
      enforce_admins: .enforce_admins.enabled,
      required_approving_review_count: .required_pull_request_reviews.required_approving_review_count,
      dismiss_stale_reviews: .required_pull_request_reviews.dismiss_stale_reviews,
      require_last_push_approval: .required_pull_request_reviews.require_last_push_approval,
      required_conversation_resolution: .required_conversation_resolution.enabled
    }'
echo ""

echo "--- Step 5: Cleanup ---"
echo "Close and delete the throwaway PR and branch:"
echo "  gh pr close $PR_URL"
echo "  git push origin --delete $BRANCH"
echo "  git branch -d $BRANCH"
