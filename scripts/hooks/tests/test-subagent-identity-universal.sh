#!/usr/bin/env bash
# scripts/hooks/tests/test-subagent-identity-universal.sh
#
# xfail test: subagent worktree commit must author as Duong (universal, both concerns)
# Plan: plans/approved/personal/2026-04-24-subagent-git-identity-as-duong.md
#
# Three-case matrix:
#   CASE-1: personal-concern worktree (no missmp/ origin) — hook must rewrite identity
#   CASE-2: work-scope worktree (missmp/ origin) — regression: hook still rewrites identity
#   CASE-3: cwd with no git origin — hook must exit 0 silently (not block)
#
# Additional:
#   ORIANNA: CLAUDE_AGENT_NAME=Orianna — hook must exit 0 (exempt)
#   ENV-MERGE: agent-identity-default.sh neutral identity wins over caller-supplied GIT_AUTHOR_*
#
# Exit: 0 = all pass, 1 = at least one failure
# Usage: bash scripts/hooks/tests/test-subagent-identity-universal.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PASS=0
FAIL=0
XFAIL=0

pass()  { printf '[PASS]  %s\n' "$1"; PASS=$((PASS+1)); }
fail()  { printf '[FAIL]  %s\n' "$1"; FAIL=$((FAIL+1)); }
xfail() { printf '[XFAIL] %s\n' "$1"; XFAIL=$((XFAIL+1)); }

HOOK="$REPO_ROOT/scripts/hooks/pretooluse-subagent-identity.sh"
AGENT_ENV_HOOK="$REPO_ROOT/scripts/hooks/agent-identity-default.sh"

NEUTRAL_EMAIL="103487096+Duongntd@users.noreply.github.com"
NEUTRAL_NAME="Duongntd"

make_personal_repo() {
  local dir
  dir="$(mktemp -d)"
  git -C "$dir" init -q
  git -C "$dir" remote add origin "git@github.com:harukainguyen1411/strawberry-agents.git"
  git -C "$dir" config user.name "Viktor"
  git -C "$dir" config user.email "viktor@strawberry.local"
  printf '%s' "$dir"
}

make_work_scope_repo() {
  local dir
  dir="$(mktemp -d)"
  git -C "$dir" init -q
  git -C "$dir" remote add origin "git@github.com:missmp/company-os.git"
  git -C "$dir" config user.name "Viktor"
  git -C "$dir" config user.email "viktor@strawberry.local"
  printf '%s' "$dir"
}

make_no_origin_repo() {
  local dir
  dir="$(mktemp -d)"
  git -C "$dir" init -q
  git -C "$dir" config user.name "Viktor"
  git -C "$dir" config user.email "viktor@strawberry.local"
  printf '%s' "$dir"
}

cleanup() { rm -rf "$@"; }

# ---------------------------------------------------------------------------
# CASE-1: personal-concern worktree — hook must rewrite identity
# (xfails against current codebase: hook is named pretooluse-work-scope-identity.sh
#  and gates on missmp/ only, so personal-scope is not covered)
# ---------------------------------------------------------------------------
test_case1_personal_concern_rewritten() {
  if [ ! -f "$HOOK" ]; then
    xfail "CASE-1: pretooluse-subagent-identity.sh does not exist yet (current file is pretooluse-work-scope-identity.sh with missmp/ gate)"
    return
  fi

  local dir
  dir="$(make_personal_repo)"
  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git commit -m test","cwd":"'"$dir"'"}}'

  printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>&1

  local email name
  email="$(git -C "$dir" config user.email 2>/dev/null || true)"
  name="$(git -C "$dir" config user.name 2>/dev/null || true)"
  cleanup "$dir"

  if [ "$email" = "$NEUTRAL_EMAIL" ] && [ "$name" = "$NEUTRAL_NAME" ]; then
    pass "CASE-1: personal-concern worktree identity rewritten to Duong"
  else
    fail "CASE-1: personal-concern identity NOT rewritten (name='$name' email='$email')"
  fi
}

# ---------------------------------------------------------------------------
# CASE-2: work-scope worktree (missmp/) — regression: still rewrites
# ---------------------------------------------------------------------------
test_case2_work_scope_still_rewritten() {
  if [ ! -f "$HOOK" ]; then
    xfail "CASE-2: pretooluse-subagent-identity.sh does not exist yet"
    return
  fi

  local dir
  dir="$(make_work_scope_repo)"
  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git commit -m test","cwd":"'"$dir"'"}}'

  printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>&1

  local email name
  email="$(git -C "$dir" config user.email 2>/dev/null || true)"
  name="$(git -C "$dir" config user.name 2>/dev/null || true)"
  cleanup "$dir"

  if [ "$email" = "$NEUTRAL_EMAIL" ] && [ "$name" = "$NEUTRAL_NAME" ]; then
    pass "CASE-2: work-scope worktree identity rewritten to Duong (regression OK)"
  else
    fail "CASE-2: work-scope identity NOT rewritten (name='$name' email='$email')"
  fi
}

# ---------------------------------------------------------------------------
# CASE-3: no git origin — hook must exit 0 silently, not block
# ---------------------------------------------------------------------------
test_case3_no_origin_pass_through() {
  if [ ! -f "$HOOK" ]; then
    xfail "CASE-3: pretooluse-subagent-identity.sh does not exist yet"
    return
  fi

  local dir
  dir="$(make_no_origin_repo)"
  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git commit -m test","cwd":"'"$dir"'"}}'

  local exit_code
  printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>&1
  exit_code=$?
  cleanup "$dir"

  if [ "$exit_code" -eq 0 ]; then
    pass "CASE-3: no-origin cwd exits 0 silently"
  else
    fail "CASE-3: no-origin cwd blocked (exit=$exit_code)"
  fi
}

# ---------------------------------------------------------------------------
# ORIANNA: CLAUDE_AGENT_NAME=Orianna — hook must exit 0 (exempt)
# ---------------------------------------------------------------------------
test_orianna_exempt() {
  if [ ! -f "$HOOK" ]; then
    xfail "ORIANNA: pretooluse-subagent-identity.sh does not exist yet"
    return
  fi

  local dir
  dir="$(make_personal_repo)"
  local payload
  payload='{"tool_name":"Bash","tool_input":{"command":"git commit -m test","cwd":"'"$dir"'"}}'

  # Hook must not rewrite when CLAUDE_AGENT_NAME=Orianna
  CLAUDE_AGENT_NAME=Orianna printf '%s' "$payload" | CLAUDE_AGENT_NAME=Orianna bash "$HOOK" >/dev/null 2>&1

  local email
  email="$(git -C "$dir" config user.email 2>/dev/null || true)"
  cleanup "$dir"

  if [ "$email" = "viktor@strawberry.local" ]; then
    pass "ORIANNA: Orianna exempt — identity NOT rewritten"
  else
    fail "ORIANNA: Orianna identity was rewritten (email='$email'); exemption not working"
  fi
}

# ---------------------------------------------------------------------------
# ENV-MERGE: agent-identity-default.sh neutral wins over caller-supplied GIT_AUTHOR_*
# (xfails against current codebase: merge is {**neutral_env, **existing_env} — existing wins)
# ---------------------------------------------------------------------------
test_env_merge_neutral_wins() {
  if [ ! -f "$AGENT_ENV_HOOK" ]; then
    xfail "ENV-MERGE: agent-identity-default.sh does not exist yet"
    return
  fi

  local dir
  dir="$(make_personal_repo)"
  # Caller pre-populates a persona GIT_AUTHOR_EMAIL in the dispatch env
  local payload
  payload='{"tool_name":"Agent","tool_input":{"subagent_type":"talon","description":"test","cwd":"'"$dir"'","env":{"GIT_AUTHOR_NAME":"Viktor","GIT_AUTHOR_EMAIL":"viktor@strawberry.local"}}}'

  local output
  output="$(printf '%s' "$payload" | bash "$AGENT_ENV_HOOK" 2>&1)"
  cleanup "$dir"

  local author_email
  author_email="$(printf '%s' "$output" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('env', {}).get('GIT_AUTHOR_EMAIL', ''))
except Exception:
    print('')
" 2>/dev/null || true)"

  if [ "$author_email" = "$NEUTRAL_EMAIL" ]; then
    pass "ENV-MERGE: neutral identity wins over caller-supplied GIT_AUTHOR_EMAIL"
  else
    xfail "ENV-MERGE: caller GIT_AUTHOR_EMAIL wins over neutral (got '$author_email') — precedence bug present"
  fi
}

# ---------------------------------------------------------------------------
# ENV-MERGE-PERSONAL: agent-identity-default.sh injects for personal-scope too
# (xfails against current: missmp/ gate blocks personal-scope injection)
# ---------------------------------------------------------------------------
test_env_merge_personal_scope_injected() {
  if [ ! -f "$AGENT_ENV_HOOK" ]; then
    xfail "ENV-MERGE-PERSONAL: agent-identity-default.sh does not exist yet"
    return
  fi

  local dir
  dir="$(make_personal_repo)"
  local payload
  payload='{"tool_name":"Agent","tool_input":{"subagent_type":"talon","description":"test","cwd":"'"$dir"'"}}'

  local output
  output="$(printf '%s' "$payload" | bash "$AGENT_ENV_HOOK" 2>&1)"
  cleanup "$dir"

  local author_email
  author_email="$(printf '%s' "$output" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('env', {}).get('GIT_AUTHOR_EMAIL', ''))
except Exception:
    print('')
" 2>/dev/null || true)"

  if [ "$author_email" = "$NEUTRAL_EMAIL" ]; then
    pass "ENV-MERGE-PERSONAL: GIT_AUTHOR_EMAIL injected for personal-scope"
  else
    xfail "ENV-MERGE-PERSONAL: personal-scope not injected (got '$author_email') — missmp/ gate blocks personal-scope"
  fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
printf '=== test-subagent-identity-universal.sh ===\n\n'

test_case1_personal_concern_rewritten
test_case2_work_scope_still_rewritten
test_case3_no_origin_pass_through
test_orianna_exempt
test_env_merge_neutral_wins
test_env_merge_personal_scope_injected

printf '\n=== Results: %d pass, %d fail, %d xfail ===\n' "$PASS" "$FAIL" "$XFAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
