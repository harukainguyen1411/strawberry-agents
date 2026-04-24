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

# Fail-closed helper: emit block JSON and exit 2
block() {
  printf '{"decision":"block","reason":"[identity-guard] %s"}\n' "$1"
  exit 2
}

# Read stdin into a variable
INPUT="$(cat)"

# Fail-closed: require python3 to be available
if ! command -v python3 >/dev/null 2>&1; then
  block "python3 not found — cannot parse PreToolUse JSON; commit blocked to prevent identity leak."
fi

# Extract tool_name (fail-closed on parse error)
TOOL_NAME="$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)" || block "JSON parse failure on tool_name — commit blocked to prevent identity leak."

if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

# Extract command (fail-closed on parse error)
COMMAND="$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)" || block "JSON parse failure on command — commit blocked to prevent identity leak."

# Detect git commit: look for a git invocation containing 'commit' as the subcommand.
# The old regex only accepted dash-prefixed tokens between 'git' and 'commit', missing:
#   git -c user.name=Viktor commit  (positional after -c has no dash)
#   git -C /path commit             (-C takes a path arg with no dash)
# Fix: allow any non-separator tokens between 'git' and 'commit'.
# Pattern: git followed by zero-or-more non-separator tokens, then standalone 'commit'.
if ! printf '%s' "$COMMAND" | grep -qE '(^|[[:space:];|&])git([[:space:]]+[^;|&[:space:]]+)*[[:space:]]+commit([[:space:]]|$)'; then
  exit 0
fi

# Resolve effective cwd: try tool_input.cwd then fall back to $PWD
CWD="$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('cwd',''))" 2>/dev/null)" || block "JSON parse failure on cwd — commit blocked to prevent identity leak."
if [ -z "$CWD" ]; then
  CWD="${PWD:-}"
fi

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  exit 0
fi

# Check work-scope (fail-closed: if we cannot read origin, block)
ORIGIN="$(git -C "$CWD" remote get-url origin 2>/dev/null)" || {
  # No origin or git error — not a work repo; pass through
  exit 0
}
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
