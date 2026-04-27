#!/usr/bin/env bash
# scripts/state/refresh-feedback.sh — upsert feedback_index from feedback/**/*.md or fixture
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §T4b
#
# Usage: refresh-feedback.sh <db_path>
#   env T4A_FIXTURE_FEEDBACK_DIR — directory to walk (overrides live feedback/)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=./_lib_db.sh
. "$SCRIPT_DIR/_lib_db.sh"

DB_PATH="${1:?refresh-feedback.sh: db_path required as \$1}"

t_start=$(date +%s 2>/dev/null || echo 0)

if [ -n "${T4A_FIXTURE_FEEDBACK_DIR:-}" ]; then
    FEEDBACK_FILES=$(find "$T4A_FIXTURE_FEEDBACK_DIR" -maxdepth 2 -name "*.md" 2>/dev/null | sort)
else
    FEEDBACK_FILES=$(find "$REPO_ROOT/feedback" -name "*.md" 2>/dev/null | sort)
fi

refreshed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
rows_in=0
rows_out=0

_frontmatter_field() {
    local file="$1" field="$2"
    awk "
    /^---$/ { if (in_fm) exit; in_fm=1; next }
    in_fm && /^$field:/ { sub(/^$field:[[:space:]]*/, \"\"); print; exit }
    " "$file" 2>/dev/null | tr -d "'\""
}

for md_file in $FEEDBACK_FILES; do
    [ -f "$md_file" ] || continue

    severity=$(_frontmatter_field "$md_file" "severity")
    [ -z "$severity" ] && continue

    rows_in=$((rows_in + 1))

    category=$(_frontmatter_field "$md_file" "category")
    status=$(_frontmatter_field "$md_file" "status")
    status="${status:-open}"

    if [ -n "${T4A_FIXTURE_FEEDBACK_DIR:-}" ]; then
        rel_path="$(basename "$md_file")"
    else
        rel_path="${md_file#"$REPO_ROOT"/}"
    fi

    rel_path_esc="${rel_path//\'/\'\'}"
    category_esc="${category//\'/\'\'}"
    severity_esc="${severity//\'/\'\'}"
    status_esc="${status//\'/\'\'}"

    db_write_tx "$DB_PATH" \
        "INSERT INTO feedback_index (path,category,severity,status,refreshed_at)
         VALUES ('$rel_path_esc','$category_esc','$severity_esc','$status_esc','$refreshed_at')
         ON CONFLICT(path) DO UPDATE SET
           category=excluded.category, severity=excluded.severity,
           status=excluded.status, refreshed_at=excluded.refreshed_at;"
    rows_out=$((rows_out + 1))
done

t_end=$(date +%s 2>/dev/null || echo 0)
duration_ms=$(( (t_end - t_start) * 1000 ))

db_write_tx "$DB_PATH" \
    "INSERT INTO refresh_log (projection,last_refreshed_at,duration_ms,rows_in,rows_out)
     VALUES ('feedback_index','$refreshed_at',$duration_ms,$rows_in,$rows_out)
     ON CONFLICT(projection) DO UPDATE SET
       last_refreshed_at=excluded.last_refreshed_at,
       duration_ms=excluded.duration_ms,
       rows_in=excluded.rows_in,
       rows_out=excluded.rows_out;"
