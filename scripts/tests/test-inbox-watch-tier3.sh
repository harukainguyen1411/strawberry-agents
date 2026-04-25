#!/usr/bin/env bash
# test-inbox-watch-tier3.sh
# Regression: Test 2 — Monitor-spawned watcher resolves identity via .coordinator-identity
# file when no env vars are set.
#
# Plan: plans/approved/personal/2026-04-25-coordinator-identity-leak-watcher-fix.md
# Test case: With STRAWBERRY_AGENT and CLAUDE_AGENT_NAME unset, watcher must resolve
# identity from .coordinator-identity file and emit INBOX: lines for pending messages.
#
# XFAIL: Will fail until Task 1 (Tier 3 file fallback in inbox-watch.sh) is implemented.
# POSIX-portable bash (Rule 10).
set -eu

REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || REPO="$(pwd)"

TMPDIR_WORK="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR_WORK"; }
trap cleanup EXIT

# Set up a fixture repo structure
FIXTURE_REPO="$TMPDIR_WORK/repo"
mkdir -p "$FIXTURE_REPO/agents/evelynn/inbox"

# Write .coordinator-identity file (Tier 3 source)
printf 'Evelynn' > "$FIXTURE_REPO/.coordinator-identity"

# Write a fixture pending inbox message
cat > "$FIXTURE_REPO/agents/evelynn/inbox/2026-04-25-test-message.md" <<'EOF'
---
from: karma
to: evelynn
priority: high
status: pending
---
Test inbox message for watcher regression.
EOF

# Run inbox-watch.sh in oneshot mode with NO env vars set, but with hint file
output="$(
  unset STRAWBERRY_AGENT CLAUDE_AGENT_NAME 2>/dev/null || true
  REPO_ROOT="$FIXTURE_REPO" INBOX_WATCH_ONESHOT=1 bash "$REPO/scripts/hooks/inbox-watch.sh" 2>/dev/null
)"

if printf '%s\n' "$output" | grep -q 'INBOX:'; then
  printf 'PASS: watcher resolved identity from .coordinator-identity and emitted INBOX line\n'
  exit 0
else
  printf 'FAIL: watcher did not emit any INBOX: lines\n' >&2
  printf 'output was: "%s"\n' "$output" >&2
  printf '(expected: watcher reads .coordinator-identity Tier 3 fallback — not yet implemented)\n' >&2
  exit 1
fi
