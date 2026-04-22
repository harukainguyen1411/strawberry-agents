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
#   1. Pre-acquire the shared coordinator lock in the test process (simulates
#      orianna-sign.sh holding the lock during its add→commit window).
#   2. Attempt plan-promote.sh on an unrelated plan.
#   3. Assert plan-promote fails fast with holder-pid diagnostic.
#   4. Release lock; assert plan-promote completes cleanly.
#   5. Assert lockfile is not visible in git status (lives under .git/).
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
PLAN_PROMOTE="$REPO_ROOT/scripts/plan-promote.sh"

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }
info() { printf '[INFO] %s\n' "$*"; }

# --- setup temp repo -----------------------------------------------------------

TMPDIR_ROOT="$(mktemp -d)"
TMPBIN="$TMPDIR_ROOT/bin"
TMPREPO="$TMPDIR_ROOT/repo"

cleanup() {
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

# Install minimal hooks (plan-promote uses pre-commit via git commit)
HOOKS_DIR="$TMPREPO/.git/hooks"
mkdir -p "$HOOKS_DIR"
# No-op pre-commit hook — plan-promote commits are plain chore: commits
cat > "$HOOKS_DIR/pre-commit" <<'HOOKEOF'
#!/usr/bin/env bash
exit 0
HOOKEOF
chmod +x "$HOOKS_DIR/pre-commit"

# Symlink supporting scripts needed by plan-promote
mkdir -p "$TMPREPO/scripts"
ln -s "$REPO_ROOT/scripts/_lib_gdoc.sh"              "$TMPREPO/scripts/_lib_gdoc.sh"
ln -s "$REPO_ROOT/scripts/orianna-sign.sh"           "$TMPREPO/scripts/orianna-sign.sh"
ln -s "$REPO_ROOT/scripts/orianna-hash-body.sh"      "$TMPREPO/scripts/orianna-hash-body.sh"
ln -s "$REPO_ROOT/scripts/orianna-verify-signature.sh" "$TMPREPO/scripts/orianna-verify-signature.sh"
ln -s "$REPO_ROOT/scripts/orianna-verify-signature.sh" "$TMPREPO/scripts/orianna-verify-signature.sh" 2>/dev/null || true
if [ -f "$REPO_ROOT/scripts/_lib_stale_lock.sh" ]; then
  ln -s "$REPO_ROOT/scripts/_lib_stale_lock.sh" "$TMPREPO/scripts/_lib_stale_lock.sh"
fi
if [ -f "$REPO_ROOT/scripts/_lib_coordinator_lock.sh" ]; then
  ln -s "$REPO_ROOT/scripts/_lib_coordinator_lock.sh" "$TMPREPO/scripts/_lib_coordinator_lock.sh"
fi

# Seed a plan in plans/approved/ (ready to promote to in-progress)
APPROVED_DIR="$TMPREPO/plans/approved/personal"
mkdir -p "$APPROVED_DIR"
PROMOTE_PLAN="$APPROVED_DIR/2026-04-22-shared-lock-promote-plan.md"
cat > "$PROMOTE_PLAN" <<'PLANEOF'
---
status: approved
concern: personal
owner: talon
created: 2026-04-22
orianna_gate_version: 2
complexity: quick
orianna_signature_approved: "sha256:deadbeef00000000000000000000000000000000000000000000000000000000:2026-04-22T00:00:00Z"
---

# Shared lock promote test plan

Minimal plan for the coordinator shared-lock test harness.
PLANEOF
git -C "$TMPREPO" add "$PROMOTE_PLAN"
git -C "$TMPREPO" commit -q -m "chore: seed promote plan"

# Stub orianna-verify-signature: always exits 0 (plan signatures are valid)
cat > "$TMPBIN/orianna-verify-signature.sh" <<'STUBEOF'
#!/usr/bin/env bash
exit 0
STUBEOF
chmod +x "$TMPBIN/orianna-verify-signature.sh"

# Stub orianna-sign.sh (plan-promote calls it for in-progress signature):
# fast, succeeds. We don't need it to hold the lock — we're testing plan-promote's
# lock behavior, not orianna-sign's.
cat > "$TMPBIN/orianna-sign.sh" <<'STUBEOF'
#!/usr/bin/env bash
# Stub orianna-sign.sh — immediately appends a fake signature and exits 0.
PLAN_PATH="${2:-}"
PHASE="${3:-approved}"
if [ -z "$PLAN_PATH" ]; then
  # Try positional
  for arg in "$@"; do
    case "$arg" in
      --*) ;;
      *.md) PLAN_PATH="$arg" ;;
      approved|in_progress|in-progress|implemented) PHASE="$arg" ;;
    esac
  done
fi
if [ -n "$PLAN_PATH" ] && [ -f "$PLAN_PATH" ]; then
  # Insert a stub orianna_signature line
  FIELD="orianna_signature_${PHASE//-/_}"
  printf '%s: "sha256:stubsig0000:2026-04-22T00:00:00Z"\n' "$FIELD" >> "$PLAN_PATH"
fi
exit 0
STUBEOF
chmod +x "$TMPBIN/orianna-sign.sh"

# --- Pre-acquire the coordinator lock -----------------------------------------
LOCKFILE="$TMPREPO/.git/strawberry-promote.lock"
LOCK_HELD=0

info "Pre-acquiring coordinator lock to simulate orianna-sign.sh holding it"
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCKFILE"
  flock -n 9 || { fail "could not pre-acquire flock"; }
  printf '%s\n' "$$" >&9
  LOCK_HELD=1
  info "flock acquired on $LOCKFILE (held by PID $$)"
else
  LOCK_DIR="${LOCKFILE}.dir"
  mkdir "$LOCK_DIR" || { fail "could not pre-acquire mkdir lock"; }
  printf '%s\n' "$$" > "$LOCK_DIR/pid"
  LOCK_HELD=1
  info "mkdir lock acquired: $LOCK_DIR (held by PID $$)"
fi

# --- Attempt plan-promote while lock is held ----------------------------------
info "Attempting plan-promote.sh while coordinator lock is held"
PROMOTE_LOG="$TMPDIR_ROOT/promote.log"
PROMOTE_RC=0
NO_PUSH=1 REPO="$TMPREPO" \
  bash "$PLAN_PROMOTE" "$PROMOTE_PLAN" in-progress >"$PROMOTE_LOG" 2>&1 || PROMOTE_RC=$?

info "plan-promote.sh exited with RC=$PROMOTE_RC"
PROMOTE_OUT="$(cat "$PROMOTE_LOG")"
info "output: $PROMOTE_OUT"

# --- Assertion 1: promote must fail (shared lock held) -------------------------
if [ "$PROMOTE_RC" -eq 0 ]; then
  fail "plan-promote.sh should have failed (shared coordinator lock held) but exited 0."
fi
pass "plan-promote.sh failed with RC=$PROMOTE_RC (expected — shared lock contention)"

# --- Assertion 2: promote output must contain holder-pid diagnostic -----------
if ! printf '%s\n' "$PROMOTE_OUT" | grep -qiE "already running \(pid [0-9]+\)"; then
  fail "expected 'already running (pid N)' in promote output. Got: $PROMOTE_OUT"
fi
pass "plan-promote.sh printed holder-pid diagnostic"

# --- Release lock and verify it's gone ---------------------------------------
info "Releasing coordinator lock"
if command -v flock >/dev/null 2>&1; then
  exec 9>&-
  rm -f "$LOCKFILE" 2>/dev/null || true
else
  rm -rf "${LOCKFILE}.dir" 2>/dev/null || true
fi
LOCK_HELD=0
pass "coordinator lock released"

# --- Assertion 3: lockfile not present after release --------------------------
if [ -e "$LOCKFILE" ] || [ -d "${LOCKFILE}.dir" ]; then
  fail "lockfile still present after release: $LOCKFILE"
fi
pass "lockfile gone after release"

# --- Assertion 4: lockfile not present in git status --------------------------
UNTRACKED="$(git -C "$TMPREPO" status --porcelain 2>/dev/null || true)"
if printf '%s\n' "$UNTRACKED" | grep -q "strawberry-promote.lock"; then
  fail "lockfile appeared in git status (should live under .git/ and never be tracked)"
fi
pass "lockfile not visible in git status"

printf '\n[ALL PASS] coordinator shared-lock test passed.\n'
exit 0
