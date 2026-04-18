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

# 3.5. Fact-check gate — runs between step 3 (require clean) and step 4 (Drive unpublish)
# so that Drive is never touched for plans that fail fact-check.
# No bypass flag. Human override: use raw git mv instead of this script.
gdoc::log "running fact-check gate on: $SOURCE"
FACT_CHECK_RC=0
"$SCRIPT_DIR/orianna-fact-check.sh" "$SOURCE" || FACT_CHECK_RC=$?
if [ "$FACT_CHECK_RC" -ne 0 ]; then
  gdoc::log "fact-check returned non-zero exit ($FACT_CHECK_RC) — promotion halted"
  # Show block-severity findings from the most-recent report for this plan.
  REPORT_DIR="$REPO_ROOT/assessments/plan-fact-checks"
  PLAN_BASENAME="$(basename "$SOURCE" .md)"
  LATEST_REPORT=""
  for _r in "$REPORT_DIR"/${PLAN_BASENAME}-*.md; do
    [ -f "$_r" ] && LATEST_REPORT="$_r"
  done
  if [ -n "$LATEST_REPORT" ]; then
    gdoc::log "report: $LATEST_REPORT"
    # Print block findings section to stderr.
    awk '/^## Block findings/{p=1; next} /^## Warn findings/{p=0} p && /[^[:space:]]/' \
      "$LATEST_REPORT" >&2 || true
  fi
  exit 1
fi
gdoc::log "fact-check passed — continuing to step 4"

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
