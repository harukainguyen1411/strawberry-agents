#!/usr/bin/env bash
# coordinator-boot.sh — single canonical boot path for Evelynn and Sona.
#
# Usage:
#   bash scripts/coordinator-boot.sh Evelynn
#   bash scripts/coordinator-boot.sh Sona
#
# Identity vars passed to claude via `env` (NOT exported into the parent shell):
#   CLAUDE_AGENT_NAME      canonical case: Evelynn | Sona
#   STRAWBERRY_AGENT       mirror, for older hooks
#   STRAWBERRY_CONCERN     personal | work
#
# Side effects:
#   - cd to repo root
#   - runs bash scripts/memory-consolidate.sh <name>
#   - exec claude --agent <name>
#
# Exit codes:
#   0  — never (exec replaces the process)
#   2  — unknown coordinator argument
#
# POSIX-portable bash (Rule 10). set -eu (no pipefail: POSIX).
set -eu

# ────────────────────────────────────────────────────────────────
# Argument validation
# ────────────────────────────────────────────────────────────────

if [ $# -lt 1 ]; then
  printf 'coordinator-boot: usage: coordinator-boot.sh <Evelynn|Sona>\n' >&2
  exit 2
fi

COORDINATOR="$1"

case "$COORDINATOR" in
  Evelynn)
    STRAWBERRY_CONCERN_VAL="personal"
    ;;
  Sona)
    STRAWBERRY_CONCERN_VAL="work"
    ;;
  *)
    printf 'coordinator-boot: unknown coordinator "%s"; expected Evelynn or Sona\n' "$COORDINATOR" >&2
    exit 2
    ;;
esac

# ────────────────────────────────────────────────────────────────
# Resolve repo root (script location independent)
# ────────────────────────────────────────────────────────────────

# Resolve absolute path to this script, then navigate to repo root.
# BASH_SOURCE[0] is the script itself; dirname twice = scripts/ then repo root.
SCRIPT_PATH="$0"
# Portable realpath replacement
if command -v realpath >/dev/null 2>&1; then
  SCRIPT_ABS="$(realpath "$SCRIPT_PATH")"
else
  # cd-based resolution (POSIX-compatible)
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_ABS="$SCRIPT_DIR/$(basename "$SCRIPT_PATH")"
fi
REPO_ROOT="$(dirname "$SCRIPT_ABS")"
# REPO_ROOT is now the scripts/ directory — go one level up to repo root
REPO_ROOT="$(dirname "$REPO_ROOT")"

cd "$REPO_ROOT"

# ────────────────────────────────────────────────────────────────
# Memory consolidation (deterministic, shell-level — not model-level)
# ────────────────────────────────────────────────────────────────

NAME_LOWER="$(printf '%s' "$COORDINATOR" | tr '[:upper:]' '[:lower:]')"

if [ -f "$REPO_ROOT/scripts/memory-consolidate.sh" ]; then
  # Run consolidation; tolerate failure (boot continues either way)
  bash "$REPO_ROOT/scripts/memory-consolidate.sh" "$NAME_LOWER" >/dev/null 2>&1 \
    || printf 'coordinator-boot: warn: memory-consolidate.sh failed for %s (continuing)\n' "$COORDINATOR" >&2
fi

# ────────────────────────────────────────────────────────────────
# Launch coordinator
#
# Identity vars are scoped to the exec'd process via `env`, NOT
# exported into the parent shell.  This prevents STRAWBERRY_AGENT
# from leaking back to the calling terminal when coordinator-boot.sh
# is invoked as a subprocess (e.g. via the shell aliases in
# scripts/mac/aliases.sh) or — in an edge case — sourced.
# ────────────────────────────────────────────────────────────────

exec env \
  CLAUDE_AGENT_NAME="$COORDINATOR" \
  STRAWBERRY_AGENT="$COORDINATOR" \
  STRAWBERRY_CONCERN="$STRAWBERRY_CONCERN_VAL" \
  claude --agent "$COORDINATOR"
