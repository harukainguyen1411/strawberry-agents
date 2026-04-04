#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load environment variables
if [[ -f "$DIR/.env" ]]; then
  set -a
  source "$DIR/.env"
  set +a
fi

# Create venv if missing
if [[ ! -d "$DIR/.venv" ]]; then
  echo "Creating Python venv at $DIR/.venv ..." >&2
  uv venv "$DIR/.venv"
  uv pip install --python "$DIR/.venv/bin/python" mcp
fi

exec "$DIR/.venv/bin/python" "$DIR/server.py"
