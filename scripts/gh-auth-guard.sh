#!/usr/bin/env bash
# gh-auth-guard.sh — PreToolUse hook that blocks GitHub auth switching
# Agents are locked to harukainguyen1411. No account switching permitted.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.input.command // empty')

# Nothing to check if no command
[ -z "$COMMAND" ] && exit 0

# Patterns that indicate auth switching or credential manipulation
BLOCKED_PATTERNS=(
  "gh auth switch"
  "gh auth login"
  "gh auth setup-git"
  "gh auth token"
  "git credential"
  "git remote set-url"
  "GH_TOKEN="
  "GITHUB_TOKEN="
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qi "$pattern"; then
    echo "BLOCKED: GitHub auth switching is not permitted. You are locked to the agent account (harukainguyen1411)." >&2
    exit 2
  fi
done

exit 0
