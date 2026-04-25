#!/usr/bin/env bash
# test-coordinator-identity-leak.sh
# Regression: Test 1 — no parent-shell leak after sourcing launcher.
#
# Plan: plans/approved/personal/2026-04-25-coordinator-identity-leak-watcher-fix.md
# The leak channel: user sources the launcher script (`. launch-evelynn.sh` or
# copy-pastes it into the shell), and STRAWBERRY_AGENT / CLAUDE_AGENT_NAME persist
# in the interactive shell after the script finishes. The fix wraps the body in a
# subshell so even when sourced the exports do not survive.
#
# XFAIL: Will fail until Task 4 (subshell-isolated launchers) is implemented.
# POSIX-portable bash (Rule 10).
set -eu

REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || REPO="$(pwd)"

TMPDIR_WORK="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR_WORK"; }
trap cleanup EXIT

# Build a fixture repo dir structure so the launcher's REPO_DIR resolves correctly.
# Launcher uses: REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
# So we place the launcher at: $TMPDIR_WORK/scripts/mac/launch-evelynn-test.sh
# Which makes REPO_DIR resolve to: $TMPDIR_WORK
FIXTURE_SCRIPTS_MAC="$TMPDIR_WORK/scripts/mac"
mkdir -p "$FIXTURE_SCRIPTS_MAC"

LAUNCHER_SRC="$REPO/scripts/mac/launch-evelynn.sh"
LAUNCHER_TEST="$FIXTURE_SCRIPTS_MAC/launch-evelynn-test.sh"

# Patch: replace 'exec claude ...' with 'true' so we don't actually launch claude.
sed 's/exec claude .*/true/' "$LAUNCHER_SRC" > "$LAUNCHER_TEST"
chmod +x "$LAUNCHER_TEST"

unset STRAWBERRY_AGENT CLAUDE_AGENT_NAME 2>/dev/null || true

# ── Part A: env-leak check via dot-sourcing ──────────────────────────────────
# Source the launcher in a child bash process and verify the outer shell doesn't
# inherit STRAWBERRY_AGENT / CLAUDE_AGENT_NAME (subshell wrapping fix).
# Note: when sourced, $0 is 'bash' so REPO_DIR resolves incorrectly (expected;
# users would normally execute not source). We still verify no env leak occurs.
child_output="$(bash -c "
  unset STRAWBERRY_AGENT CLAUDE_AGENT_NAME 2>/dev/null
  . '$LAUNCHER_TEST' 2>/dev/null || true
  echo \"STRAWBERRY_AGENT=\${STRAWBERRY_AGENT:-EMPTY}\"
  echo \"CLAUDE_AGENT_NAME=\${CLAUDE_AGENT_NAME:-EMPTY}\"
")"

strawberry_after="$(printf '%s\n' "$child_output" | grep 'STRAWBERRY_AGENT=' | sed 's/STRAWBERRY_AGENT=//')"
agent_after="$(printf '%s\n' "$child_output" | grep 'CLAUDE_AGENT_NAME=' | sed 's/CLAUDE_AGENT_NAME=//')"

if [ "$strawberry_after" != "EMPTY" ]; then
  printf 'FAIL: sourcing launcher leaked STRAWBERRY_AGENT=%s to outer shell\n' "$strawberry_after" >&2
  printf '(expected EMPTY — subshell wrapping should prevent env leak)\n' >&2
  exit 1
fi

if [ "$agent_after" != "EMPTY" ]; then
  printf 'FAIL: sourcing launcher leaked CLAUDE_AGENT_NAME=%s to outer shell\n' "$agent_after" >&2
  printf '(expected EMPTY — subshell wrapping should prevent env leak)\n' >&2
  exit 1
fi

printf 'PASS: no env leak from sourced launcher to outer shell\n'

# ── Part B: .coordinator-identity written on direct execution ─────────────────
# When executed directly (not sourced), REPO_DIR resolves via dirname($0).
# Run the patched launcher directly and verify the identity file is written.
bash "$LAUNCHER_TEST" 2>/dev/null || true

IDENTITY_FILE="$TMPDIR_WORK/.coordinator-identity"
if [ -f "$IDENTITY_FILE" ]; then
  identity_content="$(cat "$IDENTITY_FILE")"
  if [ "$identity_content" != "Evelynn" ]; then
    printf 'FAIL: .coordinator-identity contains "%s", expected "Evelynn"\n' "$identity_content" >&2
    exit 1
  fi
  printf 'PASS: .coordinator-identity written correctly on direct execute\n'
else
  printf 'FAIL: .coordinator-identity not written by launcher on direct execute\n' >&2
  exit 1
fi

exit 0
