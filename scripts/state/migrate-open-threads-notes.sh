#!/usr/bin/env bash
# scripts/state/migrate-open-threads-notes.sh
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §T7b
#
# Usage:
#   bash migrate-open-threads-notes.sh --db <path> --file <open-threads.md> --coordinator <name>
#
# Parses ## headings from the source file, inserts/upserts rows into open_threads.note
# via _lib_db.sh helpers. Idempotent (UPSERT on coordinator+source_kind+source_ref).
# Does NOT archive or delete source files — archive step is caller's responsibility.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB_DB="$REPO_ROOT/scripts/state/_lib_db.sh"

if [ ! -f "$LIB_DB" ]; then
    printf '[migrate-open-threads-notes] ERROR: _lib_db.sh not found: %s\n' "$LIB_DB" >&2
    exit 1
fi
# shellcheck source=/dev/null
. "$LIB_DB"

usage() {
    printf 'Usage: %s --db <path> --file <open-threads.md> --coordinator <name>\n' "$0" >&2
    exit 1
}

DB_PATH=""
SOURCE_FILE=""
COORDINATOR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --db)         DB_PATH="$2";      shift 2 ;;
        --file)       SOURCE_FILE="$2";  shift 2 ;;
        --coordinator) COORDINATOR="$2"; shift 2 ;;
        *) usage ;;
    esac
done

[ -n "$DB_PATH" ]      || usage
[ -n "$SOURCE_FILE" ]  || usage
[ -n "$COORDINATOR" ]  || usage

if [ ! -f "$SOURCE_FILE" ]; then
    printf '[migrate-open-threads-notes] ERROR: source file not found: %s\n' "$SOURCE_FILE" >&2
    exit 1
fi

if [ ! -f "$DB_PATH" ]; then
    printf '[migrate-open-threads-notes] ERROR: database not found: %s\n' "$DB_PATH" >&2
    exit 1
fi

# Infer a stable source_ref from a heading line.
# Strategy: use the full heading text as source_ref — it is unique per thread
# and preserves all pin-searchable substrings (PR #N, plan names, descriptors).
make_source_ref() {
    printf '%s' "$1"
}

# Infer status from heading suffix keywords.
infer_status() {
    local heading="$1"
    case "$heading" in
        *SHIPPED*|*MERGED*|*RESOLVED*|*REMOVED*|*MOOT*|*CLOSED*|*DONE*|*COMPLETE*) printf 'resolved' ;;
        *in-progress*|*in_progress*|*open*|*live*|*pending*) printf 'open' ;;
        *) printf 'open' ;;
    esac
}

# sql_escape: double single-quotes for safe SQLite literal embedding.
sql_escape() {
    printf '%s' "$1" | sed "s/'/''/g"
}

TODAY="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SOURCE_KIND="open-thread"

# Parse the file: extract ## headings and the body text that follows each heading.
# We accumulate body lines until the next ## heading or EOF, then flush the row.

current_heading=""
current_body=""

flush_row() {
    local heading="$1"
    local body="$2"

    [ -n "$heading" ] || return 0

    local source_ref status title note
    source_ref="$(make_source_ref "$heading")"
    status="$(infer_status "$heading")"
    title="$heading"
    # Strip leading/trailing blank lines from the body.
    note="$(printf '%s' "$body" | sed '/^[[:space:]]*$/d' | sed -e 's/^[[:space:]]*//' | awk 'NF{found=1} found{print}')"

    local esc_coordinator esc_source_kind esc_source_ref esc_title esc_status esc_note esc_today
    esc_coordinator="$(sql_escape "$COORDINATOR")"
    esc_source_kind="$(sql_escape "$SOURCE_KIND")"
    esc_source_ref="$(sql_escape "$source_ref")"
    esc_title="$(sql_escape "$title")"
    esc_status="$(sql_escape "$status")"
    esc_note="$(sql_escape "$note")"
    esc_today="$(sql_escape "$TODAY")"

    # INSERT OR REPLACE gives full UPSERT semantics: if the UNIQUE key
    # (coordinator, source_kind, source_ref) already exists, the row is replaced
    # with the new note content — satisfying §6 of the test (sentinel overwrite).
    db_write_tx "$DB_PATH" \
        "INSERT OR REPLACE INTO open_threads
           (coordinator, source_kind, source_ref, title, status, note, pinned, last_touched)
         VALUES
           ('${esc_coordinator}', '${esc_source_kind}', '${esc_source_ref}',
            '${esc_title}', '${esc_status}', '${esc_note}', 0, '${esc_today}');"
}

while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        '## '*)
            # Flush the previous heading+body pair before starting a new one.
            flush_row "$current_heading" "$current_body"
            # Strip the "## " prefix to get the heading text.
            current_heading="${line#'## '}"
            current_body=""
            ;;
        *)
            if [ -n "$current_heading" ]; then
                current_body="${current_body}
${line}"
            fi
            ;;
    esac
done < "$SOURCE_FILE"

# Flush the final heading.
flush_row "$current_heading" "$current_body"

printf '[migrate-open-threads-notes] done: coordinator=%s file=%s\n' "$COORDINATOR" "$SOURCE_FILE" >&2
