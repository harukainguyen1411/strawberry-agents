#!/usr/bin/env bash
# test-inbox-watch-scopes-by-env.sh — xfail test for AC-5 / INV-4 / INV-6.
#
# With CLAUDE_AGENT_NAME=Sona set and a test-fixture Sona inbox containing
# a known sentinel message, inbox-watch.sh stdout must contain the Sona
# sentinel and NOT any Evelynn-only sentinel.
#
# XFAIL against C1 HEAD: current chain falls through to .agent=Evelynn
# in .claude/settings.json — Sona's env var IS read (it's step 2), so
# actually this test may already pass in terms of env-var priority, BUT
# the fail-loud path (T11's test) is the real xfail target. This test
# is a tighter regression guard for T12.
#
# Plan: 2026-04-24-coordinator-boot-unification (T12)
# Exit 0 = pass; exit 1 = fail.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WATCHER="$REPO_ROOT/scripts/hooks/inbox-watch.sh"

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; FAIL_COUNT=$((FAIL_COUNT+1)); }
FAIL_COUNT=0

if [ ! -f "$WATCHER" ]; then
  printf '[SKIP] inbox-watch.sh not found\n' >&2
  exit 0
fi

# Build a fixture tree with separate Sona and Evelynn inboxes.
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT INT TERM

mkdir -p "$TMPDIR_TEST/agents/sona/inbox"
mkdir -p "$TMPDIR_TEST/agents/evelynn/inbox"

# Sona sentinel message
cat > "$TMPDIR_TEST/agents/sona/inbox/sona-sentinel.md" <<'EOF'
---
from: azir
to: sona
priority: high
timestamp: 2026-04-24T10:00:00Z
status: pending
---

SONA_SENTINEL_MESSAGE
EOF

# Evelynn sentinel message (must NOT appear in Sona output)
cat > "$TMPDIR_TEST/agents/evelynn/inbox/evelynn-sentinel.md" <<'EOF'
---
from: azir
to: evelynn
priority: high
timestamp: 2026-04-24T10:00:00Z
status: pending
---

EVELYNN_SENTINEL_MESSAGE
EOF

# Run with CLAUDE_AGENT_NAME=Sona
STDOUT="$(INBOX_WATCH_ONESHOT=1 CLAUDE_AGENT_NAME=Sona REPO_ROOT="$TMPDIR_TEST" bash "$WATCHER" 2>/dev/null || true)"

# Assertion 1: Sona sentinel appears in stdout
if printf '%s' "$STDOUT" | grep -q 'sona-sentinel'; then
  pass "Sona sentinel appears in stdout"
else
  fail "Sona sentinel NOT in stdout. Got: $STDOUT"
fi

# Assertion 2: Evelynn sentinel does NOT appear in stdout
if printf '%s' "$STDOUT" | grep -q 'evelynn-sentinel'; then
  fail "Evelynn sentinel INCORRECTLY appears in Sona-scoped output: $STDOUT"
else
  pass "Evelynn sentinel absent from Sona-scoped output"
fi

# Run with CLAUDE_AGENT_NAME=Evelynn — Evelynn sentinel must appear, Sona must not
STDOUT_E="$(INBOX_WATCH_ONESHOT=1 CLAUDE_AGENT_NAME=Evelynn REPO_ROOT="$TMPDIR_TEST" bash "$WATCHER" 2>/dev/null || true)"

if printf '%s' "$STDOUT_E" | grep -q 'evelynn-sentinel'; then
  pass "Evelynn sentinel appears in Evelynn-scoped output"
else
  fail "Evelynn sentinel NOT in Evelynn-scoped output. Got: $STDOUT_E"
fi

if printf '%s' "$STDOUT_E" | grep -q 'sona-sentinel'; then
  fail "Sona sentinel INCORRECTLY appears in Evelynn-scoped output: $STDOUT_E"
else
  pass "Sona sentinel absent from Evelynn-scoped output"
fi

if [ "$FAIL_COUNT" -eq 0 ]; then
  printf '\n[ALL PASS] inbox-watch scope-by-env assertions passed.\n'
  exit 0
else
  printf '\n[FAILURES] %d assertion(s) failed (xfail expected on C1 HEAD).\n' "$FAIL_COUNT" >&2
  exit 1
fi
