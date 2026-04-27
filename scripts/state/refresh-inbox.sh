#!/usr/bin/env bash
# scripts/state/refresh-inbox.sh — upsert inbox_index from agents/{evelynn,sona}/inbox/*.md or fixture
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §T4b
#
# Usage: refresh-inbox.sh <db_path>
#   env T4A_FIXTURE_INBOX_DIR — directory to walk for inbox .md files (overrides live paths)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=./_lib_db.sh
. "$SCRIPT_DIR/_lib_db.sh"

DB_PATH="${1:?refresh-inbox.sh: db_path required as \$1}"

t_start=$(date +%s 2>/dev/null || echo 0)

if [ -n "${T4A_FIXTURE_INBOX_DIR:-}" ]; then
    INBOX_FILES=$(find "$T4A_FIXTURE_INBOX_DIR" -maxdepth 2 -name "*.md" 2>/dev/null | sort)
else
    INBOX_FILES=$(find "$REPO_ROOT/agents/evelynn/inbox" "$REPO_ROOT/agents/sona/inbox" \
        -name "*.md" 2>/dev/null | sort)
fi

rows_in=0
rows_out=0

_file_mtime_iso() {
    local file="$1"
    local ts
    ts=$(stat -f "%Sm" -t "%Y-%m-%dT%H:%M:%SZ" "$file" 2>/dev/null \
         || stat -c "%Y" "$file" 2>/dev/null | xargs -I{} date -d "@{}" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
         || date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "$ts"
}

for md_file in $INBOX_FILES; do
    [ -f "$md_file" ] || continue
    rows_in=$((rows_in + 1))

    # Derive recipient from path: agents/<recipient>/inbox/... or fixture flat
    if [ -n "${T4A_FIXTURE_INBOX_DIR:-}" ]; then
        recipient="evelynn"
    else
        # Extract coordinator name from path segment
        tmp="${md_file##*/agents/}"; recipient="${tmp%%/inbox/*}"
    fi

    arrived_at=$(_file_mtime_iso "$md_file")

    if [ -n "${T4A_FIXTURE_INBOX_DIR:-}" ]; then
        rel_path="$(basename "$md_file")"
    else
        rel_path="${md_file#"$REPO_ROOT"/}"
    fi

    rel_path_esc="${rel_path//\'/\'\'}"
    recipient_esc="${recipient//\'/\'\'}"
    arrived_at_esc="${arrived_at//\'/\'\'}"

    db_write_tx "$DB_PATH" \
        "INSERT INTO inbox_index (path,recipient,arrived_at,archived,refreshed_at)
         VALUES ('$rel_path_esc','$recipient_esc','$arrived_at_esc',0,strftime('%Y-%m-%d %H:%M:%f','now'))
         ON CONFLICT(path) DO UPDATE SET
           recipient=excluded.recipient,
           arrived_at=excluded.arrived_at,
           refreshed_at=excluded.refreshed_at;"
    rows_out=$((rows_out + 1))
done

t_end=$(date +%s 2>/dev/null || echo 0)
duration_ms=$(( (t_end - t_start) * 1000 ))

db_write_tx "$DB_PATH" \
    "INSERT INTO refresh_log (projection,last_refreshed_at,duration_ms,rows_in,rows_out)
     VALUES ('inbox_index',strftime('%Y-%m-%d %H:%M:%f','now'),$duration_ms,$rows_in,$rows_out)
     ON CONFLICT(projection) DO UPDATE SET
       last_refreshed_at=strftime('%Y-%m-%d %H:%M:%f','now'),
       duration_ms=excluded.duration_ms,
       rows_in=excluded.rows_in,
       rows_out=excluded.rows_out;"
