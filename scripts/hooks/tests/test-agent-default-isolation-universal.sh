#!/usr/bin/env bash
# xfail against current opt-in hook; passes after C3 flip.
#
# Tests for scripts/hooks/agent-default-isolation.sh — universal opt-out regime.
# ADR: plans/approved/personal/2026-04-24-universal-worktree-isolation.md
#
# Covers:
#   INV-1 — Default isolation injected for non-opt-out subagents
#            (ekko, yuumi, lissandra, akali, and three planners).
#   INV-2 — Opt-out agent (skarner) passes through with no mutation.
#   INV-3 — Explicit caller isolation is never overridden.
#   INV-5 — default_isolation: none frontmatter is honored.
#   INV-7 — Skarner spawn produces no isolation injection.
#   INV-8 — Yuumi spawn produces isolation=worktree injection.
#
# These tests MUST FAIL against the current opt-in hook (C2 state).
# They will PASS after the C3 hook flip from opt-in to opt-out.

set -eu

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK="$REPO_ROOT/scripts/hooks/agent-default-isolation.sh"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

if [ ! -x "$HOOK" ]; then
    fail "hook script $HOOK not present or not executable"
    echo "Results: $PASS passed, $FAIL failed"
    exit 1
fi

# Helper: run the hook with a fake Agent tool_input JSON and return stdout.
# Args: <subagent> [extra-kv-json]  (extra-kv-json appended inside tool_input)
run_hook() {
    _subagent="$1"
    _extra="${2:-}"
    if [ -n "$_extra" ]; then
        _input="{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"$_subagent\",$_extra}}"
    else
        _input="{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"$_subagent\"}}"
    fi
    printf '%s' "$_input" | bash "$HOOK" 2>/dev/null || true
}

# Helper: assert that hook output contains isolation=worktree
assert_isolation_injected() {
    _label="$1"
    _out="$2"
    # ADR §INV-1, INV-8: isolation: "worktree" must appear in mutation output.
    if printf '%s' "$_out" | grep -q '"isolation"[[:space:]]*:[[:space:]]*"worktree"'; then
        pass "$_label — isolation=worktree injected"
    else
        fail "$_label — expected isolation=worktree injection; got: $_out"
    fi
}

# Helper: assert that hook output contains NO isolation mutation
assert_no_mutation() {
    _label="$1"
    _out="$2"
    if printf '%s' "$_out" | grep -q '"isolation"'; then
        fail "$_label — unexpected isolation mutation; got: $_out"
    else
        pass "$_label — no mutation (correct)"
    fi
}

# ── INV-1: universal default isolation for non-opt-out subagents ───────────────
# ADR §INV-1: feed tool_input for ekko, yuumi, lissandra, akali, and three
# planners; assert isolation=worktree is injected for each.
# XFAIL against current opt-in hook: these agents have no default_isolation: worktree
# frontmatter, so the current hook will NOT inject isolation. After C3 flip the
# hook injects by default for all non-opt-out agents.

for _agent in ekko yuumi lissandra akali swain azir kayn; do
    _out="$(run_hook "$_agent" "")"
    # INV-1 reference: ADR §INV-1 — Default isolation applies to any non-opt-out subagent.
    assert_isolation_injected "INV-1 $_agent" "$_out"
    unset _out
done
unset _agent

# ── INV-2 / INV-7: skarner is in opt-out set — no mutation ────────────────────
# ADR §INV-2 / INV-7: skarner is read-only; the hook must NOT inject isolation.

_out="$(run_hook skarner "")"
# INV-2 reference: ADR §INV-2 — Opt-out agents pass through untouched.
assert_no_mutation "INV-2/INV-7 skarner" "$_out"
unset _out

# ── INV-3: explicit caller isolation wins — no overwrite ───────────────────────
# ADR §INV-3: feed yuumi + isolation: "none" — hook must not mutate to "worktree".

_out="$(run_hook yuumi '"isolation":"none"')"
# INV-3 reference: ADR §INV-3 — Explicit caller isolation is never overridden.
if printf '%s' "$_out" | grep -q '"isolation"[[:space:]]*:[[:space:]]*"worktree"'; then
    fail "INV-3 yuumi+explicit-none — hook overwrote explicit isolation=none; got: $_out"
else
    pass "INV-3 yuumi+explicit-none — caller isolation preserved"
fi
unset _out

# ── INV-5: default_isolation: none frontmatter is honored ─────────────────────
# Create a fixture agent def with default_isolation: none in a temp REPO_ROOT.
# ADR §INV-5: the hook must NOT inject isolation when frontmatter opts out.

TMPDIR_FIXTURE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FIXTURE"' EXIT
mkdir -p "$TMPDIR_FIXTURE/.claude/agents"
cat > "$TMPDIR_FIXTURE/.claude/agents/fixture-none-agent.md" <<'AGEOF'
---
model: sonnet
default_isolation: none
---
# fixture-none-agent — used by test-agent-default-isolation-universal.sh INV-5
AGEOF

_fixture_input="{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"fixture-none-agent\"}}"
_out="$(REPO_ROOT="$TMPDIR_FIXTURE" printf '%s' "$_fixture_input" | bash "$HOOK" 2>/dev/null || true)"
# INV-5 reference: ADR §INV-5 — default_isolation: none frontmatter is honored.
assert_no_mutation "INV-5 fixture-none-agent (default_isolation: none)" "$_out"
unset _fixture_input _out

# ── INV-8: yuumi spawn produces isolation=worktree ────────────────────────────
# Behavioral mirror of INV-1 for yuumi specifically.
# ADR §INV-8: yuumi (an errand-runner that commits) must be isolated.

_out="$(run_hook yuumi "")"
# INV-8 reference: ADR §INV-8 — Yuumi spawn produces a worktree.
assert_isolation_injected "INV-8 yuumi" "$_out"
unset _out

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo "(Expected: all FAIL against current opt-in hook; all PASS after C3 flip)"
[ "$FAIL" -eq 0 ]
