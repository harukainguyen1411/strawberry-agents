#!/usr/bin/env bash
# PreToolUse Agent hook: inject isolation=worktree when the target subagent's
# .claude/agents/<name>.md declares `default_isolation: worktree` in its YAML
# frontmatter AND the caller did not set isolation explicitly.
#
# Input: JSON on stdin (Claude PreToolUse contract).
# Output: a JSON decision object that mutates tool_input.isolation, or nothing
# (exit 0) to pass the input through unchanged.
#
# Portability: POSIX-ish bash + python3 (already a repo dep via other hooks).
# Plan: plans/proposed/personal/2026-04-23-subagent-worktree-and-edit-only.md

set -eu

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
export REPO_ROOT

SCRIPT_FILE="$(mktemp)"
trap 'rm -f "$SCRIPT_FILE"' EXIT

cat > "$SCRIPT_FILE" <<'PY'
import json, os, re, sys

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

subagent = ti.get("subagent_type") or ""
if not subagent:
    sys.exit(0)

# If caller already supplied an isolation value, never overwrite.
iso = ti.get("isolation")
if iso:
    sys.exit(0)

repo = os.environ.get("REPO_ROOT", ".")
candidates = [
    os.path.join(repo, ".claude", "agents", subagent + ".md"),
    os.path.join(repo, ".claude", "_script-only-agents", subagent + ".md"),
]
def_path = next((p for p in candidates if os.path.isfile(p)), None)
if not def_path:
    sys.exit(0)

with open(def_path, "r", encoding="utf-8") as fh:
    body = fh.read()

m = re.match(r"^---\s*\n(.*?)\n---\s*\n", body, re.DOTALL)
if not m:
    sys.exit(0)
fm = m.group(1)

val = None
for line in fm.splitlines():
    mm = re.match(r"^\s*default_isolation:\s*(\S+)\s*$", line)
    if mm:
        val = mm.group(1).strip().strip('"').strip("'")
        break

if val != "worktree":
    if val is not None:
        sys.stderr.write(
            "[agent-default-isolation] ignoring unsupported default_isolation=%r for %s\n"
            % (val, subagent)
        )
    sys.exit(0)

new_ti = dict(ti)
new_ti["isolation"] = "worktree"
out = {
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
    },
    "systemMessage": (
        "auto-isolation: injected isolation=worktree for subagent '%s' "
        "(default_isolation: worktree)" % subagent
    ),
    "tool_input": new_ti,
}
print(json.dumps(out))
PY

python3 "$SCRIPT_FILE"
