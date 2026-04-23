#!/bin/sh
# T8 — Hook authorization tests for Orianna v2 gate regime.
# Plan: plans/in-progress/personal/2026-04-22-orianna-gate-simplification.md §T8
#
# Tests exercise the 6 invariants described in the plan's ## Test plan section.
# Run: bash scripts/hooks/test-orianna-gate-v2.sh
#
# xfail: all tests will fail until T1-T7 implementation is complete.
# Once implementation lands, run again to confirm all pass.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$SCRIPT_DIR/pre-commit-plan-promote-guard.sh"
IDENTITY_FILE="$SCRIPT_DIR/_orianna_identity.txt"
ORIANNA_EMAIL="orianna@strawberry.local"
ADMIN_EMAIL="harukainguyen1411@gmail.com"
GENERIC_EMAIL="agent@example.com"

PASS=0
FAIL=0
XFAIL=0

# Determine if the v2 hook and identity file are in place (implementation done).
IMPLEMENTATION_PRESENT=0
if [ -f "$IDENTITY_FILE" ]; then
  IMPLEMENTATION_PRESENT=1
fi

# ---- helpers ----------------------------------------------------------------

make_repo() {
  r="$(mktemp -d)"
  git -C "$r" init -q
  git -C "$r" -c user.email="test@example.com" -c user.name="Tester" \
    commit --allow-empty -q -m "init"
  mkdir -p "$r/plans/proposed/personal" "$r/plans/approved/personal"
  printf -- '---\nstatus: proposed\ntitle: test\nowner: tester\n---\n\n# Test\n' \
    > "$r/plans/proposed/personal/2026-04-22-test-plan.md"
  git -C "$r" add plans/
  git -C "$r" -c user.email="test@example.com" -c user.name="Tester" \
    commit -q -m "add proposed plan"
  # Copy the identity file into the repo so the hook can find it
  if [ -f "$IDENTITY_FILE" ]; then
    mkdir -p "$r/scripts/hooks"
    cp "$IDENTITY_FILE" "$r/scripts/hooks/_orianna_identity.txt"
  fi
  printf '%s' "$r"
}

run_hook() {
  repo="$1"
  msg="${2:-}"
  author_email="${3:-$GENERIC_EMAIL}"
  if [ -n "$msg" ]; then
    printf '%s\n' "$msg" > "$repo/.git/COMMIT_EDITMSG"
  fi
  GIT_DIR="$repo/.git" \
  GIT_WORK_TREE="$repo" \
  GIT_AUTHOR_EMAIL="$author_email" \
    bash "$HOOK" 2>&1
}

report() {
  status="$1"
  label="$2"
  detail="${3:-}"
  printf '%s  %s\n' "$status" "$label"
  [ -n "$detail" ] && printf '      %s\n' "$detail"
}

# ---- T1: Non-Orianna identity rejected on plan-lifecycle promotion ----------
label="INV-1: non-Orianna author rejected on plan-promote without Promoted-By trailer"
REPO="$(make_repo)"
git -C "$REPO" mv \
  plans/proposed/personal/2026-04-22-test-plan.md \
  plans/approved/personal/2026-04-22-test-plan.md
rc=0
output="$(run_hook "$REPO" "chore: promote plan" "$GENERIC_EMAIL" 2>&1)" || rc=$?
rm -rf "$REPO"
if [ "$IMPLEMENTATION_PRESENT" -eq 1 ]; then
  if [ "$rc" -ne 0 ]; then
    report PASS "$label"
    PASS=$((PASS + 1))
  else
    report FAIL "$label (expected non-zero exit, got 0)"
    FAIL=$((FAIL + 1))
  fi
else
  report XFAIL "$label — identity file not present, v2 hook not implemented"
  XFAIL=$((XFAIL + 1))
fi

# ---- T2: Orianna identity + Promoted-By trailer accepted --------------------
label="INV-2: Orianna identity + Promoted-By: Orianna trailer accepted"
REPO="$(make_repo)"
git -C "$REPO" mv \
  plans/proposed/personal/2026-04-22-test-plan.md \
  plans/approved/personal/2026-04-22-test-plan.md
VALID_MSG="chore: promote plan

Promoted-By: Orianna
Rationale: plan looks good"
rc=0
output="$(run_hook "$REPO" "$VALID_MSG" "$ORIANNA_EMAIL" 2>&1)" || rc=$?
rm -rf "$REPO"
if [ "$IMPLEMENTATION_PRESENT" -eq 1 ]; then
  if [ "$rc" -eq 0 ]; then
    report PASS "$label"
    PASS=$((PASS + 1))
  else
    report FAIL "$label (expected exit 0, got $rc)"
    printf '      output: %s\n' "$output"
    FAIL=$((FAIL + 1))
  fi
else
  report XFAIL "$label — identity file not present, v2 hook not implemented"
  XFAIL=$((XFAIL + 1))
fi

# ---- T3: Trailer forgery caught — non-Orianna with Promoted-By rejected ----
label="INV-3: trailer forgery rejected — non-Orianna author + Promoted-By: Orianna trailer"
REPO="$(make_repo)"
git -C "$REPO" mv \
  plans/proposed/personal/2026-04-22-test-plan.md \
  plans/approved/personal/2026-04-22-test-plan.md
FORGED_MSG="chore: promote plan

Promoted-By: Orianna
Rationale: forged trailer"
rc=0
output="$(run_hook "$REPO" "$FORGED_MSG" "$GENERIC_EMAIL" 2>&1)" || rc=$?
rm -rf "$REPO"
if [ "$IMPLEMENTATION_PRESENT" -eq 1 ]; then
  if [ "$rc" -ne 0 ]; then
    report PASS "$label"
    PASS=$((PASS + 1))
  else
    report FAIL "$label (expected non-zero exit, got 0)"
    FAIL=$((FAIL + 1))
  fi
else
  report XFAIL "$label — identity file not present, v2 hook not implemented"
  XFAIL=$((XFAIL + 1))
fi

# ---- T4: Admin identity allowed regardless of Promoted-By trailer -----------
label="INV-3b: admin identity (harukainguyen1411) allowed without Promoted-By trailer"
REPO="$(make_repo)"
git -C "$REPO" mv \
  plans/proposed/personal/2026-04-22-test-plan.md \
  plans/approved/personal/2026-04-22-test-plan.md
rc=0
output="$(run_hook "$REPO" "chore: promote plan" "$ADMIN_EMAIL" 2>&1)" || rc=$?
rm -rf "$REPO"
if [ "$IMPLEMENTATION_PRESENT" -eq 1 ]; then
  if [ "$rc" -eq 0 ]; then
    report PASS "$label"
    PASS=$((PASS + 1))
  else
    report FAIL "$label (expected exit 0, got $rc)"
    printf '      output: %s\n' "$output"
    FAIL=$((FAIL + 1))
  fi
else
  report XFAIL "$label — identity file not present, v2 hook not implemented"
  XFAIL=$((XFAIL + 1))
fi

# ---- T5: Non-promotion creates under non-proposed stages rejected -----------
label="INV-5: non-Orianna author creating plan directly in plans/approved/ rejected"
REPO="$(make_repo)"
# Create a NEW file directly in approved (not moved from proposed)
mkdir -p "$REPO/plans/approved/personal"
printf -- '---\nstatus: approved\ntitle: bypass\nowner: agent\n---\n\n# Bypass\n' \
  > "$REPO/plans/approved/personal/2026-04-22-bypass.md"
git -C "$REPO" add plans/approved/
rc=0
output="$(run_hook "$REPO" "chore: sneaky plan" "$GENERIC_EMAIL" 2>&1)" || rc=$?
rm -rf "$REPO"
if [ "$IMPLEMENTATION_PRESENT" -eq 1 ]; then
  if [ "$rc" -ne 0 ]; then
    report PASS "$label"
    PASS=$((PASS + 1))
  else
    report FAIL "$label (expected non-zero exit, got 0)"
    FAIL=$((FAIL + 1))
  fi
else
  report XFAIL "$label — identity file not present, v2 hook not implemented"
  XFAIL=$((XFAIL + 1))
fi

# ---- T6: Admin-only protection of orianna.md agent def ---------------------
label="INV-6: non-admin author modifying .claude/agents/orianna.md rejected"
REPO="$(make_repo)"
mkdir -p "$REPO/.claude/agents"
printf 'model: opus\n---\n# Orianna\n' > "$REPO/.claude/agents/orianna.md"
git -C "$REPO" add .claude/
rc=0
output="$(run_hook "$REPO" "chore: edit orianna" "$GENERIC_EMAIL" 2>&1)" || rc=$?
rm -rf "$REPO"
if [ "$IMPLEMENTATION_PRESENT" -eq 1 ]; then
  if [ "$rc" -ne 0 ]; then
    report PASS "$label"
    PASS=$((PASS + 1))
  else
    report FAIL "$label (expected non-zero exit, got 0)"
    FAIL=$((FAIL + 1))
  fi
else
  report XFAIL "$label — identity file not present, v2 hook not implemented"
  XFAIL=$((XFAIL + 1))
fi

# ---- summary ----------------------------------------------------------------
printf '\nResults: %d passed, %d failed, %d xfail\n' "$PASS" "$FAIL" "$XFAIL"
# Exit non-zero only on real failures (not xfail). xfail is expected pre-implementation.
[ "$FAIL" -eq 0 ] || exit 1
exit 0
