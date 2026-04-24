#!/usr/bin/env bash
# scripts/hooks/pretooluse-work-scope-identity.sh
#
# PreToolUse Bash hook: enforce neutral git author identity on work-scope worktrees.
#
# When a Bash tool call contains "git commit" and the effective cwd resolves to
# a work-scope repo (origin matches [:/]missmp/), this hook rewrites the
# per-worktree git config to Duong's canonical hand-commit identity:
#   user.name  = Duongntd
#   user.email = 103487096+Duongntd@users.noreply.github.com
#
# This is fail-closed: if the config write fails, the hook emits a block JSON
# and exits 2 so the commit does not proceed.
#
# Non-work-scope repos and non-commit commands pass through silently (exit 0).
#
# Input : JSON on stdin (Claude PreToolUse contract)
# Output: JSON block decision on failure; nothing on pass
# Exit  : 0 = proceed, 2 = block
#
# POSIX-portable bash per Rule 10.
# Plan: plans/approved/personal/2026-04-24-subagent-identity-leak-fix.md T1

set -uo pipefail

NEUTRAL_NAME="Duongntd"
NEUTRAL_EMAIL="103487096+Duongntd@users.noreply.github.com"

# Read stdin into a variable
INPUT="$(cat)"

# Extract tool_name
TOOL_NAME="$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || true)"

if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

# Extract command
COMMAND="$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || true)"

# Only act on git commit commands
if ! printf '%s' "$COMMAND" | grep -qE '(^|[[:space:]])git([[:space:]]+-[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)'; then
  exit 0
fi

# Resolve effective cwd: try tool_input.cwd then fall back to $PWD
CWD="$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('cwd',''))" 2>/dev/null || true)"
if [ -z "$CWD" ]; then
  CWD="${PWD:-}"
fi

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  exit 0
fi

# Check work-scope
ORIGIN="$(git -C "$CWD" remote get-url origin 2>/dev/null || true)"
if [ -z "$ORIGIN" ]; then
  exit 0
fi

if ! printf '%s' "$ORIGIN" | grep -qE '[:/]missmp/'; then
  exit 0
fi

# Work-scope: enforce neutral identity
if ! git -C "$CWD" config --local user.name "$NEUTRAL_NAME" 2>/dev/null; then
  printf '{"decision":"block","reason":"[identity-guard] Failed to set user.name in work-scope worktree — commit blocked to prevent identity leak."}\n'
  exit 2
fi

if ! git -C "$CWD" config --local user.email "$NEUTRAL_EMAIL" 2>/dev/null; then
  printf '{"decision":"block","reason":"[identity-guard] Failed to set user.email in work-scope worktree — commit blocked to prevent identity leak."}\n'
  exit 2
fi

# Success — config rewritten, proceed silently
exit 0
