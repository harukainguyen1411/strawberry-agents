#!/bin/sh
# scripts/assessments/migration-link-fix.sh
#
# Rewrites cross-references to assessment files that moved during migration,
# using a mv-map.json artifact that maps old paths to new paths.
#
# Usage:
#   bash scripts/assessments/migration-link-fix.sh --map <mv-map.json> [--apply] [--scan-dir <dir>]
#
# Options:
#   --map <file>       Path to mv-map.json (required)
#   --apply            Actually write rewrites to disk (default: dry-run advisory only)
#   --scan-dir <dir>   Root directory to scan for files (default: repo root)
#
# Dry-run (default): prints which files would be changed and what rewrites would occur.
# --apply mode:       Rewrites all matching references in-place; idempotent on second run.
#
# Files scanned: plans/**/*.md, .claude/agents/**/*.md, assessments/**/*.md,
#                architecture/**/*.md, agents/**/*.md, feedback/**/*.md, CLAUDE.md
#
# Exit codes:
#   0  success (dry-run: report emitted; apply: rewrites done)
#   1  error (missing map file, etc.)
#
# Idempotent: after --apply, running again changes nothing because the old paths
# are no longer present in any file.
#
# Plan: plans/approved/personal/2026-04-25-assessments-folder-structure.md §Tasks Phase C T15

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

MAP_FILE=""
APPLY=0
SCAN_DIR=""

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --map)
      MAP_FILE="$2"
      shift 2
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    --scan-dir)
      SCAN_DIR="$2"
      shift 2
      ;;
    *)
      printf 'migration-link-fix: unknown option: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

# Validate map file
if [ -z "$MAP_FILE" ]; then
  printf 'migration-link-fix: ERROR: --map <file> is required\n' >&2
  exit 1
fi

if [ ! -f "$MAP_FILE" ]; then
  printf 'migration-link-fix: ERROR: map file not found: %s\n' "$MAP_FILE" >&2
  exit 1
fi

# Resolve scan root
if [ -z "$SCAN_DIR" ]; then
  SCAN_DIR="$REPO_ROOT"
fi

# ---------------------------------------------------------------------------
# Parse mv-map.json using awk with quote-field splitting.
# JSON format:
# {
#   "old/path.md": "new/path.md",
#   ...
# }
# Produces a temp file with TAB-separated old<TAB>new pairs, one per line.
# ---------------------------------------------------------------------------

PAIRS_FILE="$(mktemp)"

awk -F'"' '
  NF >= 5 && $2 != "" && $4 != "" {
    # Line like:  "old/path.md": "new/path.md",
    # $1 = leading whitespace, $2 = key, $3 = ": ", $4 = value, $5 = trailing
    printf "%s\t%s\n", $2, $4
  }
' "$MAP_FILE" > "$PAIRS_FILE"

if [ ! -s "$PAIRS_FILE" ]; then
  printf 'migration-link-fix: WARNING: no path mappings found in %s\n' "$MAP_FILE" >&2
  rm -f "$PAIRS_FILE"
  exit 0
fi

# ---------------------------------------------------------------------------
# Find all files to scan
# ---------------------------------------------------------------------------

find_scan_files() {
  local root="$1"
  for pattern in \
    "plans" \
    ".claude/agents" \
    "assessments" \
    "architecture" \
    "agents" \
    "feedback"
  do
    local dir="$root/$pattern"
    if [ -d "$dir" ]; then
      find "$dir" -name '*.md' 2>/dev/null
    fi
  done
  # Single files at root
  [ -f "$root/CLAUDE.md" ] && printf '%s\n' "$root/CLAUDE.md"
}

# ---------------------------------------------------------------------------
# Rewrite references in a single file using sed.
# Builds a combined sed expression for all mappings.
# Returns the number of distinct old-paths found in the file.
# ---------------------------------------------------------------------------

rewrite_file() {
  local file="$1"
  local apply="$2"

  local found_count=0
  local sed_script=""

  while IFS="	" read -r old_path new_path; do
    # Skip empty
    [ -z "$old_path" ] && continue
    [ -z "$new_path" ] && continue

    if grep -qF "$old_path" "$file" 2>/dev/null; then
      found_count=$((found_count + 1))
      if [ "$apply" -eq 1 ]; then
        # Escape special sed characters in the paths
        old_esc="$(printf '%s' "$old_path" | sed 's|[/&]|\\&|g')"
        new_esc="$(printf '%s' "$new_path" | sed 's|[/&]|\\&|g')"
        sed_script="${sed_script}s|${old_esc}|${new_esc}|g;"
      else
        printf '  [dry-run] %s: "%s" -> "%s"\n' "$file" "$old_path" "$new_path"
      fi
    fi
  done < "$PAIRS_FILE"

  if [ "$apply" -eq 1 ] && [ -n "$sed_script" ]; then
    sed -i.bak "$sed_script" "$file" && rm -f "${file}.bak"
  fi

  printf '%d' "$found_count"
}

# ---------------------------------------------------------------------------
# Main scan loop
# ---------------------------------------------------------------------------

total_files=0
total_rewrites=0

while IFS= read -r file; do
  [ -f "$file" ] || continue
  # Skip the map file itself
  [ "$file" = "$MAP_FILE" ] && continue

  n="$(rewrite_file "$file" "$APPLY")"
  if [ "${n:-0}" -gt 0 ]; then
    total_files=$((total_files + 1))
    total_rewrites=$((total_rewrites + n))
    if [ "$APPLY" -eq 1 ]; then
      printf 'migration-link-fix: applied %d rewrite(s) in %s\n' "$n" "$file"
    fi
  fi
done << SCAN_EOF
$(find_scan_files "$SCAN_DIR")
SCAN_EOF

rm -f "$PAIRS_FILE"

if [ "$APPLY" -eq 1 ]; then
  printf 'migration-link-fix: done. %d file(s) rewritten, %d reference(s) updated.\n' \
    "$total_files" "$total_rewrites"
else
  printf 'migration-link-fix: dry-run complete. %d file(s) with %d reference(s) to rewrite. Use --apply to write.\n' \
    "$total_files" "$total_rewrites"
fi

exit 0
