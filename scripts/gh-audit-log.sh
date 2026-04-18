#!/usr/bin/env bash
# gh-audit-log.sh — PostToolUse hook that logs git/gh commands for audit
# Logs to ~/.strawberry/ops/git-audit.log

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.input.command // empty')

# Only log git and gh commands
if echo "$COMMAND" | grep -qiE '^(git |gh )'; then
  LOG_DIR="$HOME/.strawberry/ops"
  mkdir -p "$LOG_DIR"
  AGENT="${CLAUDE_AGENT_NAME:-unknown}"
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] agent=$AGENT cmd=$COMMAND" >> "$LOG_DIR/git-audit.log"
fi

exit 0
