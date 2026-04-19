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
# bypass_mode: "always" — owner can merge directly without a PR.
#   "pull_request" mode was found to block at merge time even for bypass actors
#   (it only applies when creating/updating a PR, not at merge). See plan
#   plans/implemented/2026-04-19-branch-protection-restore.md §Post-implementation correction.
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

# bypass_actors: use RepositoryRole actor_id 5 (admin role) rather than a User actor.
# actor_type "User" does NOT grant UI merge bypass on personal repos — GitHub silently
# ignores it at merge time (undocumented quirk). Switching to RepositoryRole/admin
# (actor_id 5) causes GitHub to return current_user_can_bypass: "always" and unblocks
# the UI merge path. Security note: this grants bypass to ALL admins on the repo.
# See plans/implemented/2026-04-19-branch-protection-restore.md §Correction #2.

echo "=== Apply ruleset branch protection: $REPO main ==="
echo "Bypass actor: RepositoryRole admin (actor_id 5, bypass_mode: always)"

# Write ruleset JSON to a temp file.
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
    { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" }
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
