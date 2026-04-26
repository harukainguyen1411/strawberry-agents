#!/usr/bin/env bash
# scripts/hooks/pre-commit-assessments-index-gen.sh
#
# Pre-commit hook: validates frontmatter of staged assessment files and
# regenerates affected category INDEX.md files, staging them in the same commit.
#
# Behaviour:
#   - Exits 0 immediately if no assessments/** paths are staged (H4 no-op).
#   - Validates 8 mandatory frontmatter fields on each staged assessment .md;
#     blocks commit (exit 1) and names missing fields on stderr if invalid (H5).
#   - Runs scripts/assessments/index-gen.sh --category <affected> for each
#     category touched by the staged files (H3).
#   - Stages the regenerated INDEX.md files in the same commit.
#   - Skips regeneration if INDEX.md is already current / not modified (H6).
#
# Exit codes:
#   0  allow commit
#   1  frontmatter validation failed or index-gen failed — commit blocked
#
# Plan: plans/approved/personal/2026-04-25-assessments-folder-structure.md §Tasks Phase C T16

set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'pre-commit-assessments-index-gen: ERROR: not inside a git repository\n' >&2
  exit 1
}

INDEX_GEN="$REPO_ROOT/scripts/assessments/index-gen.sh"

# ---------------------------------------------------------------------------
# 1. Detect staged assessment files
# ---------------------------------------------------------------------------

staged_assessment_files="$(git diff --cached --name-only 2>/dev/null \
  | grep -E '^assessments/[^/]+/.+\.md$' \
  | grep -v '/INDEX\.md$' \
  | grep -v '/README\.md$' \
  || true)"

if [ -z "$staged_assessment_files" ]; then
  # No assessment files staged — nothing to do
  exit 0
fi

# ---------------------------------------------------------------------------
# 2. Validate frontmatter on each staged assessment file
# ---------------------------------------------------------------------------

# Extract a YAML frontmatter field value using awk (POSIX, no python).
get_field() {
  local file="$1"
  local field="$2"
  awk -v field="$field" '
    /^---$/ { if (in_fm) { exit } else { in_fm=1; next } }
    in_fm && /^[a-zA-Z_][a-zA-Z0-9_-]*:/ {
      split($0, kv, /:[[:space:]]*/);
      if (kv[1] == field) {
        val = kv[2]
        sub(/^[[:space:]]+/, "", val)
        sub(/[[:space:]]+$/, "", val)
        print val
        exit
      }
    }
  ' "$file"
}

validation_failed=0
for staged_file in $staged_assessment_files; do
  full_path="$REPO_ROOT/$staged_file"
  # Skip deletions
  [ -f "$full_path" ] || continue

  missing_fields=""
  for field in date author category concern target state owner session; do
    val="$(get_field "$full_path" "$field")"
    if [ -z "$val" ]; then
      missing_fields="${missing_fields} ${field}"
    fi
  done

  if [ -n "$missing_fields" ]; then
    printf 'pre-commit-assessments-index-gen: ERROR: %s missing required frontmatter field(s):%s\n' \
      "$staged_file" "$missing_fields" >&2
    validation_failed=1
  fi
done

if [ "$validation_failed" -ne 0 ]; then
  printf 'pre-commit-assessments-index-gen: commit blocked — fix missing frontmatter fields above and retry.\n' >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 3. Determine which categories were affected
# ---------------------------------------------------------------------------

affected_categories="$(printf '%s\n' "$staged_assessment_files" \
  | sed 's|assessments/\([^/]*\)/.*|\1|' \
  | sort -u)"

if [ -z "$affected_categories" ]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# 4. Regenerate INDEX.md for each affected category and stage it
# ---------------------------------------------------------------------------

if [ ! -f "$INDEX_GEN" ]; then
  printf 'pre-commit-assessments-index-gen: WARNING: index-gen.sh not found at %s — skipping index regeneration\n' \
    "$INDEX_GEN" >&2
  exit 0
fi

for cat in $affected_categories; do
  cat_dir="$REPO_ROOT/assessments/$cat"
  index_file="$cat_dir/INDEX.md"

  [ -d "$cat_dir" ] || continue

  # Compute index before regeneration to detect if it actually changes
  old_sum=""
  if [ -f "$index_file" ]; then
    old_sum="$(cksum "$index_file" 2>/dev/null | awk '{print $1}')"
  fi

  # Regenerate (redirect stdout to /dev/null — gen writes to file via --out)
  if ! bash "$INDEX_GEN" --category "$cat" --root "$REPO_ROOT/assessments" \
       --out "$index_file" > /dev/null 2>&1; then
    printf 'pre-commit-assessments-index-gen: ERROR: index-gen.sh failed for category %s\n' "$cat" >&2
    exit 1
  fi

  new_sum=""
  if [ -f "$index_file" ]; then
    new_sum="$(cksum "$index_file" 2>/dev/null | awk '{print $1}')"
  fi

  if [ "$old_sum" != "$new_sum" ]; then
    # Stage the updated INDEX.md
    git add "$index_file" 2>/dev/null || {
      printf 'pre-commit-assessments-index-gen: WARNING: could not stage %s\n' "$index_file" >&2
    }
  fi
  # If sum unchanged: INDEX is already current — no-op (H6)
done

exit 0
