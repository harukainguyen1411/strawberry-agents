#!/usr/bin/env bash
# plan-fetch.sh — pull a previously-published Google Doc back into the repo as
# the approved version of a plan, replacing the proposed version.
#
# Usage:
#   ./scripts/plan-fetch.sh plans/proposed/2026-04-08-foo.md
#
# After fetch:
#   - plans/proposed/<file>.md is deleted
#   - plans/approved/<file>.md is written with whatever Drive currently holds
#   - the gdoc_id is preserved (cleanup happens in plan-unpublish.sh)
#   - the change is committed with a chore: prefix
#
# Drive content is canonical during the review window. Local edits to the
# proposed file are clobbered.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib_gdoc.sh
. "$SCRIPT_DIR/_lib_gdoc.sh"

usage() {
  cat >&2 <<EOF
Usage: $0 <plans/proposed/file.md>
Downloads the linked Google Doc as markdown and writes it to plans/approved/.
EOF
  exit 2
}

[ $# -eq 1 ] || usage
TARGET="$1"

[ -f "$TARGET" ] || gdoc::die "no such file: $TARGET"
case "$TARGET" in
  plans/proposed/*) ;;
  */plans/proposed/*) ;;
  *) gdoc::die "fetch only handles plans/proposed/*.md (got $TARGET)" ;;
esac

gdoc::require_tools
gdoc::require_clean "$TARGET"

GDOC_ID=$(gdoc::frontmatter_get "$TARGET" gdoc_id || true)
[ -n "$GDOC_ID" ] || gdoc::die "$TARGET has no gdoc_id frontmatter — was it ever published?"

DOWNLOADED=$(mktemp --suffix=.md)
trap 'rm -f "$DOWNLOADED"' EXIT

_fetch_with_secrets() {
  local response_code
  response_code=$(curl -sS -o "$DOWNLOADED" -w '%{http_code}' \
    -H "Authorization: Bearer $GDOC_ACCESS_TOKEN" \
    "https://www.googleapis.com/drive/v3/files/$GDOC_ID/export?mimeType=text/markdown")
  if [ "$response_code" != "200" ]; then
    gdoc::die "drive export returned HTTP $response_code: $(cat "$DOWNLOADED")"
  fi
}

gdoc::with_secrets _fetch_with_secrets

# Unwrap frontmatter back from the fenced block.
UNWRAPPED=$(mktemp --suffix=.md)
gdoc::unwrap_frontmatter <"$DOWNLOADED" >"$UNWRAPPED"

# If the unwrapped file does not start with `---`, Duong probably deleted the
# plan-frontmatter block in the doc. Fall back to the on-disk frontmatter.
if ! head -1 "$UNWRAPPED" | grep -q '^---[[:space:]]*$'; then
  gdoc::log "no frontmatter found in fetched markdown; reusing on-disk frontmatter"
  ORIG_FM=$(mktemp)
  awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; print; if (n==2) exit; next} n==1{print}' "$TARGET" >"$ORIG_FM"
  MERGED=$(mktemp --suffix=.md)
  cat "$ORIG_FM" "$UNWRAPPED" >"$MERGED"
  mv "$MERGED" "$UNWRAPPED"
  rm -f "$ORIG_FM"
fi

# Update the status frontmatter to "approved" since we're moving directories.
gdoc::frontmatter_set "$UNWRAPPED" status approved

# Compute target path: plans/proposed/foo.md -> plans/approved/foo.md
BASENAME=$(basename "$TARGET")
APPROVED_DIR="$(dirname "$(dirname "$TARGET")")/approved"
APPROVED_PATH="$APPROVED_DIR/$BASENAME"

mkdir -p "$APPROVED_DIR"
cp "$UNWRAPPED" "$APPROVED_PATH"
rm -f "$UNWRAPPED"

git -C "$REPO_ROOT" rm -- "$TARGET" >/dev/null
git -C "$REPO_ROOT" add -- "$APPROVED_PATH"
git -C "$REPO_ROOT" commit -m "chore: approve $BASENAME via gdoc fetch" >&2

gdoc::log "done. $TARGET -> $APPROVED_PATH"
gdoc::log "drive doc $GDOC_ID still exists; run plan-unpublish.sh when ready"
