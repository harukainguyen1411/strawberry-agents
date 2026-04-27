#!/usr/bin/env bash
# scripts/state/refresh-inbox.sh — upsert inbox_index from agents/{evelynn,sona}/inbox/*.md or fixture
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §T4b
#
# Usage: refresh-inbox.sh <db_path>
#   env T4A_FIXTURE_INBOX_DIR — directory to walk for inbox .md files (overrides live paths)
#   env STRAWBERRY_STATE_DB   — override db_path default (~/.strawberry-state/state.db)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=./_lib_db.sh
. "$SCRIPT_DIR/_lib_db.sh"

DB_PATH="${1:-${STRAWBERRY_STATE_DB:-$HOME/.strawberry-state/state.db}}"

t_start=$(date +%s 2>/dev/null || echo 0)
rows_in=0
rows_out=0

_esc() { printf '%s' "${1//\'/\'\'}"; }

_emit_refresh_log() {
    local t_end duration_ms
    t_end=$(date +%s 2>/dev/null || echo 0)
    duration_ms=$(( (t_end - t_start) * 1000 ))
    db_write_tx "$DB_PATH" \
        "INSERT INTO refresh_log (projection,last_refreshed_at,duration_ms,rows_in,rows_out)
         VALUES ('inbox_index',strftime('%Y-%m-%d %H:%M:%f','now'),$duration_ms,$rows_in,$rows_out)
         ON CONFLICT(projection) DO UPDATE SET
           last_refreshed_at=strftime('%Y-%m-%d %H:%M:%f','now'),
           duration_ms=excluded.duration_ms,
           rows_in=excluded.rows_in,
           rows_out=excluded.rows_out;" 2>/dev/null || true
}
trap '_emit_refresh_log' EXIT

_file_mtime_iso() {
    local file="$1"
    local ts
    ts=$(stat -f "%Sm" -t "%Y-%m-%dT%H:%M:%SZ" "$file" 2>/dev/null \
         || stat -c "%Y" "$file" 2>/dev/null | xargs -I{} date -d "@{}" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
         || date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "$ts"
}

if [ -n "${T4A_FIXTURE_INBOX_DIR:-}" ]; then
    FIND_ARGS=("$T4A_FIXTURE_INBOX_DIR")
else
    FIND_ARGS=("$REPO_ROOT/agents/evelynn/inbox" "$REPO_ROOT/agents/sona/inbox")
fi

while IFS= read -r -d '' md_file; do
    [ -f "$md_file" ] || continue
    rows_in=$((rows_in + 1))

    if [ -n "${T4A_FIXTURE_INBOX_DIR:-}" ]; then
        recipient="evelynn"
        rel_path="$(basename "$md_file")"
    else
        tmp="${md_file##*/agents/}"; recipient="${tmp%%/inbox/*}"
        rel_path="${md_file#"$REPO_ROOT"/}"
    fi

    arrived_at=$(_file_mtime_iso "$md_file")

    db_write_tx "$DB_PATH" \
        "INSERT INTO inbox_index (path,recipient,arrived_at,archived,refreshed_at)
         VALUES ('$(_esc "$rel_path")','$(_esc "$recipient")','$(_esc "$arrived_at")',
                 0,strftime('%Y-%m-%d %H:%M:%f','now'))
         ON CONFLICT(path) DO UPDATE SET
           recipient=excluded.recipient,
           arrived_at=excluded.arrived_at,
           refreshed_at=strftime('%Y-%m-%d %H:%M:%f','now');"
    rows_out=$((rows_out + 1))
done < <(find "${FIND_ARGS[@]}" -name "*.md" -print0 2>/dev/null | sort -z)
