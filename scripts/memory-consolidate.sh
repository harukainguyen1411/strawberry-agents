#!/usr/bin/env bash
# memory-consolidate.sh <secretary> [--index-only]
#
# Usage:
#   bash scripts/memory-consolidate.sh evelynn
#   bash scripts/memory-consolidate.sh sona
#   bash scripts/memory-consolidate.sh evelynn --index-only
#
# Responsibilities:
#   --index-only flag (new):
#     Runs only the INDEX regeneration pass (see §4.2 of ADR). No archive move,
#     no sessions-block fold, no commit/push. Lightweight — target sub-second.
#     Returns non-zero if last-sessions/ directory is missing.
#
#   Full run:
#   1. Pre-boot validator — verify sentinel + last-sessions/ exist; log shard counts
#   2. Find shards in agents/<secretary>/memory/sessions/*.md with mtime > 48h old
#   3. Sort by mtime ascending
#   4. Rewrite the ## Sessions block in <secretary>.md (below the sentinel) with merged content
#   5. git mv each shard into sessions/archive/ (handles UUID collision by looping with
#      incrementing suffix until a free name is found, bounded by 100 attempts)
#   6. INDEX regeneration — walk last-sessions/*.md sorted newest-first by mtime; for each
#      shard parse TL;DR; emit rows into last-sessions/INDEX.md (idempotent overwrite).
#      archive-policy-v2: ARCHIVE_CUTOFF_DAYS=14 OR position > 20.
#   7. Archive policy (new) — archive last-sessions shards per: mtime > 14d OR position > 20.
#      Pre-archive guard: skip any shard whose UUID appears in open-threads.md (warn to stderr).
#      Uses git mv; UUID collision loop.
#   8. Commit and push (chore: <secretary> memory consolidation YYYY-MM-DD)
#   9. Prune archive shards older than 30 days (delete from git), keyed by date embedded
#      in the shard filename (YYYY-MM-DD prefix) rather than mtime — git mv resets mtime,
#      so parsing the date from the filename is the only durable option.
#
# STRAWBERRY_MEMORY_ROOT env override (integration-test shim):
#   When set, redirects all file ops to that directory as if it were the git repo root.
#   Under the shim, last-sessions/ and archive/ are at the repo root level.
#   Also relaxes the secretary-name regex to allow hyphens (e.g. test-coordinator).
#   In shim mode, if <secretary>.md does not exist, a minimal stub is auto-created.
#
# Exit codes:
#   0 — success or no-op (nothing to consolidate)
#   1 — fatal error (commit/push failure, sentinel missing/duplicated, UUID collision
#       exhausted, invalid secretary name, last-sessions/ missing in --index-only)
#
# POSIX-portable bash — runs on macOS and Git Bash on Windows (Rule 10)
# Requires: git, python3
#
# sentinel: archive-policy-v2

set -euo pipefail

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
INDEX_ONLY=0
SECRETARY=""

for arg in "$@"; do
    case "$arg" in
        --index-only)
            INDEX_ONLY=1
            ;;
        -*)
            echo "memory-consolidate: unknown flag '${arg}'" >&2
            exit 1
            ;;
        *)
            if [ -z "$SECRETARY" ]; then
                SECRETARY="$arg"
            else
                echo "usage: memory-consolidate.sh <secretary> [--index-only]" >&2
                exit 1
            fi
            ;;
    esac
done

if [ -z "$SECRETARY" ]; then
    echo "usage: memory-consolidate.sh <secretary> [--index-only]" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Secretary name validation
# Under STRAWBERRY_MEMORY_ROOT shim: allow hyphens (test-coordinator etc.)
# Normal mode: must match [a-z]+ only
# ---------------------------------------------------------------------------
if [ -n "${STRAWBERRY_MEMORY_ROOT:-}" ]; then
    # Relaxed: allow a-z and hyphens
    case "$SECRETARY" in
        *[!a-z-]*)
            echo "memory-consolidate: invalid secretary name '${SECRETARY}' — must match [a-z-]+" >&2
            exit 1
            ;;
    esac
else
    case "$SECRETARY" in
        *[!a-z]*)
            echo "memory-consolidate: invalid secretary name '${SECRETARY}' — must match [a-z]+" >&2
            exit 1
            ;;
    esac
fi

# ---------------------------------------------------------------------------
# Path setup — STRAWBERRY_MEMORY_ROOT shim vs. real tree
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -n "${STRAWBERRY_MEMORY_ROOT:-}" ]; then
    # Integration-test shim: treat STRAWBERRY_MEMORY_ROOT as the repo/memory root.
    # The test harness sets up a minimal git repo at that root with:
    #   last-sessions/           (the shard dir)
    #   last-sessions/archive/   (the archive subdir)
    # So we work directly at that root level.
    MEMORY_BASE="${STRAWBERRY_MEMORY_ROOT}"
    REPO_ROOT="${STRAWBERRY_MEMORY_ROOT}"
    MEMORY_MD="${MEMORY_BASE}/${SECRETARY}.md"
    SESSIONS_DIR="${MEMORY_BASE}/sessions"
    ARCHIVE_DIR="${SESSIONS_DIR}/archive"
    LAST_SESSIONS_DIR="${MEMORY_BASE}/last-sessions"
    LOCK_FILE="${MEMORY_BASE}/.consolidate.lock"
    # open-threads.md may be in memory/ subdir (test B4/B5 pattern) or at root
    if [ -f "${MEMORY_BASE}/memory/open-threads.md" ]; then
        OPEN_THREADS_FILE="${MEMORY_BASE}/memory/open-threads.md"
    else
        OPEN_THREADS_FILE="${MEMORY_BASE}/open-threads.md"
    fi
    # Determine git root for git operations inside the shim's tmp repo
    GIT_ROOT="$(cd "${MEMORY_BASE}" && git rev-parse --show-toplevel 2>/dev/null || echo "${MEMORY_BASE}")"
else
    REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
    MEMORY_BASE="${REPO_ROOT}/agents/${SECRETARY}/memory"
    MEMORY_MD="${MEMORY_BASE}/${SECRETARY}.md"
    SESSIONS_DIR="${MEMORY_BASE}/sessions"
    ARCHIVE_DIR="${SESSIONS_DIR}/archive"
    LAST_SESSIONS_DIR="${MEMORY_BASE}/last-sessions"
    LOCK_FILE="${MEMORY_BASE}/.consolidate.lock"
    OPEN_THREADS_FILE="${MEMORY_BASE}/open-threads.md"
    GIT_ROOT="${REPO_ROOT}"
fi

# ---------------------------------------------------------------------------
# Source the index helper library
# ---------------------------------------------------------------------------
LIB_INDEX="${SCRIPT_DIR}/_lib_last_sessions_index.sh"
if [ -f "$LIB_INDEX" ]; then
    # shellcheck source=scripts/_lib_last_sessions_index.sh
    . "$LIB_INDEX"
else
    echo "memory-consolidate: ERROR — helper library not found: ${LIB_INDEX}" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# --index-only mode: fast path
# ---------------------------------------------------------------------------
if [ "$INDEX_ONLY" -eq 1 ]; then
    if [ ! -d "$LAST_SESSIONS_DIR" ]; then
        echo "memory-consolidate [${SECRETARY}]: ERROR — last-sessions/ directory not found at ${LAST_SESSIONS_DIR}" >&2
        exit 1
    fi
    INDEX_FILE="${LAST_SESSIONS_DIR}/INDEX.md"
    regenerate_index "$LAST_SESSIONS_DIR" "$INDEX_FILE"
    echo "memory-consolidate [${SECRETARY}]: --index-only complete, wrote ${INDEX_FILE}" >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# Guard: python3 must be available (Rule 10 — must work on Git Bash / Windows)
# ---------------------------------------------------------------------------
command -v python3 >/dev/null 2>&1 || { echo "memory-consolidate: python3 required but not found." >&2; exit 1; }

# ---------------------------------------------------------------------------
# Shim mode: auto-create minimal MEMORY_MD stub if it doesn't exist.
# This allows archive-policy and INDEX regen tests to run without needing
# a full coordinator memory file (the sessions-fold step is skipped when
# the sessions/ dir is absent or empty).
# ---------------------------------------------------------------------------
SENTINEL="<!-- sessions:auto-below"
if [ -n "${STRAWBERRY_MEMORY_ROOT:-}" ] && [ ! -f "$MEMORY_MD" ]; then
    printf '# %s memory\n\n## Sessions\n%s\n\n' "${SECRETARY}" "${SENTINEL}" > "$MEMORY_MD"
fi

# ---------------------------------------------------------------------------
# Pre-boot validator
# Verify sentinel + last-sessions/ exists; log shard counts.
# ---------------------------------------------------------------------------

# Validate MEMORY_MD exists
if [ ! -f "$MEMORY_MD" ]; then
    echo "memory-consolidate: no memory file found at ${MEMORY_MD} — secretary '${SECRETARY}' does not exist or is not initialised." >&2
    exit 1
fi

# Validate last-sessions/ exists
if [ ! -d "$LAST_SESSIONS_DIR" ]; then
    echo "memory-consolidate [${SECRETARY}]: WARNING — last-sessions/ directory not found at ${LAST_SESSIONS_DIR}. Creating it." >&2
    mkdir -p "${LAST_SESSIONS_DIR}/archive"
fi

# Sentinel check
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

# Log shard counts for audit trail
TOTAL_LAST_SHARDS=0
for f in "${LAST_SESSIONS_DIR}"/*.md; do
    [ -e "$f" ] || continue
    [ "$(basename "$f")" = ".gitkeep" ] && continue
    [ "$(basename "$f")" = "INDEX.md" ] && continue
    TOTAL_LAST_SHARDS=$(( TOTAL_LAST_SHARDS + 1 ))
done
echo "memory-consolidate [${SECRETARY}]: pre-boot-validator: sentinel_count=${SENTINEL_COUNT} total_last_session_shards=${TOTAL_LAST_SHARDS}" >&2

# ---------------------------------------------------------------------------
# Unified EXIT trap — registered BEFORE lock acquisition so it always fires.
# ---------------------------------------------------------------------------
_NEW_CONTENT_FILE=""
_MEMORY_MD_ABOVE=""

_cleanup() {
    [ -n "$_NEW_CONTENT_FILE" ] && rm -f "$_NEW_CONTENT_FILE"
    [ -n "$_MEMORY_MD_ABOVE" ]  && rm -f "$_MEMORY_MD_ABOVE"
    if [ "${_LOCK_PATH_NOCLOBBER:-}" = "1" ]; then
        rm -f "${LOCK_FILE}"
    fi
}
trap '_cleanup' EXIT INT TERM

# ---------------------------------------------------------------------------
# Advisory lock
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
    if ( set -o noclobber; echo "$$" > "${LOCK_FILE}" ) 2>/dev/null; then
        _LOCK_PATH_NOCLOBBER=1
        _lock_acquired=1
    else
        echo "memory-consolidate: another consolidation is running (noclobber race), exiting as no-op."
        exit 0
    fi
fi

cd "${GIT_ROOT}"

# ---------------------------------------------------------------------------
# Find sessions/*.md shards older than 48h (mtime > 48h ago)
# ---------------------------------------------------------------------------
OLD_SHARDS_WITH_TIME=""
if [ -d "$SESSIONS_DIR" ]; then
    for f in "${SESSIONS_DIR}"/*.md; do
        [ -e "$f" ] || continue
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
fi

# ---------------------------------------------------------------------------
# Sessions fold — only if there are old shards to consolidate
# ---------------------------------------------------------------------------
if [ -n "$OLD_SHARDS_WITH_TIME" ]; then
    # Sort by mtime ascending (oldest first), extract paths
    SORTED_SHARDS=$(printf "%b" "$OLD_SHARDS_WITH_TIME" | sort -n | awk '{print $2}')

    # Build a temp file with: above-sentinel content + shard contents
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

    # Rewrite <secretary>.md: new sessions block + preserved post-sessions sections
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

    # Ensure sessions/archive/ exists
    mkdir -p "$ARCHIVE_DIR"

    # git mv each shard to sessions/archive/
    STAGED_FILES="${MEMORY_MD}"

    while IFS= read -r shard; do
        [ -z "$shard" ] && continue
        uuid=$(basename "$shard" .md)
        dest="${ARCHIVE_DIR}/${uuid}.md"

        if [ -f "$dest" ]; then
            _collision_n=2
            while [ -f "${ARCHIVE_DIR}/${uuid}-${_collision_n}.md" ]; do
                _collision_n=$(( _collision_n + 1 ))
                if [ $_collision_n -gt 100 ]; then
                    echo "memory-consolidate [${SECRETARY}]: ERROR — UUID collision exhausted 100 suffixes for ${uuid}. Aborting." >&2
                    exit 1
                fi
            done
            dest="${ARCHIVE_DIR}/${uuid}-${_collision_n}.md"
        fi

        src_rel="${shard#${GIT_ROOT}/}"
        dst_rel="${dest#${GIT_ROOT}/}"
        git -C "${GIT_ROOT}" mv "$src_rel" "$dst_rel"
        STAGED_FILES="${STAGED_FILES} ${dest}"
    done <<EOF
$SORTED_SHARDS
EOF

    git -C "${GIT_ROOT}" add ${STAGED_FILES}
else
    echo "memory-consolidate [${SECRETARY}]: no sessions shards older than 48h — skipping sessions fold." >&2
fi

# ---------------------------------------------------------------------------
# INDEX regeneration pass (new — §4.2 step 1)
# Always regenerate INDEX.md, even if no sessions were folded.
# archive-policy-v2: ARCHIVE_CUTOFF_DAYS=14
# ---------------------------------------------------------------------------
INDEX_FILE="${LAST_SESSIONS_DIR}/INDEX.md"
regenerate_index "$LAST_SESSIONS_DIR" "$INDEX_FILE"
echo "memory-consolidate [${SECRETARY}]: INDEX.md regenerated (${INDEX_FILE})" >&2

# Stage INDEX.md
git -C "${GIT_ROOT}" add "${INDEX_FILE}"

# ---------------------------------------------------------------------------
# Archive policy (new, replaces old last-sessions/ 30d prune — §4.2 step 2)
# archive-policy-v2: ARCHIVE_CUTOFF_DAYS=14, max 20 shards in last-sessions/
#
# Input set: last-sessions/*.md (exclude .gitkeep, INDEX.md, archive/ itself)
# Order: newest-first by mtime; ties broken by filename ascending.
# Archive if: (mtime-age > 14 * 86400) OR (position > 20).
# Pre-archive guard: skip if UUID appears in open-threads.md (warn to stderr).
# Move via git mv; UUID collision suffix loop.
# ---------------------------------------------------------------------------
ARCHIVE_CUTOFF_DAYS=14
ARCHIVE_CUTOFF_SECS=$(( ARCHIVE_CUTOFF_DAYS * 86400 ))
ARCHIVE_MAX_POSITION=20
LAST_ARCHIVE_DIR="${LAST_SESSIONS_DIR}/archive"

mkdir -p "${LAST_ARCHIVE_DIR}"

# Collect last-sessions shards with mtime for sorting
LAST_SHARDS_WITH_TIME=""
for f in "${LAST_SESSIONS_DIR}"/*.md; do
    [ -e "$f" ] || continue
    bname="$(basename "$f")"
    [ "$bname" = ".gitkeep" ] && continue
    [ "$bname" = "INDEX.md" ]  && continue

    epoch="$(python3 -c "
import os
try:
    print(int(os.path.getmtime('$f')))
except Exception:
    print(0)
" 2>/dev/null || echo 0)"
    LAST_SHARDS_WITH_TIME="${LAST_SHARDS_WITH_TIME}${epoch} ${f}
"
done

# Sort newest-first, tie-break filename ascending (python3 for portability)
SORTED_LAST_SHARDS=""
if [ -n "$LAST_SHARDS_WITH_TIME" ]; then
    SORTED_LAST_SHARDS="$(printf '%s' "$LAST_SHARDS_WITH_TIME" | python3 -c "
import sys
entries = []
for line in sys.stdin:
    line = line.rstrip('\n')
    if not line:
        continue
    parts = line.split(' ', 1)
    if len(parts) == 2:
        entries.append((int(parts[0]), parts[1]))
entries.sort(key=lambda x: (-x[0], x[1]))
for epoch, path in entries:
    print(path)
")"
fi

# Process each shard against archive policy
NOW_EPOCH="$(python3 -c 'import time; print(int(time.time()))')"
POSITION=0
MOVED_COUNT=0
MOVED_SHARDS=""

while IFS= read -r shard; do
    [ -z "$shard" ] && continue
    POSITION=$(( POSITION + 1 ))

    shard_uuid="$(basename "$shard" .md)"
    shard_epoch="$(python3 -c "
import os
try:
    print(int(os.path.getmtime('$shard')))
except Exception:
    print(0)
" 2>/dev/null || echo 0)"
    shard_age=$(( NOW_EPOCH - shard_epoch ))

    # Determine if archive policy triggers
    should_archive=0
    if [ "$shard_age" -gt "$ARCHIVE_CUTOFF_SECS" ]; then
        should_archive=1
    fi
    if [ "$POSITION" -gt "$ARCHIVE_MAX_POSITION" ]; then
        should_archive=1
    fi

    if [ "$should_archive" -eq 1 ]; then
        # Pre-archive guard: check open-threads.md for UUID reference
        if [ -f "$OPEN_THREADS_FILE" ] && grep -q "$shard_uuid" "$OPEN_THREADS_FILE" 2>/dev/null; then
            printf 'memory-consolidate [%s]: WARN — shard %s is referenced in open-threads.md; skipping archive move to retain context.\n' \
                "${SECRETARY}" "$shard_uuid" >&2
            continue
        fi

        # Compute destination with collision loop
        dest="${LAST_ARCHIVE_DIR}/${shard_uuid}.md"
        if [ -f "$dest" ]; then
            _collision_n=2
            while [ -f "${LAST_ARCHIVE_DIR}/${shard_uuid}-${_collision_n}.md" ]; do
                _collision_n=$(( _collision_n + 1 ))
                if [ $_collision_n -gt 100 ]; then
                    echo "memory-consolidate [${SECRETARY}]: ERROR — UUID collision exhausted 100 suffixes for ${shard_uuid} in last-sessions/archive/. Aborting." >&2
                    exit 1
                fi
            done
            dest="${LAST_ARCHIVE_DIR}/${shard_uuid}-${_collision_n}.md"
        fi

        # Use git mv with paths relative to GIT_ROOT for history preservation
        src_rel="${shard#${GIT_ROOT}/}"
        dst_rel="${dest#${GIT_ROOT}/}"
        git -C "${GIT_ROOT}" mv "$src_rel" "$dst_rel"

        MOVED_COUNT=$(( MOVED_COUNT + 1 ))
        MOVED_SHARDS="${MOVED_SHARDS} ${shard_uuid}"
    fi
done <<EOF
$SORTED_LAST_SHARDS
EOF

if [ "$MOVED_COUNT" -gt 0 ]; then
    echo "memory-consolidate [${SECRETARY}]: archived ${MOVED_COUNT} last-sessions shards (14d/20-position policy):${MOVED_SHARDS}" >&2
    # Regenerate INDEX after archive moves so it reflects current state
    regenerate_index "$LAST_SESSIONS_DIR" "$INDEX_FILE"
    git -C "${GIT_ROOT}" add "${INDEX_FILE}"
fi

# ---------------------------------------------------------------------------
# Prune sessions/archive/ shards older than 30 days (kept as-is).
# ---------------------------------------------------------------------------
PRUNED_ARCHIVE=""
THIRTY_DAYS_AGO_EPOCH=$(python3 -c "import time; print(int(time.time()) - 2592000)")
if [ -d "$ARCHIVE_DIR" ]; then
    for f in "${ARCHIVE_DIR}"/*.md; do
        [ -e "$f" ] || continue
        [ "$(basename "$f")" = ".gitkeep" ] && continue

        fname=$(basename "$f")
        shard_epoch=""

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

        if [ -z "$shard_epoch" ]; then
            git_date=$(git -C "${GIT_ROOT}" log --follow --diff-filter=A --format="%aI" -- "${f}" 2>/dev/null | tail -1 || true)
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
            echo "memory-consolidate [${SECRETARY}]: WARNING — cannot determine age of ${fname}, skipping prune." >&2
            continue
        fi

        if [ "$shard_epoch" -lt "$THIRTY_DAYS_AGO_EPOCH" ]; then
            git -C "${GIT_ROOT}" rm -f "${f}"
            PRUNED_ARCHIVE="${PRUNED_ARCHIVE} ${fname}"
        fi
    done
fi

if [ -n "$PRUNED_ARCHIVE" ]; then
    echo "memory-consolidate [${SECRETARY}]: pruned sessions/archive shards older than 30d:${PRUNED_ARCHIVE}"
fi

# ---------------------------------------------------------------------------
# Prune last-sessions/archive/ shards older than 30 days (backstop).
# ---------------------------------------------------------------------------
PRUNED_LAST_ARCHIVE=""
for f in "${LAST_ARCHIVE_DIR}"/*.md; do
    [ -e "$f" ] || continue
    [ "$(basename "$f")" = ".gitkeep" ] && continue

    fname=$(basename "$f")
    shard_epoch=""

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

    if [ -z "$shard_epoch" ]; then
        git_date=$(git -C "${GIT_ROOT}" log --follow --diff-filter=A --format="%aI" -- "${f}" 2>/dev/null | tail -1 || true)
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
        echo "memory-consolidate [${SECRETARY}]: WARNING — cannot determine age of last-sessions/archive/${fname}, skipping prune." >&2
        continue
    fi

    if [ "$shard_epoch" -lt "$THIRTY_DAYS_AGO_EPOCH" ]; then
        git -C "${GIT_ROOT}" rm -f "${f}"
        PRUNED_LAST_ARCHIVE="${PRUNED_LAST_ARCHIVE} ${fname}"
    fi
done

if [ -n "$PRUNED_LAST_ARCHIVE" ]; then
    echo "memory-consolidate [${SECRETARY}]: pruned last-sessions/archive/ shards older than 30d:${PRUNED_LAST_ARCHIVE}"
fi

# ---------------------------------------------------------------------------
# Commit
# ---------------------------------------------------------------------------
TODAY=$(date -u +%Y-%m-%d)
git -C "${GIT_ROOT}" commit -m "chore: ${SECRETARY} memory consolidation ${TODAY}"

# ---------------------------------------------------------------------------
# Push (one retry on merge conflict, never rebase per Rule 11)
# ---------------------------------------------------------------------------
if ! git -C "${GIT_ROOT}" push 2>/dev/null; then
    echo "memory-consolidate [${SECRETARY}]: push failed, pulling with merge and retrying..."
    git -C "${GIT_ROOT}" fetch origin main
    git -C "${GIT_ROOT}" merge origin/main --no-edit
    git -C "${GIT_ROOT}" push || { echo "memory-consolidate [${SECRETARY}]: ERROR — push failed after merge retry." >&2; exit 1; }
fi

echo "memory-consolidate [${SECRETARY}]: done."
