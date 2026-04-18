#!/usr/bin/env bash
# evelynn-memory-consolidate.sh — fold session shards older than 24h into evelynn.md
#
# Responsibilities:
#   1. Find shards in agents/evelynn/memory/sessions/*.md with mtime > 24h old
#   2. Sort by mtime ascending
#   3. Rewrite the ## Sessions block in evelynn.md (below the sentinel) with merged content
#   4. git mv each shard into sessions/archive/ (handles UUID collision with -2 suffix)
#   5. Commit and push (chore: evelynn memory consolidation YYYY-MM-DD)
#   6. Prune archive shards older than 30 days (delete from git)
#
# Exit codes:
#   0 — success or no-op (nothing to consolidate)
#   1 — fatal error (commit/push failure, sentinel missing/duplicated)
#
# POSIX-portable bash — runs on macOS and Git Bash on Windows (Rule 10)
# Requires: git, python3

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SESSIONS_DIR="${REPO_ROOT}/agents/evelynn/memory/sessions"
ARCHIVE_DIR="${SESSIONS_DIR}/archive"
EVELYNN_MD="${REPO_ROOT}/agents/evelynn/memory/evelynn.md"
LOCK_FILE="${REPO_ROOT}/agents/evelynn/memory/.consolidate.lock"
SENTINEL="<!-- sessions:auto-below"

# ---------------------------------------------------------------------------
# Advisory lock — prevents two simultaneous boots from both rewriting evelynn.md
# Use flock if available (Linux/util-linux), otherwise fall back to noclobber.
# ---------------------------------------------------------------------------
_lock_acquired=0

if command -v flock >/dev/null 2>&1; then
    exec 9>"${LOCK_FILE}"
    if ! flock -n 9; then
        echo "evelynn-memory-consolidate: another consolidation is running (flock), exiting as no-op."
        exit 0
    fi
    _lock_acquired=1
else
    # Fallback: noclobber-based advisory lock (POSIX)
    # Create lock file atomically; if it already exists, exit as no-op.
    set +o noclobber 2>/dev/null || true
    if ( set -o noclobber; echo "$$" > "${LOCK_FILE}" ) 2>/dev/null; then
        _lock_acquired=1
        # Ensure lock is released on exit
        trap 'rm -f "${LOCK_FILE}"' EXIT
    else
        echo "evelynn-memory-consolidate: another consolidation is running (noclobber), exiting as no-op."
        exit 0
    fi
fi

cd "${REPO_ROOT}"

# ---------------------------------------------------------------------------
# Find shards older than 24h (mtime > 24h ago)
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
    if [ "$age" -gt 86400 ]; then
        OLD_SHARDS_WITH_TIME="${OLD_SHARDS_WITH_TIME}${mtime} ${f}\n"
    fi
done

if [ -z "$OLD_SHARDS_WITH_TIME" ]; then
    echo "evelynn-memory-consolidate: no shards older than 24h — nothing to do."
    exit 0
fi

# Sort by mtime ascending (oldest first), extract paths
SORTED_SHARDS=$(printf "%b" "$OLD_SHARDS_WITH_TIME" | sort -n | awk '{print $2}')

# ---------------------------------------------------------------------------
# Validate sentinel in evelynn.md — must appear exactly once
# ---------------------------------------------------------------------------
SENTINEL_COUNT=$(python3 -c "
count = 0
with open('${EVELYNN_MD}', 'r') as f:
    for line in f:
        if line.startswith('${SENTINEL}'):
            count += 1
print(count)
")

if [ "$SENTINEL_COUNT" -eq 0 ]; then
    echo "evelynn-memory-consolidate: ERROR — sentinel '${SENTINEL}' not found in ${EVELYNN_MD}." >&2
    exit 1
fi

if [ "$SENTINEL_COUNT" -gt 1 ]; then
    echo "evelynn-memory-consolidate: ERROR — sentinel '${SENTINEL}' appears ${SENTINEL_COUNT} times (expected 1). Manual fix required." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Build a temp file with: above-sentinel content + shard contents
# ---------------------------------------------------------------------------
NEW_CONTENT_FILE=$(mktemp /tmp/evelynn-sessions-XXXXXX.md)
trap 'rm -f "${NEW_CONTENT_FILE}" "${EVELYNN_MD}.above"' EXIT

# Write above-sentinel portion (including sentinel line)
python3 - "${EVELYNN_MD}" "${SENTINEL}" "${NEW_CONTENT_FILE}" <<'PYEOF'
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
with open('${NEW_CONTENT_FILE}', 'a') as out:
    with open('${shard}', 'r') as shard_f:
        content = shard_f.read().strip()
        out.write(content)
        out.write('\n\n')
"
done <<EOF
$SORTED_SHARDS
EOF

# ---------------------------------------------------------------------------
# Rewrite evelynn.md: new sessions block + preserved post-sessions sections
# (## Feedback and anything else below ## Sessions)
# ---------------------------------------------------------------------------
python3 - "${EVELYNN_MD}" "${SENTINEL}" "${NEW_CONTENT_FILE}" <<'PYEOF'
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
# git mv each shard to archive (handle UUID collision with -2 suffix)
# ---------------------------------------------------------------------------
while IFS= read -r shard; do
    [ -z "$shard" ] && continue
    uuid=$(basename "$shard" .md)
    dest="${ARCHIVE_DIR}/${uuid}.md"
    if [ -f "$dest" ]; then
        dest="${ARCHIVE_DIR}/${uuid}-2.md"
    fi
    git mv "${shard}" "${dest}"
done <<EOF
$SORTED_SHARDS
EOF

# Stage the updated evelynn.md and all memory changes
git add -A "${REPO_ROOT}/agents/evelynn/memory/"

# ---------------------------------------------------------------------------
# Prune archive shards older than 30 days
# ---------------------------------------------------------------------------
PRUNED=""
for f in "${ARCHIVE_DIR}"/*.md; do
    [ -e "$f" ] || continue
    [ "$(basename "$f")" = ".gitkeep" ] && continue
    result=$(python3 -c "
import os, time
mtime = int(os.path.getmtime('${f}'))
now = int(time.time())
print(now - mtime)
")
    # 30 days = 2592000 seconds
    if [ "$result" -gt 2592000 ]; then
        git rm -f "${f}"
        PRUNED="${PRUNED} $(basename "$f")"
    fi
done

if [ -n "$PRUNED" ]; then
    echo "evelynn-memory-consolidate: pruned archive shards older than 30d:${PRUNED}"
fi

# ---------------------------------------------------------------------------
# Commit
# ---------------------------------------------------------------------------
TODAY=$(date -u +%Y-%m-%d)
git commit -m "chore: evelynn memory consolidation ${TODAY}"

# ---------------------------------------------------------------------------
# Push (one retry on merge conflict, never rebase per Rule 11)
# ---------------------------------------------------------------------------
if ! git push; then
    echo "evelynn-memory-consolidate: push failed, pulling with merge and retrying..."
    git fetch origin main
    git merge origin/main --no-edit
    git push || { echo "evelynn-memory-consolidate: ERROR — push failed after merge retry." >&2; exit 1; }
fi

echo "evelynn-memory-consolidate: done."
