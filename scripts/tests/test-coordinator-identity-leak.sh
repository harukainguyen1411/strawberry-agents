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

# Patch the launcher: replace 'exec claude ...' with 'true' so we don't launch claude.
LAUNCHER_SRC="$REPO/scripts/mac/launch-evelynn.sh"
LAUNCHER_TEST="$TMPDIR_WORK/launch-evelynn-test.sh"
sed 's/exec claude .*/true/' "$LAUNCHER_SRC" > "$LAUNCHER_TEST"
chmod +x "$LAUNCHER_TEST"

# Test: source the launcher in a subshell context and check what leaks to parent.
# We run this in a child bash process that sources the script, then emits its own env.
# The child exits — the question is whether the PARENT (this script) sees the vars.

unset STRAWBERRY_AGENT CLAUDE_AGENT_NAME 2>/dev/null || true

# Source inside a child bash process and emit env values back to us.
# This simulates: a user opens terminal, types `. launch-evelynn.sh`, exits claude.
# After exit the shell still has STRAWBERRY_AGENT set — next claude launch inherits it.
#
# With the fix (subshell wrapping), sourcing sets vars only inside the subshell,
# so the outer shell (here: the child bash -c process) never sees them.
child_output="$(bash -c "
  unset STRAWBERRY_AGENT CLAUDE_AGENT_NAME 2>/dev/null
  # Source the launcher (simulating '. launch-evelynn.sh' in interactive shell)
  . '$LAUNCHER_TEST' 2>/dev/null || true
  echo \"STRAWBERRY_AGENT=\${STRAWBERRY_AGENT:-EMPTY}\"
  echo \"CLAUDE_AGENT_NAME=\${CLAUDE_AGENT_NAME:-EMPTY}\"
")"

# With subshell wrapping in the launcher, sourcing it should NOT export vars
# into the sourcing shell's environment (vars stay confined in the inner subshell).
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

# Sanity: verify the .coordinator-identity file was written by the launcher.
# After the fix, the launcher writes .coordinator-identity before exec claude.
IDENTITY_FILE="$REPO/.coordinator-identity"
if [ -f "$IDENTITY_FILE" ]; then
  identity_content="$(cat "$IDENTITY_FILE")"
  if [ "$identity_content" != "Evelynn" ]; then
    printf 'FAIL: .coordinator-identity contains "%s", expected "Evelynn"\n' "$identity_content" >&2
    exit 1
  fi
  printf 'PASS: .coordinator-identity written correctly\n'
else
  printf 'FAIL: .coordinator-identity not written by launcher\n' >&2
  exit 1
fi

printf 'PASS: no env leak from sourced launcher to outer shell\n'
exit 0
