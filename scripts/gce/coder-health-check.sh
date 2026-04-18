#!/usr/bin/env bash
# Health check for Claude Code CLI auth on the coder-worker VM.
# Installed as a cron job (every 6 hours).
# If auth fails 3 times, stops coder-worker and alerts via Discord webhook.
set -euo pipefail

LOG_DIR="/var/log/coder-worker"
FAIL_MARKER="$LOG_DIR/auth-fail-count"
DISCORD_WEBHOOK_URL="${CODER_DISCORD_WEBHOOK_URL:-}"

check_auth() {
  timeout 30 claude -p "ping" >/dev/null 2>&1
}

log_msg() {
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $1"
}

alert_discord() {
  if [ -n "$DISCORD_WEBHOOK_URL" ]; then
    curl -sf -X POST "$DISCORD_WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "{\"content\":\"coder-worker auth failure on $(hostname). SSH in and run: sudo -u coder -i claude login\"}" \
      >/dev/null 2>&1 || true
  fi
}

if check_auth; then
  log_msg "AUTH OK"
  echo "0" > "$FAIL_MARKER"
  exit 0
fi

# Auth failed
FAIL_COUNT=0
if [ -f "$FAIL_MARKER" ]; then
  FAIL_COUNT=$(cat "$FAIL_MARKER" 2>/dev/null || echo "0")
fi
FAIL_COUNT=$((FAIL_COUNT + 1))
echo "$FAIL_COUNT" > "$FAIL_MARKER"

log_msg "AUTH FAIL (count=$FAIL_COUNT)"

if [ "$FAIL_COUNT" -ge 3 ]; then
  log_msg "AUTH FAIL threshold reached — stopping coder-worker service"
  sudo systemctl stop coder-worker 2>/dev/null || true
  alert_discord
fi
