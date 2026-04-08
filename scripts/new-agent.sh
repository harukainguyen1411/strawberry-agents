#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

usage() {
  echo "Usage: scripts/new-agent.sh <agent-name> [--role \"<short role string>\"] [--profile-text-file <path>]" >&2
  exit 2
}

# Parse arguments
AGENT_NAME=""
ROLE=""
PROFILE_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --role)
      shift
      ROLE="${1:-}"
      shift
      ;;
    --profile-text-file)
      shift
      PROFILE_FILE="${1:-}"
      shift
      ;;
    -*)
      echo "new-agent: unknown option $1" >&2
      usage
      ;;
    *)
      if [ -z "$AGENT_NAME" ]; then
        AGENT_NAME="$1"
        shift
      else
        echo "new-agent: unexpected argument $1" >&2
        usage
      fi
      ;;
  esac
done

if [ -z "$AGENT_NAME" ]; then
  usage
fi

# Validate agent name: ^[a-z][a-z0-9_-]{1,31}$
if ! echo "$AGENT_NAME" | grep -qE '^[a-z][a-z0-9_-]{1,31}$'; then
  echo "new-agent: invalid agent name '$AGENT_NAME' — must match ^[a-z][a-z0-9_-]{1,31}$" >&2
  exit 2
fi

AGENT_DIR="$REPO_ROOT/agents/$AGENT_NAME"

# Refuse if already exists
if [ -d "$AGENT_DIR" ]; then
  echo "new-agent: agent '$AGENT_NAME' already exists at $AGENT_DIR" >&2
  exit 3
fi

# Capitalize name for headings
NAME_CAP="$(echo "$AGENT_NAME" | sed 's/./\u&/')"

# Create directory layout
mkdir -p "$AGENT_DIR/memory"
mkdir -p "$AGENT_DIR/journal"
mkdir -p "$AGENT_DIR/learnings"
mkdir -p "$AGENT_DIR/transcripts"
mkdir -p "$AGENT_DIR/inbox"

# profile.md
if [ -n "$PROFILE_FILE" ]; then
  cp "$PROFILE_FILE" "$AGENT_DIR/profile.md"
else
  ROLE_TEXT="${ROLE:-TBD — fill in the role}"
  cat > "$AGENT_DIR/profile.md" << PROFILE_EOF
# $NAME_CAP

## Role
$ROLE_TEXT

## Age
TBD

## Backstory
TBD

## Speaking Style
TBD
PROFILE_EOF
fi

# memory/<name>.md
cat > "$AGENT_DIR/memory/$AGENT_NAME.md" << MEM_EOF
# $NAME_CAP

## Role
${ROLE:-TBD}
MEM_EOF

# .gitkeep files for empty directories
touch "$AGENT_DIR/journal/.gitkeep"
touch "$AGENT_DIR/learnings/.gitkeep"
touch "$AGENT_DIR/transcripts/.gitkeep"
touch "$AGENT_DIR/inbox/.gitkeep"

# Report created tree
echo "Created agent scaffold at $AGENT_DIR:"
find "$AGENT_DIR" -type f -o -type d | sort | sed "s|$REPO_ROOT/||"

exit 0
