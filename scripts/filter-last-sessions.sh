#!/usr/bin/env bash
# filter-last-sessions.sh — list last-sessions/ shards modified within the last 48h,
# newest first (one path per line).
#
# Also runs a pre-boot validator:
#   - verifies the <!-- sessions:auto-below sentinel exists in evelynn.md
#   - counts shards in last-sessions/
#   - reports totals for Evelynn's audit trail
#
# Exit codes:
#   0 — success (even if no shards match)
#   1 — sentinel missing or duplicated in evelynn.md

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAST_SESSIONS_DIR="${REPO_ROOT}/agents/evelynn/memory/last-sessions"
EVELYNN_MD="${REPO_ROOT}/agents/evelynn/memory/evelynn.md"
SENTINEL="<!-- sessions:auto-below"

# ---------------------------------------------------------------------------
# Pre-boot validator
# ---------------------------------------------------------------------------
SENTINEL_COUNT=$(python3 -c "
count = 0
with open('${EVELYNN_MD}', 'r') as f:
    for line in f:
        if line.startswith('${SENTINEL}'):
            count += 1
print(count)
")

TOTAL_SHARDS=0
for f in "${LAST_SESSIONS_DIR}"/*.md; do
    [ -e "$f" ] || break
    [ "$(basename "$f")" = ".gitkeep" ] && continue
    TOTAL_SHARDS=$(( TOTAL_SHARDS + 1 ))
done

echo "# pre-boot-validator" >&2
echo "sentinel_count=${SENTINEL_COUNT} total_last_session_shards=${TOTAL_SHARDS}" >&2

if [ "$SENTINEL_COUNT" -eq 0 ]; then
    echo "ERROR: sentinel '${SENTINEL}' not found in evelynn.md — memory file may be corrupted." >&2
    exit 1
fi

if [ "$SENTINEL_COUNT" -gt 1 ]; then
    echo "ERROR: sentinel '${SENTINEL}' appears ${SENTINEL_COUNT} times (expected 1) — manual fix required." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Filter shards modified within the last 48h, collect with mtime for sorting
# ---------------------------------------------------------------------------
SHARDS_WITH_TIME=""
NOW=$(python3 -c "import time; print(int(time.time()))")
CUTOFF=$(( NOW - 172800 ))

for f in "${LAST_SESSIONS_DIR}"/*.md; do
    [ -e "$f" ] || break
    [ "$(basename "$f")" = ".gitkeep" ] && continue

    mtime=$(python3 -c "import os; print(int(os.path.getmtime('${f}')))")
    if [ "$mtime" -ge "$CUTOFF" ]; then
        SHARDS_WITH_TIME="${SHARDS_WITH_TIME}${mtime} ${f}\n"
    fi
done

if [ -z "$SHARDS_WITH_TIME" ]; then
    echo "# filter-last-sessions: no shards modified within the last 48h" >&2
    exit 0
fi

# Sort by mtime descending (newest first) and print paths
printf "%b" "$SHARDS_WITH_TIME" | sort -rn | awk '{print $2}'
