#!/usr/bin/env bash
set -euo pipefail

# setup-agent-git-auth.sh — Configure git to use agent token for GitHub
# Run once per clone to pin git push/pull to the agent account.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TOKEN_FILE="$REPO_DIR/secrets/agent-github-token"

if [ ! -f "$TOKEN_FILE" ]; then
  echo "ERROR: Agent token not found at $TOKEN_FILE"
  exit 1
fi

# Set local credential helper to use agent token
git -C "$REPO_DIR" config --local credential.https://github.com.helper \
  "!f() { echo \"password=\$(cat $TOKEN_FILE)\"; }; f"

# Export GH_TOKEN for gh CLI
export GH_TOKEN="$(cat "$TOKEN_FILE")"

echo "Git auth locked to agent account. Token: $TOKEN_FILE"
echo "Verify: gh api user --jq .login"
