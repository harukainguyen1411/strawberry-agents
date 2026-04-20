#!/usr/bin/env bash
# plan-promote.sh — move a plan out of plans/proposed/ into another lifecycle
# directory, automatically unpublishing its Drive doc on the way out.
#
# Usage:
#   ./scripts/plan-promote.sh plans/proposed/2026-04-08-foo.md approved
#
# Per plan 2026-04-08-gdoc-mirror-revision, the Drive mirror is proposed-only.
# Every exit from plans/proposed/ must flow through this script so the unpublish
# step can never be forgotten.
#
# Behavior:
#   1. Refuse if the source file is not in plans/proposed/.
#   2. Refuse if the target status is not one of approved|in-progress|implemented|archived.
#   3. Refuse if the target file has uncommitted changes.
#   4. If the source has a gdoc_id, call plan-unpublish.sh (which trashes the
#      Drive doc, strips gdoc_id/gdoc_url, and commits its own change).
#   5. git mv the file from plans/proposed/<file> to plans/<target>/<file>.
#   6. Rewrite the status: frontmatter field to match the new directory.
#   7. Commit with `chore: promote <file> to <target>`.
#   8. Push.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib_gdoc.sh
. "$SCRIPT_DIR/_lib_gdoc.sh"

usage() {
  cat >&2 <<EOF
Usage: $0 <plans/proposed/file.md> <target-status>
  target-status: approved | in-progress | implemented | archived

Moves a plan out of plans/proposed/ into the target directory, unpublishing
its Drive doc first if one exists. Use this instead of raw 'git mv' for any
plan leaving plans/proposed/.
EOF
  exit 2
}

[ $# -eq 2 ] || usage
SOURCE="$1"
TARGET_STATUS="$2"

# ---------------------------------------------------------------------------
# Advisory file lock — §D9.3
#
# Prevents two concurrent plan-promote.sh invocations from racing on the
# same repo state. Serialises all promotes repo-wide (promotes are seconds-
# long; serialisation cost is negligible).
#
# Strategy: prefer flock(1) (available on Linux and macOS via util-linux).
# Fall back to mkdir-based lock for environments where flock is absent
# (Git Bash on Windows, stripped macOS setups). The lock is advisory — the
# real corruption guard is git's push atomicity — but gives a clean error
# message instead of a mid-promote git conflict.
# ---------------------------------------------------------------------------
LOCK_FILE="$REPO_ROOT/.plan-promote.lock"
LOCK_ACQUIRED=0

_plan_promote_unlock() {
  if [ "$LOCK_ACQUIRED" -eq 1 ]; then
    # mkdir-lock: remove the directory we created.
    # flock-lock: flock releases automatically when the FD closes at exit,
    # but we also clean up the lockfile body (PID).
    rm -f "$LOCK_FILE" 2>/dev/null || true
    LOCK_ACQUIRED=0
  fi
}
trap '_plan_promote_unlock' EXIT INT TERM

_acquire_lock() {
  # --- try flock first ---
  if command -v flock >/dev/null 2>&1; then
    # Open (or create) the lockfile on FD 9 and acquire exclusive non-blocking lock.
    # shellcheck disable=SC1083
    exec 9>"$LOCK_FILE"
    if flock -n 9; then
      printf '%s\n' "$$" >&9
      LOCK_ACQUIRED=1
      return 0
    else
      # Another process holds the lock. Read its PID from the file.
      _holder_pid="$(cat "$LOCK_FILE" 2>/dev/null || true)"
      printf 'plan-promote is already running (pid %s); retry when it finishes.\n' \
        "${_holder_pid:-unknown}" >&2
      exit 1
    fi
  fi

  # --- mkdir fallback (POSIX-portable, atomic on most filesystems) ---
  # The lock directory name embeds the holder PID for diagnostics.
  _lock_dir="${LOCK_FILE}.dir"
  if mkdir "$_lock_dir" 2>/dev/null; then
    printf '%s\n' "$$" > "$_lock_dir/pid"
    LOCK_ACQUIRED=1
    # Override unlock to remove the dir instead.
    _plan_promote_unlock() {
      rm -rf "$_lock_dir" 2>/dev/null || true
      LOCK_ACQUIRED=0
    }
    return 0
  else
    _holder_pid="$(cat "$_lock_dir/pid" 2>/dev/null || true)"
    printf 'plan-promote is already running (pid %s); retry when it finishes.\n' \
      "${_holder_pid:-unknown}" >&2
    exit 1
  fi
}

_acquire_lock

# 1. Source must live in plans/proposed/.
case "$SOURCE" in
  plans/proposed/*.md) ;;
  */plans/proposed/*.md) ;;
  *) gdoc::die "plan-promote only handles plans/proposed/*.md (got $SOURCE)" ;;
esac
[ -f "$SOURCE" ] || gdoc::die "no such file: $SOURCE"

# 2. Target status must be a known lifecycle directory.
case "$TARGET_STATUS" in
  approved|in-progress|implemented|archived) ;;
  *) gdoc::die "invalid target status '$TARGET_STATUS'; expected: approved|in-progress|implemented|archived" ;;
esac

gdoc::require_tools
# 3. Target file must be clean (matches plan-publish/unpublish guards).
gdoc::require_clean "$SOURCE"

# 3.5. Orianna gate — runs between step 3 (require clean) and step 4 (Drive unpublish)
# so that Drive is never touched for plans that fail the gate.
#
# Gate version branching (§D8 T6.4):
#   - orianna_gate_version absent  → "grandfathered plan; gate-v1 rules applied"
#                                    Fall back to legacy orianna-fact-check.sh call.
#   - orianna_gate_version = 2     → Enforce §D6 signature gates:
#                                    T6.1 presence check, T6.2 carry-forward,
#                                    T6.5 no direct fact-check call (runs inside orianna-sign.sh).
#
# archived transitions carry no Orianna gate (§D2.4).

PLAN_BASENAME="$(basename "$SOURCE" .md)"
GATE_VERSION="$(gdoc::frontmatter_get "$SOURCE" orianna_gate_version || true)"

# Map target status to the underscore-form phase name used in signature field names.
# in-progress → in_progress; others are unchanged.
case "$TARGET_STATUS" in
  in-progress) _sig_phase="in_progress" ;;
  *)           _sig_phase="$TARGET_STATUS" ;;
esac

if [ "$TARGET_STATUS" = "archived" ]; then
  # §D2.4 — no Orianna gate on archived transition; signature trail is preserved, not required.
  gdoc::log "archived transition — no Orianna gate required (§D2.4)"

elif [ "$GATE_VERSION" != "2" ]; then
  # ---- Gate v1 / grandfather path (T6.4) ----------------------------------------
  gdoc::log "WARNING: grandfathered plan; gate-v1 rules applied (orianna_gate_version not set or != 2)"
  gdoc::log "running legacy fact-check gate on: $SOURCE"
  FACT_CHECK_RC=0
  "$SCRIPT_DIR/orianna-fact-check.sh" "$SOURCE" || FACT_CHECK_RC=$?
  if [ "$FACT_CHECK_RC" -ne 0 ]; then
    gdoc::log "fact-check returned non-zero exit ($FACT_CHECK_RC) — promotion halted"
    REPORT_DIR="$REPO_ROOT/assessments/plan-fact-checks"
    LATEST_REPORT=""
    for _r in "$REPORT_DIR"/${PLAN_BASENAME}-*.md; do
      [ -f "$_r" ] && LATEST_REPORT="$_r"
    done
    if [ -n "$LATEST_REPORT" ]; then
      gdoc::log "report: $LATEST_REPORT"
      awk '/^## Block findings/{p=1; next} /^## Warn findings/{p=0} p && /[^[:space:]]/' \
        "$LATEST_REPORT" >&2 || true
    fi
    exit 1
  fi
  gdoc::log "legacy fact-check passed — continuing to step 4"

else
  # ---- Gate v2 path (T6.1 + T6.2 + T6.5) ----------------------------------------

  # T6.1: Signature presence check — assert orianna_signature_<target-phase> in frontmatter.
  gdoc::log "gate-v2: checking orianna_signature_${_sig_phase} presence in: $SOURCE"
  _sig_value="$(gdoc::frontmatter_get "$SOURCE" "orianna_signature_${_sig_phase}" || true)"
  if [ -z "$_sig_value" ]; then
    printf '\n' >&2
    printf '=== BLOCKED: Orianna signature required (gate-v2) ===\n' >&2
    printf 'Plan  : %s\n' "$SOURCE" >&2
    printf 'Phase : %s\n' "$TARGET_STATUS" >&2
    printf '\n' >&2
    printf 'The plan is missing orianna_signature_%s in its frontmatter.\n' "$_sig_phase" >&2
    printf 'Obtain a signature before promoting:\n' >&2
    printf '  bash scripts/orianna-sign.sh %s %s\n' "$SOURCE" "$_sig_phase" >&2
    printf '\n' >&2
    printf 'Per plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §D6.1\n' >&2
    exit 1
  fi
  gdoc::log "gate-v2: orianna_signature_${_sig_phase} present — running validity check"

  # T6.1 (continued): Signature validity check — invoke orianna-verify-signature.sh.
  VERIFY_RC=0
  "$SCRIPT_DIR/orianna-verify-signature.sh" "$SOURCE" "$_sig_phase" >&2 || VERIFY_RC=$?
  if [ "$VERIFY_RC" -ne 0 ]; then
    printf '\n' >&2
    printf '=== BLOCKED: Orianna signature invalid (gate-v2) ===\n' >&2
    printf 'Plan  : %s\n' "$SOURCE" >&2
    printf 'Phase : %s\n' "$TARGET_STATUS" >&2
    printf '\n' >&2
    printf 'orianna-verify-signature.sh exited %d (see diagnosis above).\n' "$VERIFY_RC" >&2
    printf 'To re-sign after a body edit:\n' >&2
    printf '  1. Remove the stale orianna_signature_%s field from frontmatter.\n' "$_sig_phase" >&2
    printf '  2. Run: bash scripts/orianna-sign.sh %s %s\n' "$SOURCE" "$_sig_phase" >&2
    printf '\n' >&2
    printf 'Per plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §D6.2\n' >&2
    exit 1
  fi
  gdoc::log "gate-v2: orianna_signature_${_sig_phase} valid"

  # T6.2: Carry-forward check — verify all prior-phase signatures are still valid.
  # Prevents a tampered earlier phase from silently invalidating the chain (§D6.3).
  case "$_sig_phase" in
    in_progress)
      _prior_phases="approved"
      ;;
    implemented)
      _prior_phases="approved in_progress"
      ;;
    *)
      _prior_phases=""
      ;;
  esac

  for _prior in $_prior_phases; do
    gdoc::log "gate-v2: carry-forward check for prior phase: ${_prior}"
    PRIOR_RC=0
    "$SCRIPT_DIR/orianna-verify-signature.sh" "$SOURCE" "$_prior" >&2 || PRIOR_RC=$?
    if [ "$PRIOR_RC" -ne 0 ]; then
      printf '\n' >&2
      printf '=== BLOCKED: Prior Orianna signature invalid — carry-forward failure (gate-v2) ===\n' >&2
      printf 'Plan         : %s\n' "$SOURCE" >&2
      printf 'Current phase: %s\n' "$TARGET_STATUS" >&2
      printf 'Failed phase : %s\n' "$_prior" >&2
      printf '\n' >&2
      printf 'The orianna_signature_%s field is invalid against the current plan body.\n' "$_prior" >&2
      printf 'A tampered or edited plan body after signing invalidates subsequent promotions.\n' >&2
      printf 'To recover:\n' >&2
      printf '  1. Remove the stale orianna_signature_%s field from frontmatter.\n' "$_prior" >&2
      printf '  2. Run: bash scripts/orianna-sign.sh %s %s\n' "$SOURCE" "$_prior" >&2
      printf '  3. Then re-sign the current phase: bash scripts/orianna-sign.sh %s %s\n' "$SOURCE" "$_sig_phase" >&2
      printf '\n' >&2
      printf 'Per plans/in-progress/2026-04-20-orianna-gated-plan-lifecycle.md §D6.3\n' >&2
      exit 1
    fi
    gdoc::log "gate-v2: prior signature ${_prior} valid"
  done

  # T6.5: On the v2 path, fact-check runs inside orianna-sign.sh as a precondition
  # (§D2.1, §D6.4). No direct orianna-fact-check.sh call here.
  gdoc::log "gate-v2: all Orianna signature checks passed — continuing to step 4"
fi

# 4. If we have a gdoc_id, unpublish first. plan-unpublish.sh handles its own commit.
EXISTING=$(gdoc::frontmatter_get "$SOURCE" gdoc_id || true)
if [ -n "$EXISTING" ]; then
  gdoc::log "source has gdoc_id $EXISTING; unpublishing before promote"
  "$SCRIPT_DIR/plan-unpublish.sh" "$SOURCE"
else
  gdoc::log "source has no gdoc_id; skipping unpublish"
fi

# Recompute paths (plan-unpublish.sh edits the file but does not move it).
BASENAME=$(basename "$SOURCE")
TARGET_DIR="$(dirname "$(dirname "$SOURCE")")/$TARGET_STATUS"
TARGET_PATH="$TARGET_DIR/$BASENAME"

mkdir -p "$TARGET_DIR"

# 5. git mv. After unpublish the file is committed and clean, so the mv is safe.
git -C "$REPO_ROOT" mv "$SOURCE" "$TARGET_PATH"

# 6. Rewrite status: frontmatter to match new directory.
gdoc::frontmatter_set "$TARGET_PATH" status "$TARGET_STATUS"

# Verify the rewrite landed (same defensive check as plan-publish.sh).
if ! grep -qE "^status:[[:space:]]+$TARGET_STATUS\$" "$TARGET_PATH"; then
  gdoc::die "failed to rewrite status field in $TARGET_PATH; manual cleanup needed"
fi

# 7. Commit.
git -C "$REPO_ROOT" add -- "$TARGET_PATH"
git -C "$REPO_ROOT" commit -m "chore: promote $BASENAME to $TARGET_STATUS" >&2

# 8. Push (matches the rest of the plan-lifecycle script family — see Decision
#    in plan 2026-04-08-gdoc-mirror-revision open-question 1).
git -C "$REPO_ROOT" push >&2

gdoc::log "done. $SOURCE -> $TARGET_PATH"
