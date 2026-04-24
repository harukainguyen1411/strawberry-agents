#!/usr/bin/env bash
# PreToolUse Agent hook: inject isolation=worktree for every subagent dispatch
# UNLESS the caller supplied isolation explicitly, the subagent is in the opt-out
# allowlist, the subagent's frontmatter declares default_isolation: none, or this
# hook is itself running inside a git worktree (nested-dispatch guard).
#
# Input: JSON on stdin (Claude PreToolUse contract).
# Output: a JSON decision object that mutates tool_input.isolation, or nothing
# (exit 0) to pass the input through unchanged.
#
# Portability: POSIX-ish bash + python3 (already a repo dep via other hooks).
# ADR: plans/approved/personal/2026-04-24-universal-worktree-isolation.md
# Supersedes: 2026-04-23-subagent-worktree-and-edit-only.md opt-in regime.
#
# Opt-in frontmatter (default_isolation: worktree) on aphelios/kayn/xayah/caitlyn
# is now a no-op documentation hint — the hook's default already isolates everyone.
# Leave frontmatter in place per ADR §Migration.

set -eu

# Allow REPO_ROOT override from environment (used by tests to inject fixture agent paths).
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export REPO_ROOT

# ── Nested-dispatch guard (INV-4) ─────────────────────────────────────────────
# If this hook is running inside a worktree, do NOT inject isolation for children.
# Subagents spawned by a worktree-based agent would cause doubly-nested worktrees,
# which the harness cannot handle (see ADR §Nested-dispatch policy).
#
# Detection: git rev-parse --git-dir returns the worktree-specific path, while
# --git-common-dir returns the shared common .git dir. They differ iff we are in
# a worktree.
_git_dir="$(git rev-parse --git-dir 2>/dev/null || true)"
_git_common_dir="$(git rev-parse --git-common-dir 2>/dev/null || true)"
if [ -n "$_git_dir" ] && [ -n "$_git_common_dir" ] && [ "$_git_dir" != "$_git_common_dir" ]; then
    # Running inside a worktree — skip injection.
    exit 0
fi
unset _git_dir _git_common_dir

SCRIPT_FILE="$(mktemp)"
trap 'rm -f "$SCRIPT_FILE"' EXIT

cat > "$SCRIPT_FILE" <<'PY'
import json, os, re, sys

# Opt-out allowlist: agents where worktree isolation is pointless overhead.
# ADR §Opt-out set — 2026-04-24-universal-worktree-isolation.md:
#   skarner — read-only memory excavator (post-2026-04-24 Write/Edit retired).
#   orianna — script-only plan promoter; never Agent-tool invocable. Listed
#              defensively — never reaches this hook via Agent dispatch.
OPT_OUT = {"skarner", "orianna"}

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

# If caller already supplied an isolation value, never overwrite (INV-3).
iso = ti.get("isolation")
if iso:
    sys.exit(0)

# Opt-out allowlist check (INV-2, INV-7).
if subagent in OPT_OUT:
    sys.exit(0)

# Frontmatter check: honor default_isolation: none (INV-5).
# Also accept legacy default_isolation: worktree as a no-op documentation hint
# (ADR §Migration — redundant with the new default but harmless).
repo = os.environ.get("REPO_ROOT", ".")
candidates = [
    os.path.join(repo, ".claude", "agents", subagent + ".md"),
    os.path.join(repo, ".claude", "_script-only-agents", subagent + ".md"),
]
def_path = next((p for p in candidates if os.path.isfile(p)), None)

if def_path:
    with open(def_path, "r", encoding="utf-8") as fh:
        body = fh.read()

    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", body, re.DOTALL)
    if m:
        fm = m.group(1)
        val = None
        for line in fm.splitlines():
            mm = re.match(r"^\s*default_isolation:\s*(\S+)\s*$", line)
            if mm:
                val = mm.group(1).strip().strip('"').strip("'")
                break

        if val == "none":
            # Explicit frontmatter opt-out (INV-5).
            sys.exit(0)
        elif val is not None and val != "worktree":
            sys.stderr.write(
                "[agent-default-isolation] ignoring unsupported default_isolation=%r for %s\n"
                % (val, subagent)
            )
        # val == "worktree" → inject (legacy no-op hint; same as default behavior).
        # val is None → inject (universal default).

# Inject isolation=worktree (INV-1, INV-8).
new_ti = dict(ti)
new_ti["isolation"] = "worktree"
out = {
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
    },
    "systemMessage": (
        "auto-isolation: injected isolation=worktree for subagent '%s' "
        "(universal opt-out regime — ADR 2026-04-24-universal-worktree-isolation)" % subagent
    ),
    "tool_input": new_ti,
}
print(json.dumps(out))
PY

python3 "$SCRIPT_FILE"
