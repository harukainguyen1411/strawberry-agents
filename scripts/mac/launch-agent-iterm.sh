#!/usr/bin/env bash
# macOS only: Launch a Strawberry agent in a new iTerm2 window.
# Ported from mcps/agent-manager/server.py launch_agent tool.
# On Windows, use Task subagent instead — see scripts/windows/launch-agent.sh.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

# macOS guard
if [ "$(uname)" != "Darwin" ]; then
  echo "launch-agent-iterm: macOS only" >&2
  exit 2
fi

if [ $# -lt 1 ]; then
  echo "Usage: scripts/mac/launch-agent-iterm.sh <agent-name> [initial-task]" >&2
  exit 2
fi

AGENT_NAME="${1,,}"  # lowercase
INITIAL_TASK="${2:-}"
GREETING="$(echo "$AGENT_NAME" | sed 's/./\u&/')"  # capitalize first letter

AGENT_DIR="$REPO_ROOT/agents/$AGENT_NAME"
if [ ! -d "$AGENT_DIR" ]; then
  echo "launch-agent-iterm: agent '$AGENT_NAME' not found at $AGENT_DIR" >&2
  exit 1
fi

# Resolve model tier — Opus for planners, Sonnet for executors
OPUS_AGENTS="evelynn azir kayn aphelios caitlyn lulu neeko heimerdinger camille lux"
MODEL_FLAG="sonnet"
for opus_name in $OPUS_AGENTS; do
  if [ "$AGENT_NAME" = "$opus_name" ]; then
    MODEL_FLAG="opus"
    break
  fi
done

# Build launch command — reads token via $(cat) to keep plaintext out of scrollback
TOKEN_FILE="$REPO_ROOT/secrets/agent-github-token"
if [ -f "$TOKEN_FILE" ]; then
  # Use single-quoted path expansion in subshell to avoid leaking to env
  LAUNCH_CMD="export GH_TOKEN=\$(cat '$TOKEN_FILE') && export GITHUB_TOKEN=\$(cat '$TOKEN_FILE') && cd $REPO_ROOT && claude --model $MODEL_FLAG"
else
  LAUNCH_CMD="cd $REPO_ROOT && claude --model $MODEL_FLAG"
fi

# Escape for AppleScript embedding (backslashes then double-quotes)
LAUNCH_CMD_ESC="${LAUNCH_CMD//\\/\\\\}"
LAUNCH_CMD_ESC="${LAUNCH_CMD_ESC//\"/\\\"}"

# Grid layout: 3 cols × 2 rows (mirroring GRID_COLS=3, GRID_ROWS=2 from server.py)
# Count existing iTerm agent windows via osascript
EXISTING_COUNT=$(osascript -e '
tell application "iTerm"
  count windows
end tell' 2>/dev/null || echo "0")
SLOT=$(( EXISTING_COUNT % 6 ))

# Screen bounds via Finder
SCREEN_BOUNDS=$(osascript -e '
tell application "Finder"
  get bounds of window of desktop
end tell' 2>/dev/null || echo "0, 0, 1920, 1080")

# Parse screen width/height (format: "x1, y1, x2, y2")
SCREEN_W=$(echo "$SCREEN_BOUNDS" | awk -F',' '{print $3+0}')
SCREEN_H=$(echo "$SCREEN_BOUNDS" | awk -F',' '{print $4+0}')
[ "$SCREEN_W" -gt 0 ] || SCREEN_W=1920
[ "$SCREEN_H" -gt 0 ] || SCREEN_H=1080

MENU_BAR=25
USABLE_H=$(( SCREEN_H - MENU_BAR ))
COL=$(( SLOT % 3 ))
ROW=$(( SLOT / 3 ))
CELL_W=$(( SCREEN_W / 3 ))
CELL_H=$(( USABLE_H / 2 ))
X1=$(( COL * CELL_W ))
Y1=$(( MENU_BAR + ROW * CELL_H ))
X2=$(( X1 + CELL_W ))
Y2=$(( Y1 + CELL_H ))

# Launch iTerm window with agent profile
osascript << APPLESCRIPT
tell application "iTerm"
  activate
  set newWindow to (create window with profile "$GREETING")
  tell current session of current tab of newWindow
    set name to "$GREETING"
    write text "$LAUNCH_CMD_ESC"
  end tell
  set bounds of newWindow to {$X1, $Y1, $X2, $Y2}
end tell
APPLESCRIPT

# Brief pause to let Claude Code boot
sleep 2

# Send startup message
STARTUP_MSG="[autonomous] $GREETING, you have been launched by another agent. Check your inbox for tasks."
osascript -e "
tell application \"iTerm\"
  tell current session of current tab of front window
    write text \"$STARTUP_MSG\"
  end tell
end tell" 2>/dev/null || true

# Deliver initial task via inbox if provided
if [ -n "$INITIAL_TASK" ]; then
  INBOX_DIR="$AGENT_DIR/inbox"
  TS="$(date -u +%Y%m%d-%H%M)"
  INBOX_FILE="$INBOX_DIR/${TS}-system-info.md"
  cat > "$INBOX_FILE" << INBOX_EOF
---
from: system
to: $AGENT_NAME
priority: info
timestamp: $(date -u +%Y-%m-%d\ %H:%M)
status: pending
---

$INITIAL_TASK

INBOX_EOF
  INBOX_POINTER="[inbox] $INBOX_FILE"
  osascript -e "
tell application \"iTerm\"
  tell current session of current tab of front window
    write text \"$INBOX_POINTER\"
  end tell
end tell" 2>/dev/null || true
fi

echo "Launched $GREETING (model: $MODEL_FLAG, slot: $SLOT)"
