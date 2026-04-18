#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.npm-global/bin:$PATH"

# Health check for Discord-CLI integration
# Runs via cron every 15 minutes
# Posts failures to Discord #ops webhook

WEBHOOK_URL="${DISCORD_OPS_WEBHOOK:-}"
FAILURES=""

# --- PM2 process status ---
for proc in discord-bot discord-bridge result-watcher; do
  status=$(pm2 jlist 2>/dev/null | jq -r ".[] | select(.name==\"$proc\") | .pm2_env.status" 2>/dev/null || echo "missing")
  if [ "$status" != "online" ]; then
    FAILURES="${FAILURES}PM2: $proc is $status\n"
  fi
done

# --- Claude CLI auth ---
claude_output=$(timeout 30 claude --message "ping" --max-turns 1 2>&1) || true
if echo "$claude_output" | grep -qi "auth\|login\|unauthorized\|expired"; then
  FAILURES="${FAILURES}Claude CLI: auth failure\n"
fi

# --- Disk usage ---
disk_pct=$(df /home/runner --output=pcent 2>/dev/null | tail -1 | tr -d ' %')
if [ "${disk_pct:-0}" -gt 85 ]; then
  FAILURES="${FAILURES}Disk: ${disk_pct}% used\n"
fi

# --- Memory ---
mem_avail=$(free -m | awk '/Mem:/ {print $7}')
if [ "${mem_avail:-9999}" -lt 256 ]; then
  FAILURES="${FAILURES}Memory: only ${mem_avail}MB available\n"
fi

# --- Report ---
if [ -n "$FAILURES" ]; then
  echo "[ALERT] Health check failures:"
  echo -e "$FAILURES"

  if [ -n "$WEBHOOK_URL" ]; then
    payload=$(jq -n --arg content "**Strawberry Health Alert**\n$FAILURES" '{content: $content}')
    curl -s -H "Content-Type: application/json" -d "$payload" "$WEBHOOK_URL" >/dev/null 2>&1 || true
  fi
  exit 1
else
  echo "[OK] All checks passed"
fi
