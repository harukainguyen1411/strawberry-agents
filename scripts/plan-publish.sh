#!/usr/bin/env bash
# plan-publish.sh — push a plan markdown file into Google Drive as a Google Doc.
#
# Usage:
#   ./scripts/plan-publish.sh plans/proposed/2026-04-08-foo.md
#
# Idempotent. If the file already has a `gdoc_id` and the doc still exists,
# the doc body is replaced in place. Otherwise a new doc is created in the
# configured Drive folder and the id is written back into the file frontmatter.
#
# After a successful publish, the script commits the frontmatter change with
# a `chore:` prefix.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib_gdoc.sh
. "$SCRIPT_DIR/_lib_gdoc.sh"

usage() {
  cat >&2 <<EOF
Usage: $0 <plan-file.md>
Publishes the plan markdown file as a Google Doc in the configured Drive folder.
EOF
  exit 2
}

[ $# -eq 1 ] || usage
TARGET="$1"

[ -f "$TARGET" ] || gdoc::die "no such file: $TARGET"
case "$TARGET" in
  plans/*) ;;
  */plans/*) ;;
  *) gdoc::die "refusing to publish files outside plans/: $TARGET" ;;
esac

gdoc::require_tools
gdoc::require_clean "$TARGET"

DOC_TITLE=$(gdoc::doc_title_for "$TARGET")
EXISTING_GDOC_ID=$(gdoc::frontmatter_get "$TARGET" gdoc_id || true)

# Build the wrapped markdown body in a temp file.
WRAPPED=$(mktemp --suffix=.md)
trap 'rm -f "$WRAPPED"' EXIT
gdoc::wrap_frontmatter <"$TARGET" >"$WRAPPED"

_publish_with_secrets() {
  local boundary="strawberry-$(date +%s)-$$"
  local upload_url="https://www.googleapis.com/upload/drive/v3/files"
  local existing="$EXISTING_GDOC_ID"

  # If we already have a gdoc id, check whether it still exists.
  if [ -n "$existing" ]; then
    local check
    check=$(curl -sS -o /dev/null -w '%{http_code}' \
      -H "Authorization: Bearer $GDOC_ACCESS_TOKEN" \
      "https://www.googleapis.com/drive/v3/files/$existing?fields=id,trashed")
    if [ "$check" != "200" ]; then
      gdoc::log "previous gdoc_id $existing not reachable (HTTP $check); creating a new doc"
      existing=""
    fi
  fi

  local response
  if [ -n "$existing" ]; then
    # Update the body of the existing doc via media upload (PATCH).
    response=$(curl -sS -X PATCH \
      -H "Authorization: Bearer $GDOC_ACCESS_TOKEN" \
      -H "Content-Type: text/markdown" \
      --data-binary "@$WRAPPED" \
      "$upload_url/$existing?uploadType=media")
    NEW_ID=$(jq -r '.id // empty' <<<"$response")
    if [ -z "$NEW_ID" ]; then
      gdoc::die "update failed: $(jq -c '.error // .' <<<"$response")"
    fi
    gdoc::log "updated existing gdoc $NEW_ID"
  else
    # Create a new doc by uploading markdown and asking Drive to convert it.
    # Multipart upload: metadata part + media part.
    local meta_file body_file
    meta_file=$(mktemp)
    body_file=$(mktemp)
    jq -n --arg title "$DOC_TITLE" --arg parent "$GDRIVE_PLANS_FOLDER_ID" \
      '{name:$title, mimeType:"application/vnd.google-apps.document", parents:[$parent]}' >"$meta_file"

    {
      printf -- '--%s\r\n' "$boundary"
      printf 'Content-Type: application/json; charset=UTF-8\r\n\r\n'
      cat "$meta_file"
      printf '\r\n--%s\r\n' "$boundary"
      printf 'Content-Type: text/markdown\r\n\r\n'
      cat "$WRAPPED"
      printf '\r\n--%s--\r\n' "$boundary"
    } >"$body_file"

    response=$(curl -sS -X POST \
      -H "Authorization: Bearer $GDOC_ACCESS_TOKEN" \
      -H "Content-Type: multipart/related; boundary=$boundary" \
      --data-binary "@$body_file" \
      "$upload_url?uploadType=multipart&supportsAllDrives=true")
    rm -f "$meta_file" "$body_file"
    NEW_ID=$(jq -r '.id // empty' <<<"$response")
    if [ -z "$NEW_ID" ]; then
      gdoc::die "create failed: $(jq -c '.error // .' <<<"$response")"
    fi
    gdoc::log "created new gdoc $NEW_ID titled '$DOC_TITLE'"
  fi
  printf '%s\n' "$NEW_ID" >"$WRAPPED.id"
}

gdoc::with_secrets _publish_with_secrets

NEW_ID=$(cat "$WRAPPED.id")
rm -f "$WRAPPED.id"
[ -n "$NEW_ID" ] || gdoc::die "publish returned no doc id"

gdoc::frontmatter_set "$TARGET" gdoc_id "$NEW_ID"
gdoc::frontmatter_set "$TARGET" gdoc_url "https://docs.google.com/document/d/$NEW_ID/edit"

git -C "$REPO_ROOT" add -- "$TARGET"
git -C "$REPO_ROOT" commit -m "chore: link gdoc for $(basename "$TARGET")" >&2

gdoc::log "done. doc id: $NEW_ID"
gdoc::log "url: https://docs.google.com/document/d/$NEW_ID/edit"
