#!/usr/bin/env bash
# test-coordinator-lock-shared.sh — xfail test: plan-promote + orianna-sign share lock
#
# Plan: plans/in-progress/personal/2026-04-22-concurrent-coordinator-race-closeout.md T2
#
# xfail: This test fails until T3 (factor lock helper) and T4 (wire lock into
# both scripts sharing .git/strawberry-promote.lock) land. Once both tasks
# complete, this test must pass (exit 0).
#
# What it tests:
#   1. Start orianna-sign.sh with a slow stubbed claude (holds lock for ~3s).
#   2. While signing is in progress, attempt plan-promote.sh on an unrelated plan.
#   3. Assert plan-promote blocks/fails with holder-pid diagnostic (shared lock contention).
#   4. After signing finishes, assert lockfile is gone (no leftover .git/strawberry-promote.lock).
#   5. Assert lockfile never appears in `git status` (stays under .git/).
#
# Usage:
#   bash scripts/__tests__/test-coordinator-lock-shared.sh
#
# Exit codes:
#   0 — all assertions passed
#   1 — test assertion failed
#   2 — test setup/infrastructure error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ORIANNA_SIGN="$REPO_ROOT/scripts/orianna-sign.sh"
PLAN_PROMOTE="$REPO_ROOT/scripts/plan-promote.sh"

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }
info() { printf '[INFO] %s\n' "$*"; }

# --- setup temp repo -----------------------------------------------------------

TMPDIR_ROOT="$(mktemp -d)"
TMPBIN="$TMPDIR_ROOT/bin"
TMPREPO="$TMPDIR_ROOT/repo"

cleanup() {
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
# plan-promote.sh checks for CLAUDE.md with the Strawberry sentinel
cat > "$TMPREPO/CLAUDE.md" <<'EOF'
# Strawberry — Personal Agent System
EOF
git -C "$TMPREPO" add "$TMPREPO/CLAUDE.md"
git -C "$TMPREPO" commit -q --allow-empty -m "init"

# Install hooks
HOOKS_DIR="$TMPREPO/.git/hooks"
mkdir -p "$HOOKS_DIR"
cp "$REPO_ROOT/scripts/hooks/pre-commit-orianna-signature-guard.sh" \
   "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

# Symlink supporting scripts
mkdir -p "$TMPREPO/scripts"
ln -s "$REPO_ROOT/scripts/orianna-hash-body.sh"        "$TMPREPO/scripts/orianna-hash-body.sh"
ln -s "$REPO_ROOT/scripts/orianna-verify-signature.sh" "$TMPREPO/scripts/orianna-verify-signature.sh"
ln -s "$REPO_ROOT/scripts/orianna-sign.sh"             "$TMPREPO/scripts/orianna-sign.sh"
ln -s "$REPO_ROOT/scripts/orianna-pre-fix.sh"          "$TMPREPO/scripts/orianna-pre-fix.sh"
ln -s "$REPO_ROOT/scripts/orianna-verify-signature.sh" "$TMPREPO/scripts/orianna-verify-signature.sh"
if [ -f "$REPO_ROOT/scripts/_lib_stale_lock.sh" ]; then
  ln -s "$REPO_ROOT/scripts/_lib_stale_lock.sh" "$TMPREPO/scripts/_lib_stale_lock.sh"
fi
if [ -f "$REPO_ROOT/scripts/_lib_coordinator_lock.sh" ]; then
  ln -s "$REPO_ROOT/scripts/_lib_coordinator_lock.sh" "$TMPREPO/scripts/_lib_coordinator_lock.sh"
fi

# gdoc lib required by plan-promote
if [ -f "$REPO_ROOT/scripts/_lib_gdoc.sh" ]; then
  ln -s "$REPO_ROOT/scripts/_lib_gdoc.sh" "$TMPREPO/scripts/_lib_gdoc.sh"
fi

mkdir -p "$TMPREPO/agents/orianna/prompts"
printf 'Stub plan-check prompt.\n' > "$TMPREPO/agents/orianna/prompts/plan-check.md"
mkdir -p "$TMPREPO/assessments/plan-fact-checks"

# Seed plan for orianna-sign (stays in proposed — sign only)
PROPOSED_DIR="$TMPREPO/plans/proposed"
APPROVED_DIR="$TMPREPO/plans/approved"
mkdir -p "$PROPOSED_DIR" "$APPROVED_DIR"

make_plan() {
  local dir="$1" slug="$2" status="$3"
  local file="$dir/${slug}.md"
  cat > "$file" <<PLANEOF
---
status: ${status}
concern: personal
owner: talon
created: 2026-04-22
orianna_gate_version: 2
complexity: quick
---

# Shared lock test plan ${slug}

Minimal plan for the coordinator shared-lock test harness.
PLANEOF
  git -C "$TMPREPO" add "$file"
  git -C "$TMPREPO" commit -q -m "chore: seed plan $slug"
  printf '%s\n' "$file"
}

SIGN_PLAN="$(make_plan "$PROPOSED_DIR" "2026-04-22-shared-lock-sign-plan" "proposed")"
PROMOTE_PLAN="$(make_plan "$APPROVED_DIR" "2026-04-22-shared-lock-promote-plan" "approved")"

# Stub claude: slow (3s sleep) then clean report
cat > "$TMPBIN/claude" <<'STUBEOF'
#!/usr/bin/env bash
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
cat > "$REPORT_DIR/shared-lock-${TS}.md" <<EOF
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

info "Starting orianna-sign.sh (slow — holds lock for ~3s)"
SIGN1_LOG="$TMPDIR_ROOT/sign1.log"
SIGN1_RC=0
PATH="$TMPBIN:$PATH" REPO="$TMPREPO" \
  bash "$ORIANNA_SIGN" "$SIGN_PLAN" approved >"$SIGN1_LOG" 2>&1 &
SIGN1_PID=$!

sleep 0.5

info "Attempting plan-promote.sh while orianna-sign holds lock"
PROMOTE_LOG="$TMPDIR_ROOT/promote.log"
PROMOTE_RC=0
NO_PUSH=1 REPO="$TMPREPO" PATH="$TMPBIN:$PATH" \
  bash "$PLAN_PROMOTE" "$PROMOTE_PLAN" in-progress >"$PROMOTE_LOG" 2>&1 || PROMOTE_RC=$?

info "plan-promote.sh exited with RC=$PROMOTE_RC"

# --- Assertion 1: promote must fail on shared lock contention -----------------
if [ "$PROMOTE_RC" -eq 0 ]; then
  fail "plan-promote.sh should have failed (shared lock held by orianna-sign) but exited 0."
fi
pass "plan-promote failed with RC=$PROMOTE_RC (expected — lock contention)"

# --- Assertion 2: promote output must mention holder-pid diagnostic -----------
PROMOTE_OUT="$(cat "$PROMOTE_LOG")"
if ! printf '%s\n' "$PROMOTE_OUT" | grep -qiE "already running \(pid [0-9]+\)"; then
  fail "expected 'already running (pid N)' in promote output. Got: $PROMOTE_OUT"
fi
pass "plan-promote printed holder-pid diagnostic"

# Wait for orianna-sign to finish
wait "$SIGN1_PID" || SIGN1_RC=$?
info "orianna-sign exited with RC=$SIGN1_RC"

if [ "$SIGN1_RC" -ne 0 ]; then
  info "sign1 log: $(cat "$SIGN1_LOG")"
  fail "orianna-sign.sh should have succeeded but exited $SIGN1_RC"
fi
pass "orianna-sign.sh succeeded"

# --- Assertion 3: lockfile does not remain after normal exit ------------------
LOCKFILE="$TMPREPO/.git/strawberry-promote.lock"
if [ -e "$LOCKFILE" ] || [ -d "${LOCKFILE}.dir" ]; then
  fail "lockfile $LOCKFILE still present after orianna-sign exited normally"
fi
pass "lockfile cleaned up after normal exit"

# --- Assertion 4: lockfile is not tracked (lives under .git/) -----------------
UNTRACKED="$(git -C "$TMPREPO" status --porcelain)"
if printf '%s\n' "$UNTRACKED" | grep -q "strawberry-promote.lock"; then
  fail "lockfile appeared in git status (should live under .git/ and never be tracked)"
fi
pass "lockfile not visible in git status"

printf '\n[ALL PASS] coordinator shared-lock test passed.\n'
exit 0
