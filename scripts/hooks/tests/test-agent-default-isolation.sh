#!/usr/bin/env bash
# Tests for scripts/hooks/agent-default-isolation.sh (PreToolUse Agent hook).
# Plan: plans/proposed/personal/2026-04-23-subagent-worktree-and-edit-only.md
# Covers INV-1: auto-isolation fires for whitelisted subagent types (default_isolation: worktree frontmatter present),
# and is a no-op for non-whitelisted subagents.
set -eu

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK="$REPO_ROOT/scripts/hooks/agent-default-isolation.sh"

PASS=0
FAIL=0

fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }

if [ ! -x "$HOOK" ]; then
  fail "hook script $HOOK not present or not executable"
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# Helper: run the hook with a fake Agent tool_input JSON and capture stdout.
run_hook() {
  subagent="$1"
  extra="$2"
  # extra is an optional extra key/value pair to splice into tool_input (e.g., "\"isolation\":\"none\"").
  if [ -n "$extra" ]; then
    input="{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"$subagent\",$extra}}"
  else
    input="{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"$subagent\"}}"
  fi
  echo "$input" | bash "$HOOK" 2>/dev/null || true
}

# INV-1a: whitelisted subagents get isolation injected.
for agent in aphelios kayn xayah caitlyn; do
  out="$(run_hook "$agent" "")"
  if echo "$out" | grep -q '"isolation"[[:space:]]*:[[:space:]]*"worktree"'; then
    pass "$agent — injects isolation=worktree when unset"
  else
    fail "$agent — expected isolation=worktree injection; got: $out"
  fi
done

# INV-1b: non-whitelisted subagent (yuumi) does not mutate.
out="$(run_hook yuumi "")"
if echo "$out" | grep -q '"isolation"'; then
  fail "yuumi — unexpected isolation mutation; got: $out"
else
  pass "yuumi — no mutation (non-whitelisted, no frontmatter field)"
fi

# INV-1c: explicit isolation already set is preserved (no overwrite).
out="$(run_hook aphelios "\"isolation\":\"none\"")"
if echo "$out" | grep -q '"isolation"[[:space:]]*:[[:space:]]*"worktree"'; then
  fail "aphelios with explicit isolation=none — hook overwrote explicit value; got: $out"
else
  pass "aphelios with explicit isolation=none — preserved (no overwrite)"
fi

echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
