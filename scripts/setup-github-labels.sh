#!/usr/bin/env bash
# setup-github-labels.sh
#
# Creates the GitHub label taxonomy used by the Discord triage bot.
# Safe to re-run — skips labels that already exist.
#
# Prerequisites:
#   - gh CLI authenticated (gh auth login)
#
# Usage:
#   bash scripts/setup-github-labels.sh [OWNER/REPO]
#
#   If OWNER/REPO is not provided as $1, falls back to:
#     1. GITHUB_REPOSITORY env var
#     2. gh repo view (requires running from within the repo)

set -euo pipefail

if [ -n "${1:-}" ]; then
  REPO="$1"
elif [ -n "${GITHUB_REPOSITORY:-}" ]; then
  REPO="$GITHUB_REPOSITORY"
else
  REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)
  if [ -z "${REPO}" ]; then
    echo "ERROR: Could not resolve repo. Pass OWNER/REPO as \$1 or run 'gh auth login' inside the repo."
    exit 1
  fi
fi

echo "Creating labels in ${REPO}..."

create_label() {
  local name="$1"
  local color="$2"
  local description="$3"

  if gh label list --repo "${REPO}" --json name --jq '.[].name' | grep -qxF "${name}"; then
    echo "  skipped (exists): ${name}"
  else
    gh label create "${name}" --repo "${REPO}" --color "${color}" --description "${description}"
    echo "  created: ${name}"
  fi
}

# App labels (green family)
create_label "app:myapps" "0e8a16" "Issues related to the MyApps web application"

# Type labels (blue family)
create_label "type:bug"     "0075ca" "Bug report"
create_label "type:feature" "0075ca" "Feature request"
create_label "type:new-app" "0075ca" "Proposal for a new application"

# Priority labels (red/orange/yellow, if not already present)
create_label "priority:p0" "b60205" "Critical: data loss or auth broken"
create_label "priority:p1" "e4e669" "High: core feature broken"
create_label "priority:p2" "fbca04" "Medium: degraded experience"
create_label "priority:p3" "c5def5" "Low: nice to have"

echo ""
echo "Done. Add new 'app:*' labels here as new public-use apps are onboarded."
