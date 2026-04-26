#!/usr/bin/env bash
# scripts/assessments/index-gen.sh
#
# Generates per-category INDEX.md files by scanning YAML frontmatter of
# assessment .md files.  Produces 8 per-category INDEX.md files and 1
# top-level assessments/INDEX.md when run without --category.
#
# Usage:
#   bash scripts/assessments/index-gen.sh [options]
#
# Options:
#   --category <name>  Process only the named category (one of the 8 canonical)
#   --root <dir>       Override the assessments root dir (default: <repo_root>/assessments)
#   --out <file>       Write output to <file> instead of <root>/<category>/INDEX.md
#                      (only valid with --category)
#
# Exit codes:
#   0  success
#   1  frontmatter validation error — offending file named on stderr
#
# Idempotent: running twice on unchanged input produces identical output.
#
# Plan: plans/approved/personal/2026-04-25-assessments-folder-structure.md §Tasks Phase C T14

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Defaults
CATEGORIES="research qa-reports audits reviews retrospectives runbooks advisories artifacts"
ASSESSMENTS_ROOT=""
SINGLE_CATEGORY=""
SINGLE_OUT=""

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --category)
      SINGLE_CATEGORY="$2"
      shift 2
      ;;
    --root)
      ASSESSMENTS_ROOT="$2"
      shift 2
      ;;
    --out)
      SINGLE_OUT="$2"
      shift 2
      ;;
    *)
      printf 'index-gen: unknown option: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

# Resolve root
if [ -z "$ASSESSMENTS_ROOT" ]; then
  ASSESSMENTS_ROOT="$REPO_ROOT/assessments"
fi

# ---------------------------------------------------------------------------
# Frontmatter parsing helpers (pure awk — no python dependency)
# ---------------------------------------------------------------------------

# Extract a single YAML field value from a file's frontmatter block.
# Usage: get_field <file> <field>
# Prints the value or empty string if not found.
get_field() {
  local file="$1"
  local field="$2"
  awk -v field="$field" '
    /^---$/ { if (in_fm) { exit } else { in_fm=1; next } }
    in_fm && /^[a-zA-Z_][a-zA-Z0-9_-]*:/ {
      split($0, kv, /:[[:space:]]*/);
      if (kv[1] == field) {
        # Remove leading/trailing whitespace from value
        val = kv[2]
        sub(/^[[:space:]]+/, "", val)
        sub(/[[:space:]]+$/, "", val)
        print val
        exit
      }
    }
  ' "$file"
}

# Validate that a file has all 8 mandatory frontmatter fields.
# Prints missing field names and returns 1 if any are missing.
validate_frontmatter() {
  local file="$1"
  local missing=""
  for field in date author category concern target state owner session; do
    val="$(get_field "$file" "$field")"
    if [ -z "$val" ]; then
      missing="$missing $field"
    fi
  done
  if [ -n "$missing" ]; then
    printf 'index-gen: ERROR: %s is missing required frontmatter field(s):%s\n' "$file" "$missing" >&2
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# INDEX.md generation for a single category
# ---------------------------------------------------------------------------

# Usage: gen_category_index <category> <cat_dir> <out_file>
gen_category_index() {
  local category="$1"
  local cat_dir="$2"
  local out_file="$3"

  # Collect .md files (skip README.md, INDEX.md, .gitkeep; walk all subdirs)
  local files=""
  if [ -d "$cat_dir" ]; then
    files="$(find "$cat_dir" -name '*.md' \
      ! -name 'README.md' \
      ! -name 'INDEX.md' \
      2>/dev/null | sort)"
  fi

  # Validate all files first — exit non-zero on first bad file
  local validation_ok=1
  if [ -n "$files" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      if ! validate_frontmatter "$f"; then
        validation_ok=0
      fi
    done <<< "$files"
  fi
  if [ "$validation_ok" -eq 0 ]; then
    return 1
  fi

  # Get current date for "last 30 days" cutoff (POSIX date arithmetic via awk)
  local today=""
  today="$(date +%Y-%m-%d)"
  local cutoff=""
  cutoff="$(awk -v today="$today" 'BEGIN {
    # Parse today YYYY-MM-DD
    split(today, a, "-")
    y=a[1]+0; m=a[2]+0; d=a[3]+0
    # Subtract 30 days
    d -= 30
    while (d <= 0) {
      m--
      if (m <= 0) { m=12; y-- }
      # Days in month (approximate — close enough for a display cutoff)
      if (m==2) { days_in_m = (y%4==0 && (y%100!=0 || y%400==0)) ? 29 : 28 }
      else if (m==4||m==6||m==9||m==11) { days_in_m=30 }
      else { days_in_m=31 }
      d += days_in_m
    }
    printf "%04d-%02d-%02d", y, m, d
  }')"

  # Separate files into buckets by state
  local active_recent="" active_older="" living=""
  if [ -n "$files" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      local state date author target rel_path
      state="$(get_field "$f" "state")"
      date="$(get_field "$f" "date")"
      owner_val="$(get_field "$f" "owner")"
      target="$(get_field "$f" "target")"
      # Relative path from assessments root
      rel_path="$(printf '%s' "$f" | sed "s|${cat_dir}/||")"

      case "$state" in
        living)
          living="${living}| ${rel_path} | ${target} | ${owner_val} | ${date} |
"
          ;;
        archived)
          # Archived entries listed under Archived section via link
          ;;
        *)
          # active or superseded or anything else
          if [ -n "$date" ] && [[ "$date" > "$cutoff" ]]; then
            active_recent="${active_recent}| ${rel_path} | ${target} | ${owner_val} | ${date} | ${state} |
"
          else
            active_older="${active_older}| ${rel_path} | ${target} | ${owner_val} | ${date} | ${state} |
"
          fi
          ;;
      esac
    done <<< "$files"
  fi

  # Emit the INDEX.md
  {
    printf '<!-- auto-generated by scripts/assessments/index-gen.sh -->\n'
    printf '# %s assessments\n\n' "$category"

    if [ -z "$files" ]; then
      printf '_no entries yet_\n\n'
      printf 'See [archived/](./archived/) for historical entries.\n'
    else
      # Table header
      local table_header="| path | target | owner | date | status |
|------|--------|-------|------|--------|"

      printf '## Active (last 30 days)\n\n'
      if [ -n "$active_recent" ]; then
        printf '%s\n' "$table_header"
        printf '%s' "$active_recent"
      else
        printf '_no entries in this period_\n'
      fi
      printf '\n'

      printf '## Active (older)\n\n'
      if [ -n "$active_older" ]; then
        printf '%s\n' "$table_header"
        printf '%s' "$active_older"
      else
        printf '_no entries_\n'
      fi
      printf '\n'

      if [ -n "$living" ]; then
        printf '## Living\n\n'
        printf '| path | target | owner | date |\n'
        printf '|------|--------|-------|------|\n'
        printf '%s' "$living"
        printf '\n'
      fi

      printf '## Archived\n\n'
      printf 'See [archived/](./archived/) for historical entries.\n'
    fi
  } > "$out_file"
}

# ---------------------------------------------------------------------------
# Top-level INDEX.md generation
# ---------------------------------------------------------------------------

gen_top_index() {
  local root="$1"
  local out_file="$2"

  {
    printf '<!-- auto-generated by scripts/assessments/index-gen.sh -->\n'
    printf '# Assessments index\n\n'
    printf 'See `plans/approved/personal/2026-04-25-assessments-folder-structure.md` for the full taxonomy.\n\n'
    printf '| category | active | living | index |\n'
    printf '|----------|--------|--------|-------|\n'

    for cat in $CATEGORIES; do
      local cat_dir="$root/$cat"
      local active_count=0 living_count=0
      if [ -d "$cat_dir" ]; then
        local md_files
        md_files="$(find "$cat_dir" -name '*.md' ! -name 'README.md' ! -name 'INDEX.md' 2>/dev/null || true)"
        if [ -n "$md_files" ]; then
          while IFS= read -r f; do
            [ -z "$f" ] && continue
            local st
            st="$(get_field "$f" "state")"
            case "$st" in
              living) living_count=$((living_count + 1)) ;;
              archived) ;;
              *) active_count=$((active_count + 1)) ;;
            esac
          done <<< "$md_files"
        fi
      fi
      printf '| %s | %d | %d | [INDEX](./%s/INDEX.md) |\n' \
        "$cat" "$active_count" "$living_count" "$cat"
    done
  } > "$out_file"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if [ -n "$SINGLE_CATEGORY" ]; then
  cat_dir="$ASSESSMENTS_ROOT/$SINGLE_CATEGORY"
  if [ -n "$SINGLE_OUT" ]; then
    out_file="$SINGLE_OUT"
  else
    out_file="$cat_dir/INDEX.md"
  fi
  # If the category dir doesn't exist, treat as empty
  mkdir -p "$cat_dir" 2>/dev/null || true
  gen_category_index "$SINGLE_CATEGORY" "$cat_dir" "$out_file"

  # Also echo the generated content to stdout (for C1 test which captures output)
  cat "$out_file"
else
  # Generate all 8 category indexes + top-level
  exit_code=0
  for cat in $CATEGORIES; do
    cat_dir="$ASSESSMENTS_ROOT/$cat"
    out_file="$cat_dir/INDEX.md"
    if [ ! -d "$cat_dir" ]; then
      continue
    fi
    if ! gen_category_index "$cat" "$cat_dir" "$out_file"; then
      exit_code=1
    fi
  done

  # Top-level index
  gen_top_index "$ASSESSMENTS_ROOT" "$ASSESSMENTS_ROOT/INDEX.md"

  exit $exit_code
fi
