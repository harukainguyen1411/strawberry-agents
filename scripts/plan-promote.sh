#!/usr/bin/env bash
# plan-promote.sh — move a plan out of plans/proposed/ into another lifecycle
# directory, running the Orianna gate on the way out.
#
# Usage:
#   ./scripts/plan-promote.sh plans/proposed/2026-04-08-foo.md approved
#
# Behavior:
#   1. Refuse if the source file is not in plans/proposed/.
#   2. Refuse if the target status is not one of approved|in-progress|implemented|archived.
#   3. Refuse if the target file has uncommitted changes.
#   4. Run the Orianna gate (signature check or legacy fact-check).
#   5. git mv the file from plans/proposed/<file> to plans/<target>/<file>.
#   6. Rewrite the status: frontmatter field to match the new directory.
#   7. Commit with `chore: promote <file> to <target>`.
#   8. Push.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib_gdoc.sh
. "$SCRIPT_DIR/_lib_gdoc.sh"

# Stale index.lock auto-recovery (T7 — orianna-gate-speedups)
if [ -f "$SCRIPT_DIR/_lib_stale_lock.sh" ]; then
  # shellcheck source=_lib_stale_lock.sh
  . "$SCRIPT_DIR/_lib_stale_lock.sh"
  GIT_DIR="$(git rev-parse --git-dir 2>/dev/null || echo '')" maybe_clear_stale_lock
fi

# Shared coordinator lock (T3 — concurrent-coordinator-race-closeout)
# shellcheck source=_lib_coordinator_lock.sh
. "$SCRIPT_DIR/_lib_coordinator_lock.sh"

usage() {
  cat >&2 <<EOF
Usage: $0 <plans/proposed/file.md> <target-status>
  target-status: approved | in-progress | implemented | archived

Moves a plan out of plans/proposed/ into the target directory, running the
Orianna gate before the move. Use this instead of raw 'git mv' for any plan
leaving plans/proposed/.
EOF
  exit 2
}

[ $# -eq 2 ] || usage
SOURCE="$1"
TARGET_STATUS="$2"

# ---------------------------------------------------------------------------
# Advisory coordinator lock — §D9.3
#
# Prevents concurrent plan-promote.sh and orianna-sign.sh invocations from
# racing on the git index (git add → commit window). Both scripts acquire the
# same shared lock via _lib_coordinator_lock.sh. Lockfile lives under .git/
# (never tracked, never in the worktree).
# See: plans/in-progress/personal/2026-04-22-concurrent-coordinator-race-closeout.md T3
# ---------------------------------------------------------------------------
coordinator_lock_acquire "$REPO_ROOT/.git/strawberry-promote.lock"

# 0. Repo identity guard — must be run from inside strawberry-agents, never from a
#    workspace repo (mmp/workspace, strawberry-app, etc.).  Plans live in this repo
#    exclusively.
_claude_md="$REPO_ROOT/CLAUDE.md"
if [ ! -f "$_claude_md" ] || ! grep -qF "Strawberry — Personal Agent System" "$_claude_md"; then
  printf 'plan-promote: must be run from inside the strawberry-agents repo (current: %s).\n' "$REPO_ROOT" >&2
  printf 'Plans live in strawberry-agents/plans/{proposed,approved,...}/{work,personal}/, never in workspace repos.\n' >&2
  exit 1
fi

# 1. Source must live in a known lifecycle directory (not the target directory itself).
# Gate-v2 extends promote to handle all forward transitions:
#   plans/proposed/     → approved | in-progress | implemented | archived
#   plans/approved/     → in-progress | implemented | archived
#   plans/in-progress/  → implemented | archived
# Gate-v1 (legacy fact-check) only ran on proposed→approved; that path is preserved.
case "$SOURCE" in
  plans/proposed/*.md) ;;
  plans/proposed/work/*.md) ;;
  plans/proposed/personal/*.md) ;;
  */plans/proposed/*.md) ;;
  */plans/proposed/work/*.md) ;;
  */plans/proposed/personal/*.md) ;;
  plans/approved/*.md) ;;
  plans/approved/work/*.md) ;;
  plans/approved/personal/*.md) ;;
  */plans/approved/*.md) ;;
  */plans/approved/work/*.md) ;;
  */plans/approved/personal/*.md) ;;
  plans/in-progress/*.md) ;;
  plans/in-progress/work/*.md) ;;
  plans/in-progress/personal/*.md) ;;
  */plans/in-progress/*.md) ;;
  */plans/in-progress/work/*.md) ;;
  */plans/in-progress/personal/*.md) ;;
  *) gdoc::die "plan-promote only handles plans from proposed/, approved/, or in-progress/ (got $SOURCE)" ;;
esac
[ -f "$SOURCE" ] || gdoc::die "no such file: $SOURCE"

# 2. Target status must be a known lifecycle directory.
case "$TARGET_STATUS" in
  approved|in-progress|implemented|archived) ;;
  *) gdoc::die "invalid target status '$TARGET_STATUS'; expected: approved|in-progress|implemented|archived" ;;
esac

gdoc::require_tools
# 3. Target file must be clean.
gdoc::require_clean "$SOURCE"

# 3.5. Orianna gate — runs between step 3 (require clean) and step 5 (git mv).
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
  gdoc::log "legacy fact-check passed — continuing to step 5"

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
  gdoc::log "gate-v2: all Orianna signature checks passed — continuing to step 5"
fi

# 4. (Drive unpublish step removed — Drive mirror feature retired.)
BASENAME=$(basename "$SOURCE")
SOURCE_PARENT="$(dirname "$SOURCE")"
SOURCE_GRANDPARENT="$(dirname "$SOURCE_PARENT")"
SOURCE_PARENT_BASE="$(basename "$SOURCE_PARENT")"
# Detect concern subdir: if the immediate parent is work/ or personal/ then grandparent
# is the phase dir and we must preserve the concern subdir in the destination.
case "$SOURCE_PARENT_BASE" in
  work|personal)
    CONCERN_SUBDIR="/$SOURCE_PARENT_BASE"
    PLANS_ROOT="$(dirname "$SOURCE_GRANDPARENT")"
    ;;
  *)
    CONCERN_SUBDIR=""
    PLANS_ROOT="$SOURCE_GRANDPARENT"
    ;;
esac
TARGET_DIR="${PLANS_ROOT}/${TARGET_STATUS}${CONCERN_SUBDIR}"
TARGET_PATH="$TARGET_DIR/$BASENAME"
# DEST_REL is the repo-relative destination path, used as STAGED_SCOPE when
# invoking orianna-sign.sh so its signing commit is scoped to exactly this file
# and does not absorb concurrent sessions' staged work.
# See: plans/in-progress/personal/2026-04-22-orianna-sign-staged-scope.md T3
DEST_REL="${TARGET_PATH#"$REPO_ROOT/"}"
# Export STAGED_SCOPE scoped to child invocations of orianna-sign.sh only;
# it is unset after this block so callers of plan-promote.sh do not inherit it.
export STAGED_SCOPE="$DEST_REL"

mkdir -p "$TARGET_DIR"

# 5. git mv. File is committed and clean, so the mv is safe.
git -C "$REPO_ROOT" mv "$SOURCE" "$TARGET_PATH"

# 6. Rewrite status: frontmatter to match new directory.
gdoc::frontmatter_set "$TARGET_PATH" status "$TARGET_STATUS"

# Verify the rewrite landed.
if ! grep -qE "^status:[[:space:]]+$TARGET_STATUS\$" "$TARGET_PATH"; then
  gdoc::die "failed to rewrite status field in $TARGET_PATH; manual cleanup needed"
fi

# 7. Commit.
git -C "$REPO_ROOT" add -- "$TARGET_PATH"
git -C "$REPO_ROOT" commit -m "chore: promote $BASENAME to $TARGET_STATUS" >&2
# STAGED_SCOPE was exported above for orianna-sign.sh child invocations; unset now
# so it does not leak to callers of plan-promote.sh or the push step.
unset STAGED_SCOPE

# 8. Push (skipped when NO_PUSH env var is set — for test harnesses without a remote).
if [ -z "${NO_PUSH:-}" ]; then
  git -C "$REPO_ROOT" push >&2
fi

gdoc::log "done. $SOURCE -> $TARGET_PATH"
