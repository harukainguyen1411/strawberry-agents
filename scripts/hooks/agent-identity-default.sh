#!/usr/bin/env bash
# scripts/hooks/agent-identity-default.sh
#
# PreToolUse Agent hook: inject neutral git identity env vars into ALL Agent
# tool dispatches, regardless of repo origin (universal, both concerns).
#
# When the Agent tool dispatches a subagent, this hook injects:
#   GIT_AUTHOR_NAME    = Duongntd
#   GIT_AUTHOR_EMAIL   = 103487096+Duongntd@users.noreply.github.com
#   GIT_COMMITTER_NAME = Duongntd
#   GIT_COMMITTER_EMAIL= 103487096+Duongntd@users.noreply.github.com
#
# into the tool_input.env map. This catches any commit path that bypasses the
# per-worktree config (e.g. fresh clone inside the subagent process).
# Covers personal-concern and work-scope worktrees alike.
#
# Orianna carve-out:
#   If CLAUDE_AGENT_NAME=Orianna OR STRAWBERRY_AGENT=Orianna, the hook exits 0
#   without injecting. Orianna is the sole deliberate exception whose plan-
#   promotion commits author as orianna@strawberry.local (per
#   .claude/agents/orianna.md line 21). Her commits land only on
#   strawberry-agents main and never reach a work-repo PR.
#
# Env-merge precedence: neutral identity wins — {**existing_env, **neutral_env}.
# This ensures persona GIT_AUTHOR_* values from the caller never override the
# neutral identity. (Prior bug: {**neutral_env, **existing_env} let existing win,
# silently no-oping when a caller pre-populated an agent email.)
#
# Input : JSON on stdin (Claude PreToolUse contract)
# Output: JSON mutation decision (tool_input.env populated) or nothing
# Exit  : 0 always (non-blocking; pretooluse-subagent-identity.sh is the hard gate)
#
# POSIX-portable bash per Rule 10.
# Plan: plans/approved/personal/2026-04-24-subagent-git-identity-as-duong.md T2

set -uo pipefail

# Orianna exemption (shell-level fast path)
if [ "${CLAUDE_AGENT_NAME:-}" = "Orianna" ] || [ "${STRAWBERRY_AGENT:-}" = "Orianna" ]; then
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
export REPO_ROOT

SCRIPT_FILE="$(mktemp)"
trap 'rm -f "$SCRIPT_FILE"' EXIT

cat > "$SCRIPT_FILE" <<'PY'
import json, os, subprocess, sys, re

# Orianna exemption at Python level too (in case env propagation differs)
if os.environ.get("CLAUDE_AGENT_NAME") == "Orianna" or os.environ.get("STRAWBERRY_AGENT") == "Orianna":
    sys.exit(0)

raw = sys.stdin.read()
if not raw.strip():
    sys.exit(0)

try:
    d = json.loads(raw)
except Exception:
    sys.exit(0)

tool_name = d.get("tool_name") or ""
ti = d.get("tool_input") or {}

if tool_name != "Agent" or not isinstance(ti, dict):
    sys.exit(0)

# Orianna exemption via dispatch subagent_type / prompt content (belt-and-braces)
subagent_type = (ti.get("subagent_type") or "").lower()
if subagent_type == "orianna":
    sys.exit(0)

# Resolve effective cwd — no origin gate; universal across both concerns
cwd = ti.get("cwd") or os.environ.get("PWD") or ""
# If cwd is not provided or not a directory, still inject — the subagent
# may determine its own cwd. Injection is safe: neutral identity overwrites
# any persona value but is itself overridable by explicit Duong noreply values.
# We proceed regardless.

# Neutral identity
neutral_env = {
    "GIT_AUTHOR_NAME":     "Duongntd",
    "GIT_AUTHOR_EMAIL":    "103487096+Duongntd@users.noreply.github.com",
    "GIT_COMMITTER_NAME":  "Duongntd",
    "GIT_COMMITTER_EMAIL": "103487096+Duongntd@users.noreply.github.com",
}

existing_env = ti.get("env") or {}
if isinstance(existing_env, dict):
    # Neutral wins: {**existing_env, **neutral_env}
    # Caller-supplied GIT_AUTHOR_* values are overridden by neutral identity.
    # This is the deliberate fix for the precedence bug (prior: existing won).
    merged = {**existing_env, **neutral_env}
else:
    merged = neutral_env

ti["env"] = merged
d["tool_input"] = ti

print(json.dumps({"tool_input": ti}))
sys.exit(0)
PY

python3 "$SCRIPT_FILE"
