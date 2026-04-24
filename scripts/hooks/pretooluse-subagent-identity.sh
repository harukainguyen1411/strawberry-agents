#!/usr/bin/env bash
# scripts/hooks/pretooluse-subagent-identity.sh
#
# PreToolUse Bash hook: enforce neutral git author identity on ALL subagent worktrees.
#
# Universalises the former pretooluse-work-scope-identity.sh (which was scoped
# to [:/]missmp/ origins only). This hook fires on every "git commit" Bash
# dispatch regardless of repo origin — personal-concern and work-scope worktrees
# are both covered.
#
# When a Bash tool call contains "git commit" and the effective cwd is a git
# repo, this hook rewrites the per-worktree git config to Duong's canonical
# noreply identity:
#   user.name  = Duongntd
#   user.email = 103487096+Duongntd@users.noreply.github.com
#
# Orianna carve-out:
#   If CLAUDE_AGENT_NAME=Orianna OR agent_type resolves to "orianna", the hook
#   exits 0 silently without rewriting. Orianna is the sole deliberate exception
#   whose plan-promotion commits author as orianna@strawberry.local (per
#   .claude/agents/orianna.md). Her commits land only on strawberry-agents main
#   and never reach a work-repo PR.
#
# This is fail-closed: if the config write fails, the hook emits a block JSON
# and exits 2 so the commit does not proceed. Non-git-commit commands and
# non-git-repo cwds pass through silently (exit 0).
#
# Input : JSON on stdin (Claude PreToolUse contract)
# Output: JSON block decision on failure; nothing on pass
# Exit  : 0 = proceed, 2 = block
#
# POSIX-portable bash per Rule 10.
# Plan: plans/approved/personal/2026-04-24-subagent-git-identity-as-duong.md T2
# Supersedes: scripts/hooks/pretooluse-work-scope-identity.sh (work-scope only)

set -uo pipefail

NEUTRAL_NAME="Duongntd"
NEUTRAL_EMAIL="103487096+Duongntd@users.noreply.github.com"

# Fail-closed helper: emit block JSON and exit 2
block() {
  printf '{"decision":"block","reason":"[identity-guard] %s"}\n' "$1"
  exit 2
}

# Orianna exemption: exit 0 silently if identity resolves to Orianna.
# Resolution order mirrors the plan-lifecycle guard: CLAUDE_AGENT_NAME env var first.
if [ "${CLAUDE_AGENT_NAME:-}" = "Orianna" ] || [ "${STRAWBERRY_AGENT:-}" = "Orianna" ]; then
  exit 0
fi

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

# Detect git commit: allow any non-separator tokens between 'git' and 'commit'
# (handles: git -c user.name=X commit, git -C /path commit, git commit, etc.)
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

# Check if cwd is inside a git repo (exit 0 if not — no origin required)
if ! git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# Universal: enforce neutral identity on all git repos (no origin gate)
if ! git -C "$CWD" config --local user.name "$NEUTRAL_NAME" 2>/dev/null; then
  printf '{"decision":"block","reason":"[identity-guard] Failed to set user.name in worktree — commit blocked to prevent identity leak."}\n'
  exit 2
fi

if ! git -C "$CWD" config --local user.email "$NEUTRAL_EMAIL" 2>/dev/null; then
  printf '{"decision":"block","reason":"[identity-guard] Failed to set user.email in worktree — commit blocked to prevent identity leak."}\n'
  exit 2
fi

# Success — config rewritten, proceed silently
exit 0
