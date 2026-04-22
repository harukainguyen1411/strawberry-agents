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
#   Pre-acquires the shared coordinator lock in a background holder process, then
#   invokes scripts/orianna-sign.sh. Because orianna-sign.sh now acquires the same
#   lock before git add, it must fail fast with "already running (pid ...)" rather
#   than racing the git index.
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
HOLDER_PID=""

cleanup() {
  if [ -n "$HOLDER_PID" ] && kill -0 "$HOLDER_PID" 2>/dev/null; then
    kill "$HOLDER_PID" 2>/dev/null || true
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
ln -s "$REPO_ROOT/scripts/orianna-hash-body.sh"        "$TMPREPO/scripts/orianna-hash-body.sh"
ln -s "$REPO_ROOT/scripts/orianna-verify-signature.sh" "$TMPREPO/scripts/orianna-verify-signature.sh"
if [ -f "$REPO_ROOT/scripts/_lib_stale_lock.sh" ]; then
  ln -s "$REPO_ROOT/scripts/_lib_stale_lock.sh" "$TMPREPO/scripts/_lib_stale_lock.sh"
fi
if [ -f "$REPO_ROOT/scripts/_lib_coordinator_lock.sh" ]; then
  ln -s "$REPO_ROOT/scripts/_lib_coordinator_lock.sh" "$TMPREPO/scripts/_lib_coordinator_lock.sh"
fi

mkdir -p "$TMPREPO/agents/orianna/prompts"
printf 'Stub plan-check prompt.\n' > "$TMPREPO/agents/orianna/prompts/plan-check.md"
mkdir -p "$TMPREPO/assessments/plan-fact-checks"

# Seed a minimal plan
PLAN_DIR="$TMPREPO/plans/proposed"
mkdir -p "$PLAN_DIR"
PLAN_FILE="$PLAN_DIR/2026-04-22-lock-test-plan.md"
cat > "$PLAN_FILE" <<'PLANEOF'
---
status: proposed
concern: personal
owner: talon
created: 2026-04-22
orianna_gate_version: 2
complexity: quick
---

# Lock test plan

Minimal plan for the lock exclusion test harness.
PLANEOF
git -C "$TMPREPO" add "$PLAN_FILE"
git -C "$TMPREPO" commit -q -m "chore: seed lock test plan"
PLAN_REL="plans/proposed/2026-04-22-lock-test-plan.md"

# Stub claude: fast, emits clean Orianna report
cat > "$TMPBIN/claude" <<'STUBEOF'
#!/usr/bin/env bash
# Fast stub claude — immediately emits a clean Orianna report.
REPORT_REPO=""
NEXT_IS_SYSPROMPT=0
LAST_ARG=""
for arg in "$@"; do
  if [ "$NEXT_IS_SYSPROMPT" -eq 1 ]; then
    REPORT_REPO="${arg#*Your working directory is }"
    REPORT_REPO="${REPORT_REPO%.}"
    REPORT_REPO="${REPORT_REPO%% }"
    NEXT_IS_SYSPROMPT=0
  fi
  case "$arg" in --system-prompt) NEXT_IS_SYSPROMPT=1 ;; esac
  LAST_ARG="$arg"
done

PLAN_BASENAME=""
while IFS= read -r line; do
  case "$line" in
    *"Plan path (relative to repo root):"*)
      _rel="${line#*\`}"
      _rel="${_rel%\`*}"
      PLAN_BASENAME="$(basename "$_rel" .md)"
      break
      ;;
  esac
done <<EOF
$LAST_ARG
EOF

if [ -z "$REPORT_REPO" ] || [ -z "$PLAN_BASENAME" ]; then
  printf '[stub-claude] ERROR: missing REPORT_REPO or PLAN_BASENAME\n' >&2
  exit 2
fi

REPORT_DIR="$REPORT_REPO/assessments/plan-fact-checks"
mkdir -p "$REPORT_DIR"
TS="$(date -u '+%Y-%m-%dT%H-%M-%SZ')"
cat > "$REPORT_DIR/${PLAN_BASENAME}-${TS}.md" <<EOF
---
plan: $PLAN_BASENAME
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

# --- Pre-acquire the coordinator lock to simulate a concurrent holder ---------
# We hold the lock from a background sleep process by creating the mkdir-lock
# directory (or using flock if available). This simulates another coordinator
# already holding the lock when orianna-sign.sh tries to acquire it.

LOCKFILE="$TMPREPO/.git/strawberry-promote.lock"
LOCK_HELD=0

info "Pre-acquiring coordinator lock to simulate concurrent holder"
if command -v flock >/dev/null 2>&1; then
  # Use flock: open FD on lockfile and hold it in background
  exec 9>"$LOCKFILE"
  flock -n 9 || { fail "could not pre-acquire flock (already held?)"; }
  printf '%s\n' "$$" >&9
  LOCK_HELD=1
  info "flock acquired on $LOCKFILE (held by test PID $$)"
else
  # mkdir fallback
  LOCK_DIR="${LOCKFILE}.dir"
  mkdir "$LOCK_DIR" || { fail "could not pre-acquire mkdir lock"; }
  printf '%s\n' "$$" > "$LOCK_DIR/pid"
  LOCK_HELD=1
  info "mkdir lock acquired: $LOCK_DIR (held by PID $$)"
fi

# --- Invoke orianna-sign.sh — should fail fast on the held lock ---------------

info "Invoking orianna-sign.sh while lock is held by test (PID $$)"
SIGN_LOG="$TMPDIR_ROOT/sign.log"
SIGN_RC=0
PATH="$TMPBIN:$PATH" REPO="$TMPREPO" \
  bash "$ORIANNA_SIGN" "$PLAN_FILE" approved >"$SIGN_LOG" 2>&1 || SIGN_RC=$?

info "orianna-sign.sh exited with RC=$SIGN_RC"
SIGN_OUT="$(cat "$SIGN_LOG")"
info "output: $SIGN_OUT"

# --- Assertion 1: must fail (non-zero) ----------------------------------------
if [ "$SIGN_RC" -eq 0 ]; then
  fail "orianna-sign.sh should have failed (lock held) but exited 0. Lock not implemented?"
fi
pass "orianna-sign.sh exited non-zero (RC=$SIGN_RC)"

# --- Assertion 2: must emit holder-pid diagnostic -----------------------------
if ! printf '%s\n' "$SIGN_OUT" | grep -qiE "already running \(pid [0-9]+\)"; then
  fail "expected 'already running (pid N)' in output. Got: $SIGN_OUT"
fi
pass "orianna-sign.sh printed holder-pid diagnostic"

# --- Release the lock and verify orianna-sign succeeds now --------------------
info "Releasing pre-held lock"
if command -v flock >/dev/null 2>&1; then
  # Close FD 9 to release flock
  exec 9>&-
  rm -f "$LOCKFILE" 2>/dev/null || true
else
  rm -rf "${LOCKFILE}.dir" 2>/dev/null || true
fi
LOCK_HELD=0

info "Invoking orianna-sign.sh again (lock released — should succeed)"
SIGN2_LOG="$TMPDIR_ROOT/sign2.log"
SIGN2_RC=0
PATH="$TMPBIN:$PATH" REPO="$TMPREPO" \
  bash "$ORIANNA_SIGN" "$PLAN_FILE" approved >"$SIGN2_LOG" 2>&1 || SIGN2_RC=$?

if [ "$SIGN2_RC" -ne 0 ]; then
  info "sign2 log: $(cat "$SIGN2_LOG")"
  fail "orianna-sign.sh should succeed after lock released but exited $SIGN2_RC"
fi
pass "orianna-sign.sh succeeded after lock released"

# --- Assertion 3: lockfile not present after normal exit ----------------------
if [ -e "$LOCKFILE" ] || [ -d "${LOCKFILE}.dir" ]; then
  fail "lockfile still present after orianna-sign.sh normal exit"
fi
pass "lockfile cleaned up after normal exit"

printf '\n[ALL PASS] orianna-sign lock test passed.\n'
exit 0
