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
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "INV-1a: pretooluse-subagent-identity.sh does not exist yet"
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
# INV-1d: T2 — personal-scope repo gets neutral identity rewritten by universal hook
# ---------------------------------------------------------------------------
test_inv1d_pretooluse_rewrites_personal_scope() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "INV-1d: pretooluse-subagent-identity.sh does not exist yet"
    return
  fi

  local pdir
  pdir="$(make_personal_scope_repo)"
  git -C "$pdir" config user.name "Viktor"
  git -C "$pdir" config user.email "viktor@strawberry.local"

  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git commit -m test","cwd":"'"$pdir"'"}}'

  printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1

  local name email
  name="$(git -C "$pdir" config user.name 2>/dev/null || true)"
  email="$(git -C "$pdir" config user.email 2>/dev/null || true)"

  # Universal promise: personal-scope subagents also commit as Duong, not as persona.
  if [ "$name" = "Duongntd" ] && [ "$email" = "103487096+Duongntd@users.noreply.github.com" ]; then
    pass "INV-1d: personal-scope persona identity rewritten to neutral Duong (universal hook)"
  else
    fail "INV-1d: personal-scope identity not rewritten (name='$name' email='$email')"
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

  # Universal injection (plan 2026-04-24-subagent-git-identity-as-duong.md):
  # personal-scope dispatches now also get neutral identity injected.
  if printf '%s' "$output" | grep -q "GIT_AUTHOR_NAME"; then
    pass "INV-4b: personal-scope cwd — GIT_AUTHOR_NAME injected (universal behaviour)"
  else
    fail "INV-4b: GIT_AUTHOR_NAME not injected for personal-scope (output='$output')"
  fi
}

# ---------------------------------------------------------------------------
# C1-REGRESSION: INV-1a bypass via -c KEY=VAL positional arg
# Senna PR#35 review: regex misses git -c user.name=Viktor commit
# ---------------------------------------------------------------------------
test_c1_bypass_dash_c_key_val() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
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

  local exit_code
  printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1
  exit_code=$?

  cleanup_dirs "$wdir"

  # New behavior: hook BLOCKS (exit 2) on @strawberry.local email in -c override
  if [ "$exit_code" -eq 2 ]; then
    pass "C1-bypass1: git -c user.name/email=persona commit — blocked at PreToolUse layer (exit 2)"
  else
    fail "C1-bypass1 (REGRESSION): git -c KEY=VAL commit bypasses hook (exit=$exit_code, expected 2)"
  fi
}

# ---------------------------------------------------------------------------
# C1-REGRESSION: INV-1a bypass via -C /path positional arg
# ---------------------------------------------------------------------------
test_c1_bypass_dash_C_path() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
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
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
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

  local exit_code
  printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1
  exit_code=$?

  cleanup_dirs "$wdir"

  # With BP-3 name-blocking: -c user.name=Viktor must be BLOCKED (exit 2) at PreToolUse layer.
  # Prior behavior was to rewrite config; stricter behavior is to block outright.
  if [ "$exit_code" -eq 2 ]; then
    pass "C1-bypass3: git -c user.name=Persona -C /path commit — blocked at PreToolUse layer (exit 2)"
  else
    fail "C1-bypass3 (REGRESSION): combined -c user.name=Persona + -C commit not blocked (exit=$exit_code)"
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
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
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
# Senna C1: git -c user.email=persona@strawberry.local commit — hook must BLOCK
# (inline -c overrides local config; hook must detect and reject at PreToolUse layer)
# ---------------------------------------------------------------------------
test_senna_c1_inline_c_email_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "Senna-C1: pretooluse-subagent-identity.sh does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git -c user.email=viktor@strawberry.local commit -m msg","cwd":"'"$wdir"'"}}'

  local output exit_code
  output="$(printf '%s' "$payload" | bash "$hook" 2>&1)"
  exit_code=$?

  cleanup_dirs "$wdir"

  # Hook must BLOCK (exit 2) to prevent inline -c email bypass
  if [ "$exit_code" -eq 2 ]; then
    pass "Senna-C1: git -c user.email=persona@... commit blocked at PreToolUse layer"
  else
    fail "Senna-C1 (BYPASS): git -c user.email=persona@... commit not blocked (exit=$exit_code, output='$output')"
  fi
}

# ---------------------------------------------------------------------------
# Senna C2: GIT_AUTHOR_EMAIL=persona@strawberry.local git commit — hook must BLOCK
# (env var override wins over local config; hook must detect at PreToolUse layer)
# ---------------------------------------------------------------------------
test_senna_c2_env_var_email_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "Senna-C2: pretooluse-subagent-identity.sh does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"GIT_AUTHOR_EMAIL=viktor@strawberry.local git commit -m msg","cwd":"'"$wdir"'"}}'

  local output exit_code
  output="$(printf '%s' "$payload" | bash "$hook" 2>&1)"
  exit_code=$?

  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "Senna-C2: GIT_AUTHOR_EMAIL=persona@... git commit blocked at PreToolUse layer"
  else
    fail "Senna-C2 (BYPASS): GIT_AUTHOR_EMAIL=persona@... git commit not blocked (exit=$exit_code, output='$output')"
  fi
}

# ---------------------------------------------------------------------------
# Senna C3: git commit --author="Viktor <viktor@strawberry.local>" — hook must BLOCK
# (explicit --author flag wins over local config)
# ---------------------------------------------------------------------------
test_senna_c3_author_flag_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "Senna-C3: pretooluse-subagent-identity.sh does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git commit --author=\"Viktor <viktor@strawberry.local>\" -m msg","cwd":"'"$wdir"'"}}'

  local output exit_code
  output="$(printf '%s' "$payload" | bash "$hook" 2>&1)"
  exit_code=$?

  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "Senna-C3: git commit --author=persona blocked at PreToolUse layer"
  else
    fail "Senna-C3 (BYPASS): git commit --author=persona not blocked (exit=$exit_code, output='$output')"
  fi
}

# ---------------------------------------------------------------------------
# Senna I3: empty stdin → pass-through (exit 0), not fail-closed block
# (hook should not block when there is no PreToolUse payload — graceful degradation)
# ---------------------------------------------------------------------------
test_senna_i3_empty_stdin_passthrough() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "Senna-I3: pretooluse-subagent-identity.sh does not exist yet"
    return
  fi

  local output exit_code
  output="$(printf '' | bash "$hook" 2>&1)"
  exit_code=$?

  if [ "$exit_code" -eq 0 ]; then
    pass "Senna-I3: empty stdin → pass-through (exit 0), not over-aggressive block"
  else
    fail "Senna-I3: empty stdin caused exit $exit_code (expected 0 pass-through, output='$output')"
  fi
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# BP-1: git -c "user.email=viktor@strawberry.local" commit (QUOTED -c value)
# Senna round 3: literal quote between -c and user. defeats prior regex
# ---------------------------------------------------------------------------
test_bp1_quoted_dash_c_email_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "BP-1: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  # Double-quoted form: -c "user.email=viktor@strawberry.local"
  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git -c \"user.email=viktor@strawberry.local\" commit -m msg","cwd":"'"$wdir"'"}}'

  local output exit_code
  output="$(printf '%s' "$payload" | bash "$hook" 2>&1)"
  exit_code=$?
  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "BP-1 (double-quoted -c email): git -c \"user.email=persona@...\" commit blocked"
  else
    fail "BP-1 (BYPASS): git -c \"user.email=persona@...\" commit NOT blocked (exit=$exit_code)"
  fi
}

test_bp1_single_quoted_dash_c_email_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "BP-1b: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  # Single-quoted form: -c 'user.email=viktor@strawberry.local'
  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git -c '"'"'user.email=viktor@strawberry.local'"'"' commit -m msg","cwd":"'"$wdir"'"}}'

  local output exit_code
  output="$(printf '%s' "$payload" | bash "$hook" 2>&1)"
  exit_code=$?
  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "BP-1b (single-quoted -c email): git -c 'user.email=persona@...' commit blocked"
  else
    fail "BP-1b (BYPASS): git -c 'user.email=persona@...' commit NOT blocked (exit=$exit_code)"
  fi
}

test_bp1_quoted_dash_c_name_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "BP-1c: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  # Quoted name form: -c "user.name=Viktor"
  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git -c \"user.name=Viktor\" commit -m msg","cwd":"'"$wdir"'"}}'

  local output exit_code
  output="$(printf '%s' "$payload" | bash "$hook" 2>&1)"
  exit_code=$?
  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "BP-1c (quoted -c name): git -c \"user.name=Persona\" commit blocked"
  else
    fail "BP-1c (BYPASS): git -c \"user.name=Persona\" commit NOT blocked (exit=$exit_code)"
  fi
}

# ---------------------------------------------------------------------------
# BP-2: git commit --author "Viktor <viktor@strawberry.local>" (SPACE separator)
# Senna round 3: --author X (space) not caught by --author=.* regex
# ---------------------------------------------------------------------------
test_bp2_author_space_separator_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "BP-2: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  # Space form: --author "Viktor <viktor@strawberry.local>"
  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git commit --author \"Viktor <viktor@strawberry.local>\" -m msg","cwd":"'"$wdir"'"}}'

  local output exit_code
  output="$(printf '%s' "$payload" | bash "$hook" 2>&1)"
  exit_code=$?
  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "BP-2 (--author space form): git commit --author \"Persona <...>\" blocked"
  else
    fail "BP-2 (BYPASS): git commit --author \"Persona <...>\" NOT blocked (exit=$exit_code)"
  fi
}

test_bp2_author_space_name_only_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "BP-2b: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  # Space form with neutral email but persona NAME
  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git commit --author \"Viktor <103487096+Duongntd@users.noreply.github.com>\" -m msg","cwd":"'"$wdir"'"}}'

  local output exit_code
  output="$(printf '%s' "$payload" | bash "$hook" 2>&1)"
  exit_code=$?
  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "BP-2b (--author space, persona name + neutral email): blocked"
  else
    fail "BP-2b (BYPASS): --author with persona name + neutral email NOT blocked (exit=$exit_code)"
  fi
}

# ---------------------------------------------------------------------------
# BP-3: Name-only leak paths
# GIT_AUTHOR_NAME=Viktor (neutral email, persona name)
# GIT_COMMITTER_NAME=Viktor
# -c user.name=Viktor (unquoted, neutral email)
# ---------------------------------------------------------------------------
test_bp3_git_author_name_env_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "BP-3a: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  # GIT_AUTHOR_NAME=Viktor with neutral email (name-only leak)
  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"GIT_AUTHOR_NAME=Viktor git commit -m msg","cwd":"'"$wdir"'"}}'

  local output exit_code
  output="$(printf '%s' "$payload" | bash "$hook" 2>&1)"
  exit_code=$?
  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "BP-3a: GIT_AUTHOR_NAME=Persona git commit blocked"
  else
    fail "BP-3a (BYPASS): GIT_AUTHOR_NAME=Persona git commit NOT blocked (exit=$exit_code)"
  fi
}

test_bp3_git_committer_name_env_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "BP-3b: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"GIT_COMMITTER_NAME=Jayce git commit -m msg","cwd":"'"$wdir"'"}}'

  local output exit_code
  output="$(printf '%s' "$payload" | bash "$hook" 2>&1)"
  exit_code=$?
  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "BP-3b: GIT_COMMITTER_NAME=Persona git commit blocked"
  else
    fail "BP-3b (BYPASS): GIT_COMMITTER_NAME=Persona git commit NOT blocked (exit=$exit_code)"
  fi
}

test_bp3_dash_c_name_unquoted_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "BP-3c: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  # -c user.name=Viktor (no strawberry.local, just persona name)
  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git -c user.name=Viktor commit -m msg","cwd":"'"$wdir"'"}}'

  local output exit_code
  output="$(printf '%s' "$payload" | bash "$hook" 2>&1)"
  exit_code=$?
  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "BP-3c: git -c user.name=Persona commit blocked"
  else
    fail "BP-3c (BYPASS): git -c user.name=Persona commit NOT blocked (exit=$exit_code)"
  fi
}

test_bp3_author_flag_persona_name_neutral_email_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "BP-3d: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  # --author= with persona name but neutral email
  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git commit --author=\"Soraka <103487096+Duongntd@users.noreply.github.com>\" -m msg","cwd":"'"$wdir"'"}}'

  local output exit_code
  output="$(printf '%s' "$payload" | bash "$hook" 2>&1)"
  exit_code=$?
  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "BP-3d: git commit --author=Persona<neutral-email> blocked"
  else
    fail "BP-3d (BYPASS): git commit --author=Persona<neutral-email> NOT blocked (exit=$exit_code)"
  fi
}

# Non-persona neutral --author must PASS (regression guard)
test_bp3_author_neutral_name_passes() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "BP-3e: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git commit --author=\"Duongntd <103487096+Duongntd@users.noreply.github.com>\" -m msg","cwd":"'"$wdir"'"}}'

  local output exit_code
  output="$(printf '%s' "$payload" | bash "$hook" 2>&1)"
  exit_code=$?
  cleanup_dirs "$wdir"

  if [ "$exit_code" -ne 2 ]; then
    pass "BP-3e: git commit --author=Duongntd (neutral) passes hook"
  else
    fail "BP-3e (REGRESSION): neutral --author blocked (exit=2)"
  fi
}

printf '=== Identity-leak fix xfail tests ===\n\n'

test_inv1a_pretooluse_rewrites_identity
test_inv1b_precommit_blocks_persona_author
test_inv1c_precommit_passes_neutral_author
test_inv1d_pretooluse_rewrites_personal_scope
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

# Senna bypass shapes — C1/C2/C3 + I3 empty-stdin
test_senna_c1_inline_c_email_blocked
test_senna_c2_env_var_email_blocked
test_senna_c3_author_flag_blocked
test_senna_i3_empty_stdin_passthrough

# ---------------------------------------------------------------------------
# NEW-BP-1: semicolon/pipe inside quoted -c value defeats token scan
# git -c 'user.email=viktor@strawberry.local;' commit
# git -c 'user.email=viktor@strawberry.local|more'
# ---------------------------------------------------------------------------
test_new_bp1_semicolon_in_quoted_c_email_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "NEW-BP-1a: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  # Semicolon inside quoted -c value — current regex early-terminates on ';'
  local payload exit_code
  payload='{"tool_name":"Bash","tool_input":{"command":"git -c '\''user.email=viktor@strawberry.local;'\'' commit -m msg","cwd":"'"$wdir"'"}}'
  printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1
  exit_code=$?
  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "NEW-BP-1a: git -c 'user.email=persona;' commit blocked (shlex tokenizer)"
  else
    fail "NEW-BP-1a (BYPASS): semicolon in quoted -c email NOT blocked (exit=$exit_code)"
  fi
}

test_new_bp1_pipe_in_quoted_c_email_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "NEW-BP-1b: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  # Pipe inside quoted -c value
  local payload exit_code
  payload='{"tool_name":"Bash","tool_input":{"command":"git -c '\''user.email=viktor@strawberry.local|more'\'' commit -m msg","cwd":"'"$wdir"'"}}'
  printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1
  exit_code=$?
  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "NEW-BP-1b: git -c 'user.email=persona|more' commit blocked (shlex tokenizer)"
  else
    fail "NEW-BP-1b (BYPASS): pipe in quoted -c email NOT blocked (exit=$exit_code)"
  fi
}

# ---------------------------------------------------------------------------
# NEW-BP-2: quote char immediately after = in GIT_AUTHOR_NAME defeats regex anchor
# GIT_AUTHOR_NAME='Viktor Kesler' git commit
# git -c " user.name=Viktor" commit  (leading space in quoted -c value)
# git commit --author=' Viktor <neutral-email>'  (leading space, name-only)
# ---------------------------------------------------------------------------
test_new_bp2_quoted_git_author_name_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "NEW-BP-2a: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  # Quoted multi-word GIT_AUTHOR_NAME — regex requires name immediately after =
  local payload exit_code
  payload='{"tool_name":"Bash","tool_input":{"command":"GIT_AUTHOR_NAME='\''Viktor Kesler'\'' git commit -m msg","cwd":"'"$wdir"'"}}'
  printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1
  exit_code=$?
  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "NEW-BP-2a: GIT_AUTHOR_NAME='Viktor Kesler' git commit blocked (shlex tokenizer)"
  else
    fail "NEW-BP-2a (BYPASS): quoted GIT_AUTHOR_NAME with persona NOT blocked (exit=$exit_code)"
  fi
}

test_new_bp2_leading_space_in_quoted_c_name_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "NEW-BP-2b: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  # Leading space in quoted -c value: git -c " user.name=Viktor" commit
  local payload exit_code
  payload='{"tool_name":"Bash","tool_input":{"command":"git -c \" user.name=Viktor\" commit -m msg","cwd":"'"$wdir"'"}}'
  printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1
  exit_code=$?
  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "NEW-BP-2b: git -c \" user.name=Persona\" commit blocked (shlex tokenizer)"
  else
    fail "NEW-BP-2b (BYPASS): leading space in quoted -c name NOT blocked (exit=$exit_code)"
  fi
}

test_new_bp2_author_leading_space_name_only_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "NEW-BP-2c: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  # --author with leading space inside quoted value, neutral email (name-only bypass)
  local payload exit_code
  payload='{"tool_name":"Bash","tool_input":{"command":"git commit --author='\'' Viktor <103487096+Duongntd@users.noreply.github.com>'\'' -m msg","cwd":"'"$wdir"'"}}'
  printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1
  exit_code=$?
  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "NEW-BP-2c: --author=' Viktor <neutral-email>' blocked (shlex tokenizer, word-boundary name match)"
  else
    fail "NEW-BP-2c (BYPASS): --author with leading space + persona name NOT blocked (exit=$exit_code)"
  fi
}

# ---------------------------------------------------------------------------
# NEW-BP-3: persona name as middle/trailing token in multi-word quoted value
# GIT_AUTHOR_NAME='The Viktor' git commit
# ---------------------------------------------------------------------------
test_new_bp3_persona_as_middle_token_blocked() {
  local hook="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
  if [ ! -f "$hook" ]; then
    xfail "NEW-BP-3: hook does not exist yet"
    return
  fi

  local wdir
  wdir="$(make_work_scope_repo)"

  # Persona name appears after other text in quoted value
  local payload exit_code
  payload='{"tool_name":"Bash","tool_input":{"command":"GIT_AUTHOR_NAME='\''The Viktor'\'' git commit -m msg","cwd":"'"$wdir"'"}}'
  printf '%s' "$payload" | bash "$hook" >/dev/null 2>&1
  exit_code=$?
  cleanup_dirs "$wdir"

  if [ "$exit_code" -eq 2 ]; then
    pass "NEW-BP-3: GIT_AUTHOR_NAME='The Viktor' blocked (shlex tokenizer, word-boundary name match)"
  else
    fail "NEW-BP-3 (BYPASS): persona name as middle token NOT blocked (exit=$exit_code)"
  fi
}

# Senna round-3 bypass shapes — BP-1/BP-2/BP-3
test_bp1_quoted_dash_c_email_blocked
test_bp1_single_quoted_dash_c_email_blocked
test_bp1_quoted_dash_c_name_blocked
test_bp2_author_space_separator_blocked
test_bp2_author_space_name_only_blocked
test_bp3_git_author_name_env_blocked
test_bp3_git_committer_name_env_blocked
test_bp3_dash_c_name_unquoted_blocked
test_bp3_author_flag_persona_name_neutral_email_blocked
test_bp3_author_neutral_name_passes

# Senna round-4 bypass shapes — NEW-BP-1/2/3 (shlex tokenizer required)
test_new_bp1_semicolon_in_quoted_c_email_blocked
test_new_bp1_pipe_in_quoted_c_email_blocked
test_new_bp2_quoted_git_author_name_blocked
test_new_bp2_leading_space_in_quoted_c_name_blocked
test_new_bp2_author_leading_space_name_only_blocked
test_new_bp3_persona_as_middle_token_blocked

printf '\n=== Results: %d pass, %d fail, %d xfail ===\n' "$PASS" "$FAIL" "$XFAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
