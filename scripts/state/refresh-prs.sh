#!/usr/bin/env bash
# scripts/state/refresh-prs.sh — upsert prs_index from gh pr list or fixture
# Plan: plans/approved/personal/2026-04-27-coordinator-memory-v1-adr.md §T4b
#
# Usage: refresh-prs.sh <db_path>
#   env T4A_FIXTURE_PRS — path to JSON fixture (overrides live gh pr list)
#
# gh pr list output cached for 60s at /tmp/strawberry-prs-cache.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./_lib_db.sh
. "$SCRIPT_DIR/_lib_db.sh"

DB_PATH="${1:?refresh-prs.sh: db_path required as \$1}"
CACHE_FILE="/tmp/strawberry-prs-cache.json"
CACHE_TTL=60

t_start=$(date +%s 2>/dev/null || echo 0)

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

# ── Parse JSON into TSV via python3 ──────────────────────────────────────────
TSV_FILE="/tmp/strawberry-prs-$$.tsv"
python3 - "$PR_JSON_FILE" > "$TSV_FILE" <<'PYEOF'
import sys, json
with open(sys.argv[1]) as f:
    data = json.load(f)
for pr in data:
    number   = pr.get("number", "")
    title    = (pr.get("title") or "").replace("'", "''")
    state    = (pr.get("state") or "").lower()
    author   = ((pr.get("author") or {}).get("login") or "")
    base_ref = (pr.get("baseRefName") or "")
    head_ref = (pr.get("headRefName") or "")
    updated  = (pr.get("updatedAt") or "")
    repo     = ((pr.get("repository") or {}).get("nameWithOwner") or "")
    print(f"{number}\t{repo}\t{title}\t{state}\t{author}\t{base_ref}\t{head_ref}\t{updated}")
PYEOF

refreshed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
rows_in=0
rows_out=0

while IFS="	" read -r number repo title state author base_ref head_ref updated; do
    [ -z "$number" ] && continue
    rows_in=$((rows_in + 1))
    db_write_tx "$DB_PATH" \
        "INSERT INTO prs_index (number,repo,title,state,author,base_ref,head_ref,updated_at,refreshed_at)
         VALUES ($number,'$repo','$title','$state','$author','$base_ref','$head_ref','$updated','$refreshed_at')
         ON CONFLICT(number) DO UPDATE SET
           repo=excluded.repo, title=excluded.title, state=excluded.state,
           author=excluded.author, base_ref=excluded.base_ref, head_ref=excluded.head_ref,
           updated_at=excluded.updated_at, refreshed_at=excluded.refreshed_at;"
    rows_out=$((rows_out + 1))
done < "$TSV_FILE"
rm -f "$TSV_FILE"

t_end=$(date +%s 2>/dev/null || echo 0)
duration_ms=$(( (t_end - t_start) * 1000 ))

db_write_tx "$DB_PATH" \
    "INSERT INTO refresh_log (projection,last_refreshed_at,duration_ms,rows_in,rows_out)
     VALUES ('prs_index','$refreshed_at',$duration_ms,$rows_in,$rows_out)
     ON CONFLICT(projection) DO UPDATE SET
       last_refreshed_at=excluded.last_refreshed_at,
       duration_ms=excluded.duration_ms,
       rows_in=excluded.rows_in,
       rows_out=excluded.rows_out;"
