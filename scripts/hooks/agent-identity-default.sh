#!/usr/bin/env bash
# scripts/hooks/agent-identity-default.sh
#
# PreToolUse Agent hook: inject work-scope git identity env vars into Agent
# tool dispatches when the target cwd resolves to a work-scope origin.
#
# When the Agent tool dispatches a subagent and tool_input.cwd (or the current
# PWD) resolves to a work-scope git repo (origin matches [:/]missmp/), this
# hook injects:
#   GIT_AUTHOR_NAME    = Duongntd
#   GIT_AUTHOR_EMAIL   = 103487096+Duongntd@users.noreply.github.com
#   GIT_COMMITTER_NAME = Duongntd
#   GIT_COMMITTER_EMAIL= 103487096+Duongntd@users.noreply.github.com
#
# into the tool_input.env map. This catches any commit path that bypasses the
# per-worktree config (e.g. fresh clone inside the subagent process).
#
# Non-work-scope dispatches are passed through unchanged (exit 0, no output).
#
# Input : JSON on stdin (Claude PreToolUse contract)
# Output: JSON mutation decision (tool_input.env populated) or nothing
# Exit  : 0 always (non-blocking; T1+T2 remain the hard gates)
#
# POSIX-portable bash per Rule 10.
# Plan: plans/approved/personal/2026-04-24-subagent-identity-leak-fix.md T6

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
export REPO_ROOT

SCRIPT_FILE="$(mktemp)"
trap 'rm -f "$SCRIPT_FILE"' EXIT

cat > "$SCRIPT_FILE" <<'PY'
import json, os, subprocess, sys

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

# Resolve effective cwd
cwd = ti.get("cwd") or os.environ.get("PWD") or ""
if not cwd or not os.path.isdir(cwd):
    sys.exit(0)

# Check work-scope
try:
    origin = subprocess.check_output(
        ["git", "-C", cwd, "remote", "get-url", "origin"],
        stderr=subprocess.DEVNULL
    ).decode().strip()
except Exception:
    origin = ""

import re
if not origin or not re.search(r'[:/]missmp/', origin):
    sys.exit(0)

# Work-scope: inject neutral identity env vars
neutral_env = {
    "GIT_AUTHOR_NAME":    "Duongntd",
    "GIT_AUTHOR_EMAIL":   "103487096+Duongntd@users.noreply.github.com",
    "GIT_COMMITTER_NAME": "Duongntd",
    "GIT_COMMITTER_EMAIL":"103487096+Duongntd@users.noreply.github.com",
}

existing_env = ti.get("env") or {}
if isinstance(existing_env, dict):
    merged = {**neutral_env, **existing_env}  # existing values win (don't override explicit caller intent)
else:
    merged = neutral_env

ti["env"] = merged
d["tool_input"] = ti

print(json.dumps({"tool_input": ti}))
sys.exit(0)
PY

python3 "$SCRIPT_FILE"
