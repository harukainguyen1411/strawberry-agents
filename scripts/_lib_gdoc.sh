#!/usr/bin/env bash
# Shared helpers for plan lifecycle scripts (plan-promote.sh, plan-fetch.sh).
# Source this from those scripts. Do not run directly.
#
# Discipline:
#   - Plaintext credentials live only inside this file's functions, never
#     leak to the calling script's globals.
#   - We never `echo`, `printf`, `set -x`, or otherwise log credential values.
#   - Functions return only their intended output (e.g. an access token,
#     a doc id) on stdout. Errors go to stderr.

set -euo pipefail

# Resolve repo root regardless of where the caller invoked from.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Plaintext credential files this library reads. Each file holds a single
# KEY=value line. They are populated by `tools/decrypt.sh` from the encrypted
# blobs in secrets/encrypted/. They are gitignored. This library never
# invokes the age binary directly; decryption is tools/decrypt.sh's job.
GDOC_SECRETS_DIR="${GDOC_SECRETS_DIR:-$REPO_ROOT/secrets}"
GDOC_FILE_CLIENT_ID="$GDOC_SECRETS_DIR/google-client-id.env"
GDOC_FILE_CLIENT_SECRET="$GDOC_SECRETS_DIR/google-client-secret.env"
GDOC_FILE_REFRESH_TOKEN="$GDOC_SECRETS_DIR/google-refresh-token.env"
GDOC_FILE_FOLDER_ID="$GDOC_SECRETS_DIR/google-drive-plans-folder-id.env"

GDOC_DOC_TITLE_PREFIX="[strawberry] "

# Print a message to stderr.
gdoc::log() {
  printf '[plan-gdoc-mirror] %s\n' "$*" >&2
}

gdoc::die() {
  gdoc::log "ERROR: $*"
  exit 1
}

# Verify required tools are present.
gdoc::require_tools() {
  for tool in curl jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      gdoc::die "missing required tool: $tool"
    fi
  done
}

# Refuse to operate on a target file with uncommitted changes.
# Usage: gdoc::require_clean <path>
gdoc::require_clean() {
  local target="$1"
  if [ -n "$(git -C "$REPO_ROOT" status --porcelain -- "$target" 2>/dev/null)" ]; then
    gdoc::die "$target has uncommitted changes; commit or stash first"
  fi
}

# Source the four single-key plaintext credential files.
# Each file is one `KEY=value` line written by tools/decrypt.sh.
# This is the ONE function allowed to materialize plaintext credentials.
gdoc::_load_secrets() {
  local f
  for f in "$GDOC_FILE_CLIENT_ID" "$GDOC_FILE_CLIENT_SECRET" "$GDOC_FILE_REFRESH_TOKEN" "$GDOC_FILE_FOLDER_ID"; do
    if [ ! -f "$f" ]; then
      gdoc::die "missing credential file: $f
hint: decrypt the corresponding secrets/encrypted/*.age blob via tools/decrypt.sh.
Run tools/decrypt.sh to populate secrets before using Drive-backed scripts."
    fi
  done
  # shellcheck disable=SC1090
  . "$GDOC_FILE_CLIENT_ID"
  # shellcheck disable=SC1090
  . "$GDOC_FILE_CLIENT_SECRET"
  # shellcheck disable=SC1090
  . "$GDOC_FILE_REFRESH_TOKEN"
  # shellcheck disable=SC1090
  . "$GDOC_FILE_FOLDER_ID"
}

# Run a callback function with secrets available as local-scope variables.
# Usage: gdoc::with_secrets <callback_fn> [args...]
# The callback receives the access token + folder id as env vars:
#   GDOC_ACCESS_TOKEN, GDRIVE_PLANS_FOLDER_ID
# Plaintext is scoped to the callback's process; nothing leaks back.
gdoc::with_secrets() {
  local cb="$1"
  shift
  (
    set +x
    local GOOGLE_CLIENT_ID="" GOOGLE_CLIENT_SECRET="" GOOGLE_REFRESH_TOKEN="" GDRIVE_PLANS_FOLDER_ID=""
    gdoc::_load_secrets

    if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ] || [ -z "$GOOGLE_REFRESH_TOKEN" ] || [ -z "$GDRIVE_PLANS_FOLDER_ID" ]; then
      gdoc::die "credential files exist but did not populate GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET / GOOGLE_REFRESH_TOKEN / GDRIVE_PLANS_FOLDER_ID"
    fi

    local token_response
    token_response=$(curl -sS -X POST https://oauth2.googleapis.com/token \
      --data-urlencode "client_id=$GOOGLE_CLIENT_ID" \
      --data-urlencode "client_secret=$GOOGLE_CLIENT_SECRET" \
      --data-urlencode "refresh_token=$GOOGLE_REFRESH_TOKEN" \
      --data-urlencode "grant_type=refresh_token")
    GOOGLE_CLIENT_ID=""
    GOOGLE_CLIENT_SECRET=""
    GOOGLE_REFRESH_TOKEN=""

    local access_token
    access_token=$(jq -r '.access_token // empty' <<<"$token_response")
    if [ -z "$access_token" ]; then
      local err
      err=$(jq -r '.error // "unknown"' <<<"$token_response")
      gdoc::die "failed to mint access token: $err (re-run scripts/google-oauth-bootstrap.sh if 'invalid_grant')"
    fi
    token_response=""

    GDOC_ACCESS_TOKEN="$access_token" GDRIVE_PLANS_FOLDER_ID="$GDRIVE_PLANS_FOLDER_ID" "$cb" "$@"
  )
}

# --- Frontmatter helpers (operate on plain markdown files, not secrets) ----

# Extract a frontmatter field. Echoes value or empty string.
# Usage: gdoc::frontmatter_get <file> <field>
gdoc::frontmatter_get() {
  local file="$1" field="$2"
  awk -v f="$field" '
    BEGIN { in_fm=0; n=0 }
    /^---[[:space:]]*$/ { n++; if (n==1) {in_fm=1; next} else {exit} }
    in_fm && $0 ~ "^"f":[[:space:]]" {
      sub("^"f":[[:space:]]*", "", $0)
      print $0
      exit
    }
  ' "$file"
}

# Set or update a frontmatter field. If not present, append before closing `---`.
# Usage: gdoc::frontmatter_set <file> <field> <value>
gdoc::frontmatter_set() {
  local file="$1" field="$2" value="$3"
  local tmp
  tmp=$(mktemp)
  awk -v f="$field" -v v="$value" '
    BEGIN { in_fm=0; n=0; set=0 }
    {
      if ($0 ~ /^---[[:space:]]*$/) {
        n++
        if (n==1) { in_fm=1; print; next }
        if (n==2) {
          if (!set && in_fm) { print f": "v; set=1 }
          in_fm=0; print; next
        }
      }
      if (in_fm && $0 ~ "^"f":[[:space:]]") {
        print f": "v
        set=1
        next
      }
      print
    }
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

# Remove a frontmatter field if present.
# Usage: gdoc::frontmatter_unset <file> <field>
gdoc::frontmatter_unset() {
  local file="$1" field="$2"
  local tmp
  tmp=$(mktemp)
  awk -v f="$field" '
    BEGIN { in_fm=0; n=0 }
    {
      if ($0 ~ /^---[[:space:]]*$/) {
        n++
        if (n==1) { in_fm=1; print; next }
        if (n==2) { in_fm=0; print; next }
      }
      if (in_fm && $0 ~ "^"f":[[:space:]]") next
      print
    }
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

# Wrap a markdown file's YAML frontmatter in a fenced ```yaml plan-frontmatter block
# so that Drive's markdown converter doesn't render it as a literal paragraph.
# Reads from stdin, writes to stdout.
gdoc::wrap_frontmatter() {
  awk '
    BEGIN { in_fm=0; n=0; emitted_open=0 }
    {
      if ($0 ~ /^---[[:space:]]*$/) {
        n++
        if (n==1) {
          in_fm=1
          print "```yaml plan-frontmatter"
          next
        }
        if (n==2) {
          in_fm=0
          print "```"
          next
        }
      }
      print
    }
  '
}

# Inverse of wrap_frontmatter. If the wrapped block is present, unwrap it back
# to ---/--- frontmatter delimiters. If not present, leave content untouched.
# Reads from stdin, writes to stdout.
gdoc::unwrap_frontmatter() {
  awk '
    BEGIN { in_block=0; seen=0 }
    {
      if (!seen && $0 ~ /^```yaml plan-frontmatter[[:space:]]*$/) {
        in_block=1; seen=1
        print "---"
        next
      }
      if (in_block && $0 ~ /^```[[:space:]]*$/) {
        in_block=0
        print "---"
        next
      }
      print
    }
  '
}

# Convert plan filename (basename without .md) into Drive doc title.
gdoc::doc_title_for() {
  local file="$1"
  local base
  base=$(basename "$file" .md)
  printf '%s%s' "$GDOC_DOC_TITLE_PREFIX" "$base"
}
