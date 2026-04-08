#!/usr/bin/env bash
# plan-unpublish.sh — trash the Google Doc associated with a plan and strip
# the gdoc_id/gdoc_url frontmatter fields.
#
# Usage:
#   ./scripts/plan-unpublish.sh plans/implemented/2026-04-08-foo.md
#
# No-op if the file has no gdoc_id. Trashes (not hard-deletes) the doc per
# Decision 2 in the plan, so Duong has a 30-day recovery window.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib_gdoc.sh
. "$SCRIPT_DIR/_lib_gdoc.sh"

usage() {
  cat >&2 <<EOF
Usage: $0 <plan-file.md>
Trashes the linked Google Doc and removes gdoc_id/gdoc_url from frontmatter.
EOF
  exit 2
}

[ $# -eq 1 ] || usage
TARGET="$1"

[ -f "$TARGET" ] || gdoc::die "no such file: $TARGET"
gdoc::require_tools
gdoc::require_clean "$TARGET"

GDOC_ID=$(gdoc::frontmatter_get "$TARGET" gdoc_id || true)
if [ -z "$GDOC_ID" ]; then
  gdoc::log "no gdoc_id in $TARGET; nothing to unpublish"
  exit 0
fi

_unpublish_with_secrets() {
  local response_code
  response_code=$(curl -sS -o /tmp/plan-unpublish-resp.$$ -w '%{http_code}' -X PATCH \
    -H "Authorization: Bearer $GDOC_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"trashed":true}' \
    "https://www.googleapis.com/drive/v3/files/$GDOC_ID")
  case "$response_code" in
    200)
      gdoc::log "trashed gdoc $GDOC_ID"
      ;;
    404)
      gdoc::log "gdoc $GDOC_ID already gone (404); treating as success"
      ;;
    *)
      gdoc::die "trash request returned HTTP $response_code: $(cat /tmp/plan-unpublish-resp.$$)"
      ;;
  esac
  rm -f /tmp/plan-unpublish-resp.$$
}

gdoc::with_secrets _unpublish_with_secrets

gdoc::frontmatter_unset "$TARGET" gdoc_id
gdoc::frontmatter_unset "$TARGET" gdoc_url

git -C "$REPO_ROOT" add -- "$TARGET"
git -C "$REPO_ROOT" commit -m "chore: unpublish gdoc for $(basename "$TARGET")" >&2

gdoc::log "done"
