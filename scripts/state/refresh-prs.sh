#!/usr/bin/env bash
# scripts/state/refresh-prs.sh — upsert prs_index from gh pr list or fixture
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §T4b
#
# Usage: refresh-prs.sh <db_path>
#   env T4A_FIXTURE_PRS        — path to JSON fixture (overrides live gh pr list)
#   env STRAWBERRY_STATE_DB    — override db_path default (~/.strawberry-state/state.db)
#
# gh pr list output cached for 60s at /tmp/strawberry-prs-cache.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./_lib_db.sh
. "$SCRIPT_DIR/_lib_db.sh"

DB_PATH="${1:-${STRAWBERRY_STATE_DB:-$HOME/.strawberry-state/state.db}}"
CACHE_FILE="/tmp/strawberry-prs-cache.json"
CACHE_TTL=60

t_start=$(date +%s 2>/dev/null || echo 0)
rows_in=0
rows_out=0
TSV_FILE="/tmp/strawberry-prs-$$.tsv"

_esc() { printf '%s' "${1//\'/\'\'}"; }

_emit_refresh_log() {
    local t_end duration_ms
    t_end=$(date +%s 2>/dev/null || echo 0)
    duration_ms=$(( (t_end - t_start) * 1000 ))
    db_write_tx "$DB_PATH" \
        "INSERT INTO refresh_log (projection,last_refreshed_at,duration_ms,rows_in,rows_out)
         VALUES ('prs_index',strftime('%Y-%m-%d %H:%M:%f','now'),$duration_ms,$rows_in,$rows_out)
         ON CONFLICT(projection) DO UPDATE SET
           last_refreshed_at=strftime('%Y-%m-%d %H:%M:%f','now'),
           duration_ms=excluded.duration_ms,
           rows_in=excluded.rows_in,
           rows_out=excluded.rows_out;" 2>/dev/null || true
}
trap '_emit_refresh_log; rm -f "$TSV_FILE"' EXIT

# ── Fetch JSON ────────────────────────────────────────────────────────────────
if [ -n "${T4A_FIXTURE_PRS:-}" ]; then
    PR_JSON_FILE="$T4A_FIXTURE_PRS"
else
    now=$(date +%s 2>/dev/null || echo 0)
    cache_fresh=0
    if [ -f "$CACHE_FILE" ]; then
        mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
        age=$((now - mtime))
        [ "$age" -lt "$CACHE_TTL" ] && cache_fresh=1
    fi
    if [ "$cache_fresh" -eq 0 ]; then
        gh pr list --state all --limit 200 \
            --json number,title,state,author,baseRefName,headRefName,updatedAt,repository \
            > "$CACHE_FILE" 2>/dev/null || printf '[]' > "$CACHE_FILE"
    fi
    PR_JSON_FILE="$CACHE_FILE"
fi

# ── Parse JSON into TSV via python3 (no SQL escaping — bash-side _esc handles it) ──
python3 - "$PR_JSON_FILE" > "$TSV_FILE" <<'PYEOF'
import sys, json
with open(sys.argv[1]) as f:
    data = json.load(f)
for pr in data:
    number   = pr.get("number", "")
    title    = (pr.get("title") or "")
    state    = (pr.get("state") or "").lower()
    author   = ((pr.get("author") or {}).get("login") or "")
    base_ref = (pr.get("baseRefName") or "")
    head_ref = (pr.get("headRefName") or "")
    updated  = (pr.get("updatedAt") or "")
    repo     = ((pr.get("repository") or {}).get("nameWithOwner") or "")
    print(f"{number}\t{repo}\t{title}\t{state}\t{author}\t{base_ref}\t{head_ref}\t{updated}")
PYEOF

# ── Upsert rows ───────────────────────────────────────────────────────────────
while IFS="	" read -r number repo title state author base_ref head_ref updated; do
    [ -z "$number" ] && continue
    rows_in=$((rows_in + 1))
    db_write_tx "$DB_PATH" \
        "INSERT INTO prs_index (number,repo,title,state,author,base_ref,head_ref,updated_at,refreshed_at)
         VALUES ($number,'$(_esc "$repo")','$(_esc "$title")','$(_esc "$state")',
                 '$(_esc "$author")','$(_esc "$base_ref")','$(_esc "$head_ref")','$(_esc "$updated")',
                 strftime('%Y-%m-%d %H:%M:%f','now'))
         ON CONFLICT(number) DO UPDATE SET
           repo=excluded.repo, title=excluded.title, state=excluded.state,
           author=excluded.author, base_ref=excluded.base_ref, head_ref=excluded.head_ref,
           updated_at=excluded.updated_at, refreshed_at=strftime('%Y-%m-%d %H:%M:%f','now');"
    rows_out=$((rows_out + 1))
done < "$TSV_FILE"
