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
# C1-REGRESSION: INV-1a bypass via -c KEY=VAL positional arg
# Senna PR#35 review: regex misses git -c user.name=Viktor commit
# ---------------------------------------------------------------------------
test_c1_bypass_dash_c_key_val() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-work-scope-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "C1-bypass1: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"
  git -C "$wdir" config user.name "Viktor"
  git -C "$wdir" config user.email "viktor@strawberry.local"

  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git -c user.name=Viktor -c user.email=viktor@strawberry.local commit -m msg","cwd":"'"$wdir"'"}}'
  printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1

  local name
  name="$(git -C "$wdir" config user.name 2>/dev/null || true)"

  cleanup_dirs "$wdir"

  # XFAIL: current regex misses -c KEY=VAL positional — identity not rewritten
  if [ "$name" = "Duongntd" ]; then
    pass "C1-bypass1: git -c user.name=Viktor commit — identity rewritten to neutral"
  else
    fail "C1-bypass1 (REGRESSION): git -c KEY=VAL commit bypasses hook (name='$name', expected 'Duongntd')"
  fi
}

# ---------------------------------------------------------------------------
# C1-REGRESSION: INV-1a bypass via -C /path positional arg
# ---------------------------------------------------------------------------
test_c1_bypass_dash_C_path() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-work-scope-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "C1-bypass2: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"
  git -C "$wdir" config user.name "Viktor"
  git -C "$wdir" config user.email "viktor@strawberry.local"

  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git -C '"$wdir"' commit -m msg","cwd":"'"$wdir"'"}}'
  printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1

  local name
  name="$(git -C "$wdir" config user.name 2>/dev/null || true)"

  cleanup_dirs "$wdir"

  if [ "$name" = "Duongntd" ]; then
    pass "C1-bypass2: git -C /path commit — identity rewritten to neutral"
  else
    fail "C1-bypass2 (REGRESSION): git -C /path commit bypasses hook (name='$name', expected 'Duongntd')"
  fi
}

# ---------------------------------------------------------------------------
# C1-REGRESSION: combined -c ... -C /path commit
# ---------------------------------------------------------------------------
test_c1_bypass_combined() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-work-scope-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "C1-bypass3: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"
  git -C "$wdir" config user.name "Viktor"
  git -C "$wdir" config user.email "viktor@strawberry.local"

  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git -c user.name=Viktor -C '"$wdir"' commit -m msg","cwd":"'"$wdir"'"}}'
  printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1

  local name
  name="$(git -C "$wdir" config user.name 2>/dev/null || true)"

  cleanup_dirs "$wdir"

  if [ "$name" = "Duongntd" ]; then
    pass "C1-bypass3: git -c ... -C /path commit — identity rewritten to neutral"
  else
    fail "C1-bypass3 (REGRESSION): combined -c + -C commit bypasses hook (name='$name', expected 'Duongntd')"
  fi
}

# ---------------------------------------------------------------------------
# I3: INV-1b — commit-message-body probe (body should not leak persona name)
# ---------------------------------------------------------------------------
test_i3_inv1b_commit_msg_body() {
  local hook="$REPO_ROOT/scripts/hooks/pre-commit-reviewer-anonymity.sh"
  if [ ! -f "$hook" ]; then
    xfail "I3-INV-1b-body: pre-commit-reviewer-anonymity.sh not found"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  # Commit message body containing a persona name — hook should block
  printf 'chore: test\n\nViktor made this change.\n' > "$wdir/.git/COMMIT_EDITMSG"

  local exit_code
  ANONYMITY_HOOK_REPO="$wdir" ANONYMITY_TEST_AUTHOR="Duongntd <103487096+Duongntd@users.noreply.github.com>" \
    bash "$hook" >/dev/null 2>&1
  exit_code=$?

  cleanup_dirs "$wdir"

  if [ "$exit_code" -ne 0 ]; then
    pass "I3-INV-1b-body: pre-commit hook blocks commit message body with persona name"
  else
    fail "I3-INV-1b-body: pre-commit hook allowed persona name in commit message body (exit=0)"
  fi
}

# ---------------------------------------------------------------------------
# I3: INV-2a — read stripped tempfile and assert signature was actually removed
# ---------------------------------------------------------------------------
test_i3_inv2a_signature_actually_removed() {
  local wrapper="$REPO_ROOT/scripts/post-reviewer-comment.sh"
  if [ ! -f "$wrapper" ]; then
    xfail "I3-INV-2a: post-reviewer-comment.sh not found"
    return
  fi

  # We need to intercept the tmpfile content; use a custom ANONYMITY_DRY_RUN approach
  # by capturing dry-run stdout and checking it does NOT contain the signature
  local infile
  infile="$(mktemp)"
  printf 'LGTM. Looks good.\n-- Senna\n' > "$infile"

  # Patch: check that after strip the wrapper does NOT pass "-- Senna" to the scanner
  # We test this by verifying scanner passes (exit 0 means sig was stripped — if not stripped, scanner would block)
  local exit_code
  ANONYMITY_DRY_RUN=1 bash "$wrapper" --pr 99 --repo missmp/company-os --file "$infile" >/dev/null 2>&1
  exit_code=$?

  # Assert the raw input file still has the signature (i.e. we didn't modify it in place)
  local still_has_sig
  if grep -qF -- "-- Senna" "$infile" 2>/dev/null; then
    still_has_sig=1
  else
    still_has_sig=0
  fi

  rm -f "$infile"

  # exit 0 = scan passed = sig was stripped before scan. Input should still have sig (not modified in place).
  if [ "$exit_code" -eq 0 ] && [ "$still_has_sig" -eq 1 ]; then
    pass "I3-INV-2a: signature stripped from tmpfile before scan; input file unchanged"
  else
    fail "I3-INV-2a: signature strip check failed (exit=$exit_code, still_has_sig=$still_has_sig)"
  fi
}

# ---------------------------------------------------------------------------
# I3: INV-2b — sweep full denylist (all 17 agent names + handles + domain + trailer)
# ---------------------------------------------------------------------------
test_i3_inv2b_full_denylist_sweep() {
  local wrapper="$REPO_ROOT/scripts/post-reviewer-comment.sh"
  if [ ! -f "$wrapper" ]; then
    xfail "I3-INV-2b: post-reviewer-comment.sh not found"
    return
  fi

  local all_fail=0
  # All agent names from _ANONYMITY_AGENT_NAMES
  for token in Senna Lucian Evelynn Sona Viktor Jayce Azir Swain Orianna Karma Talon Ekko Heimerdinger Syndra Akali Ahri Ori; do
    local tmpfile exit_code
    tmpfile="$(mktemp)"
    printf 'This mentions %s in the body.\n' "$token" > "$tmpfile"
    ANONYMITY_DRY_RUN=1 bash "$wrapper" --pr 99 --repo missmp/company-os --file "$tmpfile" >/dev/null 2>&1
    exit_code=$?
    rm -f "$tmpfile"
    if [ "$exit_code" -ne 3 ]; then
      fail "I3-INV-2b: agent name '$token' not blocked (exit=$exit_code)"
      all_fail=1
    fi
  done
  # GitHub handles
  for handle in strawberry-reviewers strawberry-reviewers-2 harukainguyen1411 duongntd99; do
    local tmpfile exit_code
    tmpfile="$(mktemp)"
    printf 'Handle: %s was mentioned.\n' "$handle" > "$tmpfile"
    ANONYMITY_DRY_RUN=1 bash "$wrapper" --pr 99 --repo missmp/company-os --file "$tmpfile" >/dev/null 2>&1
    exit_code=$?
    rm -f "$tmpfile"
    if [ "$exit_code" -ne 3 ]; then
      fail "I3-INV-2b: handle '$handle' not blocked (exit=$exit_code)"
      all_fail=1
    fi
  done
  # @anthropic.com domain
  local tmpfile exit_code
  tmpfile="$(mktemp)"
  printf 'Contact: agent@anthropic.com\n' > "$tmpfile"
  ANONYMITY_DRY_RUN=1 bash "$wrapper" --pr 99 --repo missmp/company-os --file "$tmpfile" >/dev/null 2>&1
  exit_code=$?
  rm -f "$tmpfile"
  if [ "$exit_code" -ne 3 ]; then
    fail "I3-INV-2b: @anthropic.com domain not blocked (exit=$exit_code)"
    all_fail=1
  fi
  # Co-Authored-By trailer
  tmpfile="$(mktemp)"
  printf 'Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>\n' > "$tmpfile"
  ANONYMITY_DRY_RUN=1 bash "$wrapper" --pr 99 --repo missmp/company-os --file "$tmpfile" >/dev/null 2>&1
  exit_code=$?
  rm -f "$tmpfile"
  if [ "$exit_code" -ne 3 ]; then
    fail "I3-INV-2b: Co-Authored-By trailer not blocked (exit=$exit_code)"
    all_fail=1
  fi

  if [ "$all_fail" -eq 0 ]; then
    pass "I3-INV-2b: full denylist sweep — all 17 names + 4 handles + domain + trailer blocked"
  fi
}

# ---------------------------------------------------------------------------
# I3: INV-4a — parse JSON and assert tool_input.env.GIT_AUTHOR_NAME == "Duongntd"
# ---------------------------------------------------------------------------
test_i3_inv4a_json_parse_git_author_name() {
  local hook="$REPO_ROOT/scripts/hooks/agent-identity-default.sh"
  if [ ! -f "$hook" ]; then
    xfail "I3-INV-4a: agent-identity-default.sh does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"
  local payload
  payload='{"tool_name":"Agent","tool_input":{"subagent_type":"talon","description":"test","cwd":"'"$wdir"'"}}'

  local output
  output="$(printf '%s' "$payload" | bash "$hook" 2>&1)"

  cleanup_dirs "$wdir"

  # Parse JSON and assert GIT_AUTHOR_NAME == "Duongntd" (not just grep for string)
  local author_name
  author_name="$(printf '%s' "$output" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('env', {}).get('GIT_AUTHOR_NAME', ''))
except Exception:
    print('')
" 2>/dev/null || true)"

  if [ "$author_name" = "Duongntd" ]; then
    pass "I3-INV-4a: JSON parse confirms tool_input.env.GIT_AUTHOR_NAME == 'Duongntd'"
  else
    fail "I3-INV-4a: GIT_AUTHOR_NAME not 'Duongntd' in parsed JSON (got '$author_name', raw output='$output')"
  fi
}

# ---------------------------------------------------------------------------
# I1: fail-closed — missing python3 or JSON parse failure should BLOCK, not pass
# ---------------------------------------------------------------------------
test_i1_failclosed_json_parse_failure() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-work-scope-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "I1-failclosed: hook does not exist yet"
    return
  fi

  # Send malformed JSON that looks like a Bash git commit call but can't be parsed
  local output exit_code
  output="$(printf 'NOT VALID JSON {{{' | bash "$hook" 2>&1)"
  exit_code=$?

  # Fail-closed: should block (exit 2) or at minimum not silently exit 0
  # Current impl: exits 0 (fail-open). This test will FAIL against current impl.
  if [ "$exit_code" -ne 0 ]; then
    pass "I1-failclosed: malformed JSON input does not silently exit 0 (exit=$exit_code)"
  else
    fail "I1-failclosed (REGRESSION): malformed JSON causes silent exit 0 — hook is fail-open on parse error"
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

# C1 regression tests (bypass vectors — must FAIL before regex fix)
test_c1_bypass_dash_c_key_val
test_c1_bypass_dash_C_path
test_c1_bypass_combined

# I3 tightenings
test_i3_inv1b_commit_msg_body
test_i3_inv2a_signature_actually_removed
test_i3_inv2b_full_denylist_sweep
test_i3_inv4a_json_parse_git_author_name

# I1 fail-closed (must FAIL before fix)
test_i1_failclosed_json_parse_failure

printf '\n=== Results: %d pass, %d fail, %d xfail ===\n' "$PASS" "$FAIL" "$XFAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
