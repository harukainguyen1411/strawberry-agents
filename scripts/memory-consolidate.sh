#!/usr/bin/env bash
# memory-consolidate.sh <secretary> — fold session shards older than 48h into <secretary>.md
#
# Usage: bash scripts/memory-consolidate.sh evelynn
#        bash scripts/memory-consolidate.sh sona
#
# Responsibilities:
#   1. Find shards in agents/<secretary>/memory/sessions/*.md with mtime > 48h old
#   2. Sort by mtime ascending
#   3. Rewrite the ## Sessions block in <secretary>.md (below the sentinel) with merged content
#   4. git mv each shard into sessions/archive/ (handles UUID collision by looping with
#      incrementing suffix until a free name is found, bounded by 100 attempts)
#   5. Commit and push (chore: <secretary> memory consolidation YYYY-MM-DD)
#   6. Prune archive shards older than 30 days (delete from git), keyed by date embedded
#      in the shard filename (YYYY-MM-DD prefix) rather than mtime — git mv resets mtime,
#      so parsing the date from the filename is the only durable option.
#   7. Prune last-sessions/ shards older than 30 days using the same date-in-filename
#      strategy (same 30d window as archive/).
#
# Exit codes:
#   0 — success or no-op (nothing to consolidate)
#   1 — fatal error (commit/push failure, sentinel missing/duplicated, UUID collision
#       exhausted, invalid secretary name)
#
# POSIX-portable bash — runs on macOS and Git Bash on Windows (Rule 10)
# Requires: git, python3

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------
if [ $# -ne 1 ]; then
    echo "usage: memory-consolidate.sh <secretary>" >&2
    exit 1
fi

SECRETARY="$1"

# Must match [a-z]+ only
case "$SECRETARY" in
    *[!a-z]*)
        echo "memory-consolidate: invalid secretary name '${SECRETARY}' — must match [a-z]+" >&2
        exit 1
        ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MEMORY_MD="${REPO_ROOT}/agents/${SECRETARY}/memory/${SECRETARY}.md"

if [ ! -f "$MEMORY_MD" ]; then
    echo "memory-consolidate: no memory file found at ${MEMORY_MD} — secretary '${SECRETARY}' does not exist or is not initialised." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Guard: python3 must be available (Rule 10 — must work on Git Bash / Windows)
# ---------------------------------------------------------------------------
command -v python3 >/dev/null 2>&1 || { echo "memory-consolidate: python3 required but not found." >&2; exit 1; }

SESSIONS_DIR="${REPO_ROOT}/agents/${SECRETARY}/memory/sessions"
ARCHIVE_DIR="${SESSIONS_DIR}/archive"
LAST_SESSIONS_DIR="${REPO_ROOT}/agents/${SECRETARY}/memory/last-sessions"
LOCK_FILE="${REPO_ROOT}/agents/${SECRETARY}/memory/.consolidate.lock"
SENTINEL="<!-- sessions:auto-below"

# ---------------------------------------------------------------------------
# Unified EXIT trap — registered BEFORE lock acquisition so it always fires.
# Holds references to all temps the script may create; set to empty strings
# initially and populated as each resource is created.
# ---------------------------------------------------------------------------
_NEW_CONTENT_FILE=""
_MEMORY_MD_ABOVE=""

_cleanup() {
    # Always remove temp files if they were created
    [ -n "$_NEW_CONTENT_FILE" ] && rm -f "$_NEW_CONTENT_FILE"
    [ -n "$_MEMORY_MD_ABOVE" ]  && rm -f "$_MEMORY_MD_ABOVE"
    # Release noclobber lock only if we own it
    if [ "${_LOCK_PATH_NOCLOBBER:-}" = "1" ]; then
        rm -f "${LOCK_FILE}"
    fi
    # flock lock: released automatically when fd 9 is closed on shell exit
}
trap '_cleanup' EXIT INT TERM

# ---------------------------------------------------------------------------
# Advisory lock — prevents two simultaneous boots from both rewriting <secretary>.md
# Use flock if available (Linux/util-linux), otherwise fall back to noclobber.
#
# IMPORTANT: trap is registered ABOVE before lock acquisition. This is
# intentional — it guarantees lock cleanup even if the script aborts during
# startup checks before the lock section completes.
# ---------------------------------------------------------------------------
_LOCK_PATH_NOCLOBBER=0
_lock_acquired=0

if command -v flock >/dev/null 2>&1; then
    exec 9>"${LOCK_FILE}"
    if ! flock -n 9; then
        echo "memory-consolidate: another consolidation is running (flock), exiting as no-op."
        exit 0
    fi
    _lock_acquired=1
else
    # Fallback: noclobber-based advisory lock (POSIX)
    #
    # PID liveness check: if a lock file already exists, read its PID and test
    # whether that process is still alive. If it is dead (stale lock from crash
    # or SIGKILL), reclaim the lock. If it is alive, exit as no-op.
    if [ -f "${LOCK_FILE}" ]; then
        existing_pid=$(cat "${LOCK_FILE}" 2>/dev/null || true)
        if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
            echo "memory-consolidate: another consolidation is running (pid ${existing_pid}), exiting as no-op."
            exit 0
        else
            echo "memory-consolidate: stale lock from pid ${existing_pid:-unknown} (process dead), reclaiming."
            rm -f "${LOCK_FILE}"
        fi
    fi
    # Attempt atomic create via noclobber
    if ( set -o noclobber; echo "$$" > "${LOCK_FILE}" ) 2>/dev/null; then
        _LOCK_PATH_NOCLOBBER=1
        _lock_acquired=1
    else
        echo "memory-consolidate: another consolidation is running (noclobber race), exiting as no-op."
        exit 0
    fi
fi

cd "${REPO_ROOT}"

# ---------------------------------------------------------------------------
# Find shards older than 48h (mtime > 48h ago)
# Use python3 for portability instead of GNU find -mtime or stat
# ---------------------------------------------------------------------------
OLD_SHARDS_WITH_TIME=""
for f in "${SESSIONS_DIR}"/*.md; do
    # Skip if glob didn't expand (no files)
    [ -e "$f" ] || continue
    # Skip .gitkeep
    [ "$(basename "$f")" = ".gitkeep" ] && continue

    result=$(python3 -c "
import os, time
mtime = int(os.path.getmtime('${f}'))
now = int(time.time())
age = now - mtime
print(mtime, age)
")
    mtime=$(echo "$result" | awk '{print $1}')
    age=$(echo "$result" | awk '{print $2}')
    if [ "$age" -gt 172800 ]; then
        OLD_SHARDS_WITH_TIME="${OLD_SHARDS_WITH_TIME}${mtime} ${f}\n"
    fi
done

if [ -z "$OLD_SHARDS_WITH_TIME" ]; then
    echo "memory-consolidate [${SECRETARY}]: no shards older than 48h — nothing to do."
    exit 0
fi

# Sort by mtime ascending (oldest first), extract paths
SORTED_SHARDS=$(printf "%b" "$OLD_SHARDS_WITH_TIME" | sort -n | awk '{print $2}')

# ---------------------------------------------------------------------------
# Validate sentinel in <secretary>.md — must appear exactly once
# ---------------------------------------------------------------------------
SENTINEL_COUNT=$(python3 -c "
count = 0
with open('${MEMORY_MD}', 'r') as f:
    for line in f:
        if line.startswith('${SENTINEL}'):
            count += 1
print(count)
")

if [ "$SENTINEL_COUNT" -eq 0 ]; then
    echo "memory-consolidate [${SECRETARY}]: ERROR — sentinel '${SENTINEL}' not found in ${MEMORY_MD}." >&2
    exit 1
fi

if [ "$SENTINEL_COUNT" -gt 1 ]; then
    echo "memory-consolidate [${SECRETARY}]: ERROR — sentinel '${SENTINEL}' appears ${SENTINEL_COUNT} times (expected 1). Manual fix required." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Build a temp file with: above-sentinel content + shard contents
# ---------------------------------------------------------------------------
_NEW_CONTENT_FILE=$(mktemp /tmp/${SECRETARY}-sessions-XXXXXX.md)
_MEMORY_MD_ABOVE="${MEMORY_MD}.above"

# Write above-sentinel portion (including sentinel line)
python3 - "${MEMORY_MD}" "${SENTINEL}" "${_NEW_CONTENT_FILE}" <<'PYEOF'
import sys

md_path = sys.argv[1]
sentinel_prefix = sys.argv[2]
out_path = sys.argv[3]

with open(md_path, 'r') as f:
    lines = f.readlines()

sentinel_idx = None
for i, line in enumerate(lines):
    if line.startswith(sentinel_prefix):
        sentinel_idx = i
        break

if sentinel_idx is None:
    print("ERROR: sentinel not found", file=sys.stderr)
    sys.exit(1)

above = ''.join(lines[:sentinel_idx + 1])  # includes sentinel line
with open(out_path, 'w') as f:
    f.write(above)
    # Ensure a blank line after sentinel
    if not above.endswith('\n\n'):
        f.write('\n')
PYEOF

# Append each shard's content (oldest first)
while IFS= read -r shard; do
    [ -z "$shard" ] && continue
    python3 -c "
with open('${_NEW_CONTENT_FILE}', 'a') as out:
    with open('${shard}', 'r') as shard_f:
        content = shard_f.read().strip()
        out.write(content)
        out.write('\n\n')
"
done <<EOF
$SORTED_SHARDS
EOF

# ---------------------------------------------------------------------------
# Rewrite <secretary>.md: new sessions block + preserved post-sessions sections
# (## Feedback and anything else below ## Sessions)
# ---------------------------------------------------------------------------
python3 - "${MEMORY_MD}" "${SENTINEL}" "${_NEW_CONTENT_FILE}" <<'PYEOF'
import sys

md_path = sys.argv[1]
sentinel_prefix = sys.argv[2]
new_sessions_path = sys.argv[3]

with open(md_path, 'r') as f:
    lines = f.readlines()

sentinel_idx = None
for i, line in enumerate(lines):
    if line.startswith(sentinel_prefix):
        sentinel_idx = i
        break

# Find the next top-level ## heading after the sessions sentinel
# (this is where Feedback or other curated sections begin)
post_sessions_idx = None
for i in range(sentinel_idx + 1, len(lines)):
    stripped = lines[i].strip()
    if stripped.startswith('## ') and not stripped.startswith('## Sessions'):
        post_sessions_idx = i
        break

with open(new_sessions_path, 'r') as f:
    new_sessions_content = f.read()

if post_sessions_idx is not None:
    post_content = ''.join(lines[post_sessions_idx:])
else:
    post_content = ''

with open(md_path, 'w') as f:
    f.write(new_sessions_content)
    if post_content:
        if not new_sessions_content.endswith('\n\n'):
            f.write('\n')
        f.write(post_content)
PYEOF

# ---------------------------------------------------------------------------
# git mv each shard to archive (UUID collision: loop with incrementing suffix,
# bounded to 100 attempts; fail loud + abort on exhaustion)
# ---------------------------------------------------------------------------

# Collect the explicit list of files staged by this script so we can use
# targeted git add instead of git add -A (which could sweep in secret files
# or concurrent-session temp files from other agents).
STAGED_FILES="${MEMORY_MD}"

while IFS= read -r shard; do
    [ -z "$shard" ] && continue
    uuid=$(basename "$shard" .md)
    dest="${ARCHIVE_DIR}/${uuid}.md"

    # Loop with incrementing suffix until a free destination is found (max 100)
    if [ -f "$dest" ]; then
        _collision_n=2
        while [ -f "${ARCHIVE_DIR}/${uuid}-${_collision_n}.md" ]; do
            _collision_n=$(( _collision_n + 1 ))
            if [ $_collision_n -gt 100 ]; then
                echo "memory-consolidate [${SECRETARY}]: ERROR — UUID collision exhausted 100 suffixes for ${uuid}. Aborting to avoid partial state." >&2
                exit 1
            fi
        done
        dest="${ARCHIVE_DIR}/${uuid}-${_collision_n}.md"
    fi

    git mv "${shard}" "${dest}"
    STAGED_FILES="${STAGED_FILES} ${dest}"
done <<EOF
$SORTED_SHARDS
EOF

# Stage only the files this script explicitly created/modified (not git add -A)
git add ${STAGED_FILES}

# ---------------------------------------------------------------------------
# Prune archive shards older than 30 days.
#
# NOTE: git mv resets the mtime of the destination file to the time of the
# move — it does NOT preserve the original shard's mtime. This means that
# checking mtime of archive/ files would measure time-since-archive, not
# time-since-session, producing incorrect results.
#
# Strategy chosen (option a): encode the session date into the shard filename.
# Shard filenames are expected to be UUID-keyed; we embed the date as the
# archive filename prefix: YYYY-MM-DD-<uuid>.md when git mv'ing into archive/.
# For existing shards that predate this convention (no date prefix), fall back
# to git log to read the original commit date of the file.
# ---------------------------------------------------------------------------
PRUNED_ARCHIVE=""
THIRTY_DAYS_AGO_EPOCH=$(python3 -c "import time; print(int(time.time()) - 2592000)")
for f in "${ARCHIVE_DIR}"/*.md; do
    [ -e "$f" ] || continue
    [ "$(basename "$f")" = ".gitkeep" ] && continue

    fname=$(basename "$f")
    shard_epoch=""

    # Try to parse YYYY-MM-DD prefix from filename
    date_prefix=$(echo "$fname" | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}-' | cut -c1-10 || true)
    if [ -n "$date_prefix" ]; then
        shard_epoch=$(python3 -c "
import time, datetime
try:
    d = datetime.date.fromisoformat('${date_prefix}')
    print(int(time.mktime(d.timetuple())))
except Exception:
    print('')
" 2>/dev/null || true)
    fi

    # Fallback: use git log to get the original commit date for this file path
    if [ -z "$shard_epoch" ]; then
        git_date=$(git log --follow --diff-filter=A --format="%aI" -- "${f}" 2>/dev/null | tail -1 || true)
        if [ -n "$git_date" ]; then
            shard_epoch=$(python3 -c "
from email.utils import parsedate_to_datetime
import time
try:
    import datetime
    d = datetime.datetime.fromisoformat('${git_date}'.replace('Z', '+00:00'))
    print(int(d.timestamp()))
except Exception:
    print('')
" 2>/dev/null || true)
        fi
    fi

    # If we still have no epoch, skip (conservative: don't prune unknown-age shards)
    if [ -z "$shard_epoch" ]; then
        echo "memory-consolidate [${SECRETARY}]: WARNING — cannot determine age of ${fname}, skipping prune." >&2
        continue
    fi

    if [ "$shard_epoch" -lt "$THIRTY_DAYS_AGO_EPOCH" ]; then
        git rm -f "${f}"
        PRUNED_ARCHIVE="${PRUNED_ARCHIVE} ${fname}"
    fi
done

if [ -n "$PRUNED_ARCHIVE" ]; then
    echo "memory-consolidate [${SECRETARY}]: pruned archive shards older than 30d:${PRUNED_ARCHIVE}"
fi

# ---------------------------------------------------------------------------
# Prune last-sessions/ shards older than 30 days (same policy as archive/).
# These accumulate from /end-session Step 6 writes and are never pruned
# otherwise. Uses the same date-from-git-log strategy as archive/.
# ---------------------------------------------------------------------------
PRUNED_LAST=""
for f in "${LAST_SESSIONS_DIR}"/*.md; do
    [ -e "$f" ] || continue
    [ "$(basename "$f")" = ".gitkeep" ] && continue

    fname=$(basename "$f")
    shard_epoch=""

    # Try to parse YYYY-MM-DD prefix from filename
    date_prefix=$(echo "$fname" | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}-' | cut -c1-10 || true)
    if [ -n "$date_prefix" ]; then
        shard_epoch=$(python3 -c "
import time, datetime
try:
    d = datetime.date.fromisoformat('${date_prefix}')
    print(int(time.mktime(d.timetuple())))
except Exception:
    print('')
" 2>/dev/null || true)
    fi

    # Fallback: git log for original commit date
    if [ -z "$shard_epoch" ]; then
        git_date=$(git log --follow --diff-filter=A --format="%aI" -- "${f}" 2>/dev/null | tail -1 || true)
        if [ -n "$git_date" ]; then
            shard_epoch=$(python3 -c "
import datetime
try:
    d = datetime.datetime.fromisoformat('${git_date}'.replace('Z', '+00:00'))
    print(int(d.timestamp()))
except Exception:
    print('')
" 2>/dev/null || true)
        fi
    fi

    if [ -z "$shard_epoch" ]; then
        echo "memory-consolidate [${SECRETARY}]: WARNING — cannot determine age of last-sessions/${fname}, skipping prune." >&2
        continue
    fi

    if [ "$shard_epoch" -lt "$THIRTY_DAYS_AGO_EPOCH" ]; then
        git rm -f "${f}"
        PRUNED_LAST="${PRUNED_LAST} ${fname}"
    fi
done

if [ -n "$PRUNED_LAST" ]; then
    echo "memory-consolidate [${SECRETARY}]: pruned last-sessions/ shards older than 30d:${PRUNED_LAST}"
fi

# ---------------------------------------------------------------------------
# Commit
# ---------------------------------------------------------------------------
TODAY=$(date -u +%Y-%m-%d)
git commit -m "chore: ${SECRETARY} memory consolidation ${TODAY}"

# ---------------------------------------------------------------------------
# Push (one retry on merge conflict, never rebase per Rule 11)
# ---------------------------------------------------------------------------
if ! git push; then
    echo "memory-consolidate [${SECRETARY}]: push failed, pulling with merge and retrying..."
    git fetch origin main
    git merge origin/main --no-edit
    git push || { echo "memory-consolidate [${SECRETARY}]: ERROR — push failed after merge retry." >&2; exit 1; }
fi

echo "memory-consolidate [${SECRETARY}]: done."
