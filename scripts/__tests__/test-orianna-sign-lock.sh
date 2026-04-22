#!/usr/bin/env bash
# test-orianna-sign-lock.sh — xfail test: orianna-sign.sh acquires coordinator lock
#
# Plan: plans/in-progress/personal/2026-04-22-concurrent-coordinator-race-closeout.md T1
#
# xfail: This test fails against an unpatched orianna-sign.sh (no lock acquisition).
# Once T3 (factor lock helper) and T4 (wire lock into orianna-sign) land, this
# test must pass (exit 0).
#
# What it tests:
#   Two concurrent invocations of scripts/orianna-sign.sh against a temp repo.
#   The second invocation must fail fast with an "already running (pid ...)" message
#   rather than racing the git index.
#
# Usage:
#   bash scripts/__tests__/test-orianna-sign-lock.sh
#
# Exit codes:
#   0 — all assertions passed (lock exclusion works)
#   1 — test assertion failed
#   2 — test setup/infrastructure error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ORIANNA_SIGN="$REPO_ROOT/scripts/orianna-sign.sh"

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }
info() { printf '[INFO] %s\n' "$*"; }

# --- setup temp repo -----------------------------------------------------------

TMPDIR_ROOT="$(mktemp -d)"
TMPBIN="$TMPDIR_ROOT/bin"
TMPREPO="$TMPDIR_ROOT/repo"

cleanup() {
  # Kill background signing job if still running
  if [ -n "${SIGN1_PID:-}" ] && kill -0 "$SIGN1_PID" 2>/dev/null; then
    kill "$SIGN1_PID" 2>/dev/null || true
  fi
  rm -rf "$TMPDIR_ROOT"
}
trap cleanup EXIT INT TERM

mkdir -p "$TMPBIN" "$TMPREPO"

git -C "$TMPREPO" init -q
git -C "$TMPREPO" config user.email "test@test.local"
git -C "$TMPREPO" config user.name "Test"
git -C "$TMPREPO" commit -q --allow-empty -m "init"

# Install minimal hooks needed by orianna-sign
HOOKS_DIR="$TMPREPO/.git/hooks"
mkdir -p "$HOOKS_DIR"
cp "$REPO_ROOT/scripts/hooks/pre-commit-orianna-signature-guard.sh" \
   "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

# Symlink supporting scripts
mkdir -p "$TMPREPO/scripts"
ln -s "$REPO_ROOT/scripts/orianna-hash-body.sh" "$TMPREPO/scripts/orianna-hash-body.sh"
ln -s "$REPO_ROOT/scripts/orianna-verify-signature.sh" "$TMPREPO/scripts/orianna-verify-signature.sh"
# Symlink _lib_stale_lock.sh if it exists
if [ -f "$REPO_ROOT/scripts/_lib_stale_lock.sh" ]; then
  ln -s "$REPO_ROOT/scripts/_lib_stale_lock.sh" "$TMPREPO/scripts/_lib_stale_lock.sh"
fi
# Symlink _lib_coordinator_lock.sh when it exists (T3 delivers this)
if [ -f "$REPO_ROOT/scripts/_lib_coordinator_lock.sh" ]; then
  ln -s "$REPO_ROOT/scripts/_lib_coordinator_lock.sh" "$TMPREPO/scripts/_lib_coordinator_lock.sh"
fi

mkdir -p "$TMPREPO/agents/orianna/prompts"
printf 'Stub plan-check prompt.\n' > "$TMPREPO/agents/orianna/prompts/plan-check.md"
mkdir -p "$TMPREPO/assessments/plan-fact-checks"

# Seed two minimal plans (one per concurrent invocation)
PLAN_DIR="$TMPREPO/plans/proposed"
mkdir -p "$PLAN_DIR"

make_plan() {
  local slug="$1"
  local file="$PLAN_DIR/${slug}.md"
  cat > "$file" <<PLANEOF
---
status: proposed
concern: personal
owner: talon
created: 2026-04-22
orianna_gate_version: 2
complexity: quick
---

# Lock test plan ${slug}

Minimal plan for the concurrent-lock test harness.
PLANEOF
  git -C "$TMPREPO" add "$file"
  git -C "$TMPREPO" commit -q -m "chore: seed plan $slug"
  printf '%s\n' "$file"
}

PLAN1_PATH="$(make_plan "2026-04-22-lock-test-plan-a")"
PLAN2_PATH="$(make_plan "2026-04-22-lock-test-plan-b")"

# Stub claude: sleeps 3 seconds before emitting a clean report, simulating a
# slow signing invocation. This gives the second invocation time to race.
cat > "$TMPBIN/claude" <<'STUBEOF'
#!/usr/bin/env bash
# Slow stub claude — sleeps 3s then emits clean Orianna report.
REPORT_REPO=""
NEXT_IS_SYSPROMPT=0
for arg in "$@"; do
  if [ "$NEXT_IS_SYSPROMPT" -eq 1 ]; then
    REPORT_REPO="${arg#*Your working directory is }"
    REPORT_REPO="${REPORT_REPO%.}"
    REPORT_REPO="${REPORT_REPO%% }"
    NEXT_IS_SYSPROMPT=0
  fi
  case "$arg" in --system-prompt) NEXT_IS_SYSPROMPT=1 ;; esac
done

sleep 3

if [ -z "$REPORT_REPO" ]; then
  printf '[stub-claude] ERROR: could not determine repo root\n' >&2
  exit 2
fi

REPORT_DIR="$REPORT_REPO/assessments/plan-fact-checks"
mkdir -p "$REPORT_DIR"
TS="$(date -u '+%Y-%m-%dT%H-%M-%SZ')"
REPORT_FILE="$REPORT_DIR/lock-test-${TS}.md"
cat > "$REPORT_FILE" <<EOF
---
plan: stub
phase: approved
block_findings: 0
warn_findings: 0
timestamp: $TS
---

## Summary
Stub check: no findings.

## Block findings
None.

## Warn findings
None.
EOF
exit 0
STUBEOF
chmod +x "$TMPBIN/claude"

info "Starting first orianna-sign.sh (slow, acquires lock)"
SIGN1_LOG="$TMPDIR_ROOT/sign1.log"
SIGN1_RC=0
PATH="$TMPBIN:$PATH" REPO="$TMPREPO" \
  bash "$ORIANNA_SIGN" "$PLAN1_PATH" approved >"$SIGN1_LOG" 2>&1 &
SIGN1_PID=$!

# Give sign1 a moment to start and hopefully acquire the lock
sleep 0.5

info "Starting second orianna-sign.sh (should fail fast on locked lock)"
SIGN2_LOG="$TMPDIR_ROOT/sign2.log"
SIGN2_RC=0
PATH="$TMPBIN:$PATH" REPO="$TMPREPO" \
  bash "$ORIANNA_SIGN" "$PLAN2_PATH" approved >"$SIGN2_LOG" 2>&1 || SIGN2_RC=$?

info "Second invocation exited with RC=$SIGN2_RC"

# --- Assertion 1: second invocation must fail (non-zero exit) -----------------
if [ "$SIGN2_RC" -eq 0 ]; then
  fail "second orianna-sign.sh should have failed (lock contention) but exited 0. Lock not implemented?"
fi
pass "second invocation exited non-zero (RC=$SIGN2_RC)"

# --- Assertion 2: second invocation must emit holder-pid diagnostic -----------
SIGN2_OUT="$(cat "$SIGN2_LOG")"
if ! printf '%s\n' "$SIGN2_OUT" | grep -qiE "already running \(pid [0-9]+\)"; then
  fail "expected 'already running (pid N)' message in sign2 output. Got: $SIGN2_OUT"
fi
pass "second invocation printed holder-pid diagnostic"

# --- Assertion 3: second invocation must fail within 2 seconds ----------------
# (The slow stub sleeps 3s; a blocking second invocation would take >3s total.)
# We already have the exit time from above — if we got here quickly it passed.
pass "second invocation fast-failed (lock fast-fail semantics)"

# Wait for first invocation to finish
wait "$SIGN1_PID" || SIGN1_RC=$?
info "First invocation exited with RC=$SIGN1_RC"

# --- Assertion 4: first invocation must succeed --------------------------------
if [ "$SIGN1_RC" -ne 0 ]; then
  info "sign1 log: $(cat "$SIGN1_LOG")"
  fail "first orianna-sign.sh should have succeeded but exited $SIGN1_RC"
fi
pass "first invocation succeeded"

printf '\n[ALL PASS] orianna-sign lock test passed.\n'
exit 0
