# _lib_last_sessions_index.sh — sourced-only helper for INDEX.md generation
#
# Public functions:
#   extract_shard_tldr <shard_path>   — prints 3 lines of TL;DR to stdout
#   render_index_row <shard_path>     — prints one markdown row to stdout
#   regenerate_index <last_sessions_dir> <output_file>
#                                     — writes INDEX.md from scratch
#
# Parse rules for extract_shard_tldr (applied in order):
#   a) If shard has a line matching ^TL;DR: (case-sensitive), use the first 3
#      non-blank lines beginning at that anchor.
#   b) Else use the first 3 non-blank prose lines under the first # heading
#      (skip frontmatter fences, skip subsequent ## headings).
#   c) Else produce "(no summary extractable)".
#
# POSIX bash — no shebang, sourced by memory-consolidate.sh (Rule 10).
# Requires: python3

# ---------------------------------------------------------------------------
# extract_shard_tldr <shard_path>
#   Print up to 3 non-blank TL;DR lines to stdout.
# ---------------------------------------------------------------------------
extract_shard_tldr() {
    local shard_path="$1"
    python3 - "$shard_path" <<'PYEOF'
import sys, re

path = sys.argv[1]
try:
    with open(path, 'r', encoding='utf-8', errors='replace') as fh:
        lines = fh.readlines()
except Exception:
    print("(no summary extractable)")
    sys.exit(0)

# Rule (a): TL;DR: anchor
tldr_idx = None
for i, line in enumerate(lines):
    if line.startswith('TL;DR:'):
        tldr_idx = i
        break

if tldr_idx is not None:
    collected = []
    for line in lines[tldr_idx + 1:]:
        stripped = line.rstrip('\n')
        if stripped.strip():
            collected.append(stripped)
            if len(collected) >= 3:
                break
    if collected:
        for l in collected:
            print(l)
        # pad to 3 if fewer lines
        for _ in range(3 - len(collected)):
            print('')
        sys.exit(0)

# Rule (b): first 3 prose lines under first # heading
in_frontmatter = False
found_h1 = False
collected = []
for line in lines:
    stripped = line.rstrip('\n')
    # Frontmatter fence detection
    if stripped == '---':
        in_frontmatter = not in_frontmatter
        continue
    if in_frontmatter:
        continue
    # H1 heading detection
    if re.match(r'^# ', stripped):
        found_h1 = True
        continue
    if not found_h1:
        continue
    # Stop at any sub-heading
    if stripped.startswith('#'):
        break
    if stripped.strip():
        collected.append(stripped)
        if len(collected) >= 3:
            break

if collected:
    for l in collected:
        print(l)
    for _ in range(3 - len(collected)):
        print('')
    sys.exit(0)

# Rule (c): fallback
print("(no summary extractable)")
print('')
print('')
PYEOF
}

# ---------------------------------------------------------------------------
# render_index_row <shard_path>
#   Print a markdown row: "- YYYY-MM-DD · <uuid> · <tldr line 1; line 2; line 3>"
#   Format is greppable by UUID.
# ---------------------------------------------------------------------------
render_index_row() {
    local shard_path="$1"
    local fname
    fname="$(basename "$shard_path" .md)"

    # Extract date from mtime via python3 (portable)
    local date_str
    date_str="$(python3 -c "
import os, time
try:
    t = os.path.getmtime('$shard_path')
    print(time.strftime('%Y-%m-%d', time.localtime(t)))
except Exception:
    print('0000-00-00')
" 2>/dev/null || echo '0000-00-00')"

    # Get TL;DR lines and collapse to semicolon-separated single line
    local tldr_raw tldr_line
    tldr_raw="$(extract_shard_tldr "$shard_path" 2>/dev/null || echo "(no summary extractable)")"
    tldr_line="$(printf '%s' "$tldr_raw" | tr '\n' ';' | sed 's/;;*/; /g; s/; $//')"

    printf -- '- %s · %s · %s\n' "$date_str" "$fname" "$tldr_line"
}

# ---------------------------------------------------------------------------
# regenerate_index <last_sessions_dir> <output_file>
#   Walk last_sessions_dir, sort newest-first (ties broken by filename ascending),
#   emit header + rows for active shards + ## Archived section for archive/.
#   Idempotent: always overwrites output_file.
# ---------------------------------------------------------------------------
regenerate_index() {
    local last_dir="$1"
    local out_file="$2"
    local archive_dir="${last_dir}/archive"

    # Collect active shards with mtime epoch for sorting
    # Format: "<epoch> <path>"
    local shards_with_time=""
    for f in "${last_dir}"/*.md; do
        [ -e "$f" ] || continue
        local bname
        bname="$(basename "$f")"
        # Exclude INDEX.md and .gitkeep
        [ "$bname" = "INDEX.md" ]  && continue
        [ "$bname" = ".gitkeep" ]  && continue

        local epoch
        epoch="$(python3 -c "
import os
try:
    print(int(os.path.getmtime('$f')))
except Exception:
    print(0)
" 2>/dev/null || echo 0)"
        shards_with_time="${shards_with_time}${epoch} ${f}
"
    done

    # Sort: primary descending by epoch (newest first),
    # secondary ascending by filename (tie-break).
    # Use python3 for portable stable sort.
    local sorted_shards=""
    if [ -n "$shards_with_time" ]; then
        sorted_shards="$(printf '%s' "$shards_with_time" | python3 -c "
import sys

entries = []
for line in sys.stdin:
    line = line.rstrip('\n')
    if not line:
        continue
    parts = line.split(' ', 1)
    if len(parts) == 2:
        entries.append((int(parts[0]), parts[1]))

# Sort by epoch descending, then by path ascending (filename tie-break)
entries.sort(key=lambda x: (-x[0], x[1]))
for epoch, path in entries:
    print(path)
")"
    fi

    # Write header
    local today
    today="$(python3 -c "import time; print(time.strftime('%Y-%m-%d'))" 2>/dev/null || date -u +%Y-%m-%d)"

    {
        printf '# last-sessions/INDEX.md\n\n'
        printf '<!-- auto-generated by scripts/memory-consolidate.sh --index-only -->\n'
        printf '<!-- regenerated: %s -->\n\n' "$today"

        local row_count=0
        if [ -n "$sorted_shards" ]; then
            printf '## Active shards (newest first)\n\n'
            while IFS= read -r shard_path; do
                [ -z "$shard_path" ] && continue
                render_index_row "$shard_path"
                row_count=$((row_count + 1))
            done <<SHARDS_EOF
$sorted_shards
SHARDS_EOF
        else
            printf '## Active shards (newest first)\n\n'
            printf '_(no shards)_\n'
        fi

        printf '\n'

        # Archived section
        printf '## Archived\n\n'
        local arc_count=0
        if [ -d "$archive_dir" ]; then
            for af in "${archive_dir}"/*.md; do
                [ -e "$af" ] || continue
                [ "$(basename "$af")" = ".gitkeep" ] && continue
                local afname
                afname="$(basename "$af" .md)"
                printf -- '- archive/%s\n' "$afname"
                arc_count=$((arc_count + 1))
            done
        fi
        if [ "$arc_count" -eq 0 ]; then
            printf '_(no archived shards)_\n'
        fi
    } > "$out_file"
}
