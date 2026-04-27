#!/usr/bin/env bash
# scripts/state/refresh-projects.sh — upsert projects_index from projects/**/*.md or fixture
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §T4b
#
# Usage: refresh-projects.sh <db_path>
#   env T4A_FIXTURE_PROJECTS_DIR — directory to walk (overrides live projects/)
#   env STRAWBERRY_STATE_DB      — override db_path default (~/.strawberry-state/state.db)

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
         VALUES ('projects_index',strftime('%Y-%m-%d %H:%M:%f','now'),$duration_ms,$rows_in,$rows_out)
         ON CONFLICT(projection) DO UPDATE SET
           last_refreshed_at=strftime('%Y-%m-%d %H:%M:%f','now'),
           duration_ms=excluded.duration_ms,
           rows_in=excluded.rows_in,
           rows_out=excluded.rows_out;" 2>/dev/null || true
}
trap '_emit_refresh_log' EXIT

if [ -n "${T4A_FIXTURE_PROJECTS_DIR:-}" ]; then
    SCAN_DIR="$T4A_FIXTURE_PROJECTS_DIR"
else
    SCAN_DIR="$REPO_ROOT/projects"
fi

_frontmatter_field() {
    local file="$1" field="$2"
    awk "
    /^---$/ { if (in_fm) exit; in_fm=1; next }
    in_fm && /^$field:/ { sub(/^$field:[[:space:]]*/, \"\"); print; exit }
    " "$file" 2>/dev/null | tr -d "'\""
}

while IFS= read -r -d '' md_file; do
    [ -f "$md_file" ] || continue

    status=$(_frontmatter_field "$md_file" "status")
    [ -z "$status" ] && continue

    rows_in=$((rows_in + 1))

    concern=$(_frontmatter_field "$md_file" "concern")
    deadline=$(_frontmatter_field "$md_file" "deadline")
    slug="$(basename "$md_file" .md)"

    db_write_tx "$DB_PATH" \
        "INSERT INTO projects_index (slug,status,concern,deadline,refreshed_at)
         VALUES ('$(_esc "$slug")','$(_esc "$status")','$(_esc "${concern:-personal}")',
                 '$(_esc "$deadline")',strftime('%Y-%m-%d %H:%M:%f','now'))
         ON CONFLICT(slug) DO UPDATE SET
           status=excluded.status, concern=excluded.concern,
           deadline=excluded.deadline, refreshed_at=strftime('%Y-%m-%d %H:%M:%f','now');"
    rows_out=$((rows_out + 1))
done < <(find "$SCAN_DIR" -name "*.md" -print0 2>/dev/null | sort -z)
