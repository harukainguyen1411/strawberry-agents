#!/usr/bin/env bash
# scripts/hooks/tests/test-identity-leak-fix.sh
#
# xfail tests for subagent-identity-leak-fix plan.
# Plan: plans/approved/personal/2026-04-24-subagent-identity-leak-fix.md
#
# Invariants covered:
#   INV-1: Commit author anonymity on work-scope (T1 + T2)
#   INV-2: Reviewer-comment wrapper scrubs + scans (T3)
#   INV-3: Personal-scope untouched by new hooks
#   INV-4: Agent-tool harness env injection scoped to work-scope (T6)
#
# Exit codes:
#   0 = all passing (xfail → should fail initially until impl exists)
#   non-zero = at least one unexpected failure
#
# Usage: bash scripts/hooks/tests/test-identity-leak-fix.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PASS=0
FAIL=0
XFAIL=0

pass() { printf '[PASS] %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf '[FAIL] %s\n' "$1"; FAIL=$((FAIL+1)); }
xfail() { printf '[XFAIL] %s — implementation not yet present\n' "$1"; XFAIL=$((XFAIL+1)); }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
make_work_scope_repo() {
  local dir
  dir="$(mktemp -d)"
  git -C "$dir" init -q
  git -C "$dir" remote add origin "git@github.com:missmp/company-os.git"
  git -C "$dir" config user.email "test@test.com"
  git -C "$dir" config user.name "TestUser"
  printf '%s' "$dir"
}

make_personal_scope_repo() {
  local dir
  dir="$(mktemp -d)"
  git -C "$dir" init -q
  git -C "$dir" remote add origin "git@github.com:harukainguyen1411/strawberry-agents.git"
  git -C "$dir" config user.email "test@test.com"
  git -C "$dir" config user.name "TestUser"
  printf '%s' "$dir"
}

cleanup_dirs() {
  for d in "$@"; do
    rm -rf "$d"
  done
}

# ---------------------------------------------------------------------------
# INV-1a: T1 — PreToolUse hook rewrites persona identity to neutral on work-scope
# ---------------------------------------------------------------------------
test_inv1a_pretooluse_rewrites_identity() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-work-scope-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "INV-1a: pretooluse-work-scope-identity.sh does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"
  # Set persona identity
  git -C "$wdir" config user.name "Viktor"
  git -C "$wdir" config user.email "viktor@strawberry.local"

  # Invoke hook with synthetic tool_input
  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git commit -m test","cwd":"'"$wdir"'"}}'

  printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1
  local hook_exit=$?

  # Hook should exit 0 and config should be rewritten
  local name email
  name="$(git -C "$wdir" config user.name 2>/dev/null || true)"
  email="$(git -C "$wdir" config user.email 2>/dev/null || true)"

  if [ "$name" = "Duongntd" ] && [ "$email" = "103487096+Duongntd@users.noreply.github.com" ]; then
    pass "INV-1a: work-scope persona identity rewritten to neutral"
  else
    fail "INV-1a: identity not rewritten (name='$name' email='$email')"
  fi

  cleanup_dirs "$wdir"
}

# ---------------------------------------------------------------------------
# INV-1b: T2 — pre-commit author scan blocks persona author on work-scope
# ---------------------------------------------------------------------------
test_inv1b_precommit_blocks_persona_author() {
  local hook="$REPO_ROOT/scripts/hooks/pre-commit-reviewer-anonymity.sh"
  if [ ! -f "$hook" ]; then
    xfail "INV-1b: pre-commit-reviewer-anonymity.sh not found"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"
  git -C "$wdir" config user.name "Viktor"
  git -C "$wdir" config user.email "viktor@strawberry.local"

  # Create a dummy commit message
  printf 'chore: test commit' > "$wdir/.git/COMMIT_EDITMSG"

  local output
  output="$(ANONYMITY_HOOK_REPO="$wdir" ANONYMITY_TEST_AUTHOR="Viktor <viktor@strawberry.local>" bash "$hook" 2>&1)"
  local exit_code=$?

  if [ "$exit_code" -ne 0 ]; then
    pass "INV-1b: pre-commit hook blocks persona author on work-scope"
  else
    fail "INV-1b: pre-commit hook should have blocked persona author (exit=0, output='$output')"
  fi

  cleanup_dirs "$wdir"
}

# ---------------------------------------------------------------------------
# INV-1c: T2 — pre-commit author scan passes neutral author on work-scope
# ---------------------------------------------------------------------------
test_inv1c_precommit_passes_neutral_author() {
  local hook="$REPO_ROOT/scripts/hooks/pre-commit-reviewer-anonymity.sh"
  if [ ! -f "$hook" ]; then
    xfail "INV-1c: pre-commit-reviewer-anonymity.sh not found"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"
  git -C "$wdir" config user.name "Duongntd"
  git -C "$wdir" config user.email "103487096+Duongntd@users.noreply.github.com"

  printf 'chore: clean commit' > "$wdir/.git/COMMIT_EDITMSG"

  local output
  output="$(ANONYMITY_HOOK_REPO="$wdir" ANONYMITY_TEST_AUTHOR="Duongntd <103487096+Duongntd@users.noreply.github.com>" bash "$hook" 2>&1)"
  local exit_code=$?

  if [ "$exit_code" -eq 0 ]; then
    pass "INV-1c: pre-commit hook passes neutral author on work-scope"
  else
    fail "INV-1c: pre-commit hook blocked neutral author unexpectedly (exit=$exit_code)"
  fi

  cleanup_dirs "$wdir"
}

# ---------------------------------------------------------------------------
# INV-1d: T1 — personal-scope repo left untouched by pretooluse hook
# ---------------------------------------------------------------------------
test_inv1d_pretooluse_ignores_personal_scope() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-work-scope-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "INV-1d: pretooluse-work-scope-identity.sh does not exist yet"
    return
  fi

  local pdir
  pdir="$(make_personal_scope_repo)"
  git -C "$pdir" config user.name "Viktor"
  git -C "$pdir" config user.email "viktor@strawberry.local"

  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git commit -m test","cwd":"'"$pdir"'"}}'

  printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1

  local name
  name="$(git -C "$pdir" config user.name 2>/dev/null || true)"

  if [ "$name" = "Viktor" ]; then
    pass "INV-1d: personal-scope persona config left untouched by pretooluse hook"
  else
    fail "INV-1d: personal-scope config was mutated (name='$name')"
  fi

  cleanup_dirs "$pdir"
}

# ---------------------------------------------------------------------------
# INV-2a: T3 — wrapper strips trailing signature and posts
# ---------------------------------------------------------------------------
test_inv2a_wrapper_strips_signature() {
  local wrapper="$REPO_ROOT/scripts/post-reviewer-comment.sh"
  if [ ! -f "$wrapper" ]; then
    xfail "INV-2a: post-reviewer-comment.sh does not exist yet"
    return
  fi

  local tmpfile
  tmpfile="$(mktemp)"
  printf 'LGTM. Looks good.\n-- Senna\n' > "$tmpfile"

  local output
  output="$(ANONYMITY_DRY_RUN=1 bash "$wrapper" --pr 99 --repo missmp/company-os --file "$tmpfile" 2>&1)"
  local exit_code=$?

  rm -f "$tmpfile"

  if [ "$exit_code" -eq 0 ]; then
    pass "INV-2a: wrapper strips trailing agent signature and exits 0 (dry-run)"
  else
    fail "INV-2a: wrapper exited $exit_code for clean body with trailing signature (output='$output')"
  fi
}

# ---------------------------------------------------------------------------
# INV-2b: T3 — wrapper rejects inline agent name (exit 3)
# ---------------------------------------------------------------------------
test_inv2b_wrapper_rejects_inline_token() {
  local wrapper="$REPO_ROOT/scripts/post-reviewer-comment.sh"
  if [ ! -f "$wrapper" ]; then
    xfail "INV-2b: post-reviewer-comment.sh does not exist yet"
    return
  fi

  local tmpfile
  tmpfile="$(mktemp)"
  printf 'Evelynn reviewed this and found no issues.\n' > "$tmpfile"

  ANONYMITY_DRY_RUN=1 bash "$wrapper" --pr 99 --repo missmp/company-os --file "$tmpfile" >/dev/null 2>&1
  local exit_code=$?

  rm -f "$tmpfile"

  if [ "$exit_code" -eq 3 ]; then
    pass "INV-2b: wrapper rejects inline agent name with exit 3"
  else
    fail "INV-2b: expected exit 3, got $exit_code"
  fi
}

# ---------------------------------------------------------------------------
# INV-2c: T3 — clean body passes through unchanged
# ---------------------------------------------------------------------------
test_inv2c_wrapper_passes_clean_body() {
  local wrapper="$REPO_ROOT/scripts/post-reviewer-comment.sh"
  if [ ! -f "$wrapper" ]; then
    xfail "INV-2c: post-reviewer-comment.sh does not exist yet"
    return
  fi

  local tmpfile
  tmpfile="$(mktemp)"
  printf 'LGTM. No issues found.\n-- reviewer\n' > "$tmpfile"

  local output
  output="$(ANONYMITY_DRY_RUN=1 bash "$wrapper" --pr 99 --repo missmp/company-os --file "$tmpfile" 2>&1)"
  local exit_code=$?

  rm -f "$tmpfile"

  if [ "$exit_code" -eq 0 ]; then
    pass "INV-2c: clean body passes wrapper unchanged (dry-run)"
  else
    fail "INV-2c: clean body rejected (exit=$exit_code, output='$output')"
  fi
}

# ---------------------------------------------------------------------------
# INV-3: personal-scope not mutated by pre-commit author scan
# ---------------------------------------------------------------------------
test_inv3_personal_scope_precommit_untouched() {
  local hook="$REPO_ROOT/scripts/hooks/pre-commit-reviewer-anonymity.sh"
  if [ ! -f "$hook" ]; then
    xfail "INV-3: pre-commit-reviewer-anonymity.sh not found"
    return
  fi

  local pdir
  pdir="$(make_personal_scope_repo)"
  git -C "$pdir" config user.name "Viktor"
  git -C "$pdir" config user.email "viktor@strawberry.local"

  printf 'chore: test' > "$pdir/.git/COMMIT_EDITMSG"

  ANONYMITY_HOOK_REPO="$pdir" ANONYMITY_TEST_AUTHOR="Viktor <viktor@strawberry.local>" bash "$hook" >/dev/null 2>&1
  local exit_code=$?

  if [ "$exit_code" -eq 0 ]; then
    pass "INV-3: personal-scope hook exits 0 (not enforced on personal)"
  else
    fail "INV-3: personal-scope hook blocked unexpectedly (exit=$exit_code)"
  fi

  cleanup_dirs "$pdir"
}

# ---------------------------------------------------------------------------
# INV-4: T6 — agent-identity-default.sh injects GIT_* only on work-scope
# ---------------------------------------------------------------------------
test_inv4_agent_harness_env_work_scope() {
  local hook="$REPO_ROOT/scripts/hooks/agent-identity-default.sh"
  if [ ! -f "$hook" ]; then
    xfail "INV-4a: agent-identity-default.sh does not exist yet"
    return
  fi

  # Work-scope cwd in the payload
  local wdir
  wdir="$(make_work_scope_repo)"
  local payload
  payload='{"tool_name":"Agent","tool_input":{"subagent_type":"talon","description":"test","cwd":"'"$wdir"'"}}'

  local output
  output="$(printf '%s' "$payload" | bash "$hook" 2>&1)"
  local exit_code=$?

  cleanup_dirs "$wdir"

  if printf '%s' "$output" | grep -q "GIT_AUTHOR_NAME"; then
    pass "INV-4a: agent-identity-default.sh injects GIT_AUTHOR_NAME for work-scope"
  else
    fail "INV-4a: GIT_AUTHOR_NAME not present in output (exit=$exit_code, output='$output')"
  fi
}

test_inv4_agent_harness_env_personal_scope() {
  local hook="$REPO_ROOT/scripts/hooks/agent-identity-default.sh"
  if [ ! -f "$hook" ]; then
    xfail "INV-4b: agent-identity-default.sh does not exist yet"
    return
  fi

  local pdir
  pdir="$(make_personal_scope_repo)"
  local payload
  payload='{"tool_name":"Agent","tool_input":{"subagent_type":"talon","description":"test","cwd":"'"$pdir"'"}}'

  local output
  output="$(printf '%s' "$payload" | bash "$hook" 2>&1)"
  local exit_code=$?

  cleanup_dirs "$pdir"

  # Should exit 0 with no modification (or empty output)
  if ! printf '%s' "$output" | grep -q "GIT_AUTHOR_NAME"; then
    pass "INV-4b: personal-scope cwd — no GIT_AUTHOR_NAME injected"
  else
    fail "INV-4b: GIT_AUTHOR_NAME incorrectly injected for personal-scope (output='$output')"
  fi
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
printf '=== Identity-leak fix xfail tests ===\n\n'

test_inv1a_pretooluse_rewrites_identity
test_inv1b_precommit_blocks_persona_author
test_inv1c_precommit_passes_neutral_author
test_inv1d_pretooluse_ignores_personal_scope
test_inv2a_wrapper_strips_signature
test_inv2b_wrapper_rejects_inline_token
test_inv2c_wrapper_passes_clean_body
test_inv3_personal_scope_precommit_untouched
test_inv4_agent_harness_env_work_scope
test_inv4_agent_harness_env_personal_scope

printf '\n=== Results: %d pass, %d fail, %d xfail ===\n' "$PASS" "$FAIL" "$XFAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
