#!/usr/bin/env bash
# scripts/feedback-index.sh — feedback INDEX generator and schema validator
#
# §D2: Reads feedback/*.md (not feedback/archived/), extracts §D1 frontmatter,
# writes feedback/INDEX.md per the §D3 template.
#
# §D12 bind-points (breaking-change-locked):
#   (a) Severity is column 1 in header row
#   (b) Date is column 2 in header row
#   (c) Summary line: "Open: N | High: N | Medium: N | Low: N"
#   (d) Summary line: "Graduated (this week): N"
#
# Usage:
#   feedback-index.sh --check <file>          validate one file
#   feedback-index.sh --check --dir <dir>     validate all *.md in dir
#   feedback-index.sh --check --audit-history --dir <dir>
#                                             also check commit prefixes
#   feedback-index.sh --dir <dir> --out <file>  generate INDEX
#   feedback-index.sh --dir <dir>             generate feedback/INDEX.md
#
# Exit codes:
#   0  ok
#   1  validation or rendering error
#
# Env:
#   FEEDBACK_INDEX_RENAME_SEVERITY  — if set, use this string instead of
#                                      "Severity" as column-1 header (for
#                                      mutation-simulation tests per TT2-bind §e)
#   FEEDBACK_TEST_MODE              — if "1", skip git operations (for CI)

set -uo pipefail

# ---------------------------------------------------------------------------
# Constants — §D1 schema
# ---------------------------------------------------------------------------

VALID_CATEGORIES="hook-friction schema-surprise tool-missing tool-permission doc-stale review-loop coordinator-discipline retry-loop context-loss other"
VALID_SEVERITIES="low medium high"
VALID_STATES="open acknowledged graduated stale"
VALID_CONCERNS="work personal"
REQUIRED_FRONTMATTER_FIELDS="date time author concern category severity friction_cost_minutes state"
REQUIRED_BODY_SECTIONS="## What went wrong ## Suggestion ## Why I'm writing this now"

# Column 1 header — may be overridden for mutation-simulation tests
SEVERITY_COL_HEADER="${FEEDBACK_INDEX_RENAME_SEVERITY:-Severity}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

err() { printf '%s\n' "$*" >&2; }

# Extract a YAML frontmatter field value from a file.
# Usage: extract_field <file> <fieldname>
# Prints the value (stripped of quotes) or empty string.
extract_field() {
  local file="$1"
  local field="$2"
  # Grab only the frontmatter block (between first pair of --- delimiters)
  awk '
    /^---$/ { if (fm==0) { fm=1; next } else { exit } }
    fm==1 && /^'"$field"':/ {
      sub(/^'"$field"':[ \t]*/, "")
      # Remove surrounding quotes
      gsub(/^["'"'"']|["'"'"']$/, "")
      print
      exit
    }
  ' "$file"
}

# Check whether a file has a given section heading in its body.
has_section() {
  local file="$1"
  local section="$2"
  # Look outside the frontmatter block
  awk '
    /^---$/ { dashes++; next }
    dashes>=2 && /^'"$section"'/ { found=1 }
    END { exit (found ? 0 : 1) }
    BEGIN { dashes=0; found=0 }
  ' "$file"
}

# Returns 0 if value is in space-separated list
in_list() {
  local val="$1"
  local list="$2"
  for item in $list; do
    [ "$val" = "$item" ] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# Schema validation for a single file
# ---------------------------------------------------------------------------

validate_file() {
  local file="$1"
  local ok=0

  # Check file exists
  if [ ! -f "$file" ]; then
    err "feedback-index: file not found: $file"
    return 1
  fi

  # Must have frontmatter delimiters
  local dash_count
  dash_count=$(grep -c '^---$' "$file" 2>/dev/null || echo 0)
  if [ "$dash_count" -lt 2 ]; then
    err "feedback-index: §D1 schema error in $file: missing frontmatter delimiters (---)"
    return 1
  fi

  # Required field presence
  local field val
  for field in $REQUIRED_FRONTMATTER_FIELDS; do
    val="$(extract_field "$file" "$field")"
    if [ -z "$val" ]; then
      err "feedback-index: §D1 schema error in $file: required field '$field' is missing or empty"
      ok=1
    fi
  done

  # author must not be empty string
  local author
  author="$(extract_field "$file" "author")"
  if [ -z "$author" ]; then
    err "feedback-index: §D1 schema error in $file: 'author' field is missing or empty"
    ok=1
  fi

  # concern enum
  local concern
  concern="$(extract_field "$file" "concern")"
  if [ -n "$concern" ] && ! in_list "$concern" "$VALID_CONCERNS"; then
    err "feedback-index: §D1 schema error in $file: 'concern' value '$concern' not in enum (work|personal)"
    ok=1
  fi

  # category enum
  local category
  category="$(extract_field "$file" "category")"
  if [ -n "$category" ] && ! in_list "$category" "$VALID_CATEGORIES"; then
    err "feedback-index: §D1 schema error in $file: 'category' value '$category' not in §D1 enum"
    ok=1
  fi

  # severity enum
  local severity
  severity="$(extract_field "$file" "severity")"
  if [ -n "$severity" ] && ! in_list "$severity" "$VALID_SEVERITIES"; then
    err "feedback-index: §D1 schema error in $file: 'severity' value '$severity' not in enum (low|medium|high)"
    ok=1
  fi

  # state enum
  local state
  state="$(extract_field "$file" "state")"
  if [ -n "$state" ] && ! in_list "$state" "$VALID_STATES"; then
    err "feedback-index: §D1 schema error in $file: 'state' value '$state' not in enum (open|acknowledged|graduated|stale)"
    ok=1
  fi

  # Invariant 6 — state machine monotone:
  # An entry with state: open AND a graduated_to: pointer is illegal
  local graduated_to
  graduated_to="$(extract_field "$file" "graduated_to")"
  if [ "$state" = "open" ] && [ -n "$graduated_to" ]; then
    err "feedback-index: §D1 schema error in $file: state: open cannot coexist with graduated_to: pointer (Invariant 6 — state machine monotone)"
    ok=1
  fi

  # Required body sections
  local section
  for section in "## What went wrong" "## Suggestion" "## Why I'm writing this now"; do
    if ! has_section "$file" "$section"; then
      err "feedback-index: §D1 schema error in $file: required body section '$section' is missing"
      ok=1
    fi
  done

  return $ok
}

# ---------------------------------------------------------------------------
# Audit-history mode: check commit prefixes for all feedback files in a dir
# ---------------------------------------------------------------------------

audit_history() {
  local dir="$1"
  local ok=0

  # Require git to be available
  if ! command -v git >/dev/null 2>&1; then
    err "feedback-index: --audit-history requires git"
    return 1
  fi

  # Find git repo root containing this directory
  local repo_root
  repo_root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || {
    err "feedback-index: --audit-history: directory '$dir' is not inside a git repository"
    return 1
  }

  local file rel_file commit_msg
  for file in "$dir"/*.md; do
    [ -f "$file" ] || continue
    [ "$(basename "$file")" = "INDEX.md" ] && continue

    rel_file="${file#$repo_root/}"

    # Get the commit that introduced this file
    commit_msg="$(git -C "$repo_root" log --oneline --follow -- "$rel_file" 2>/dev/null | tail -1)"

    if [ -z "$commit_msg" ]; then
      # File not yet committed — skip audit for uncommitted files
      continue
    fi

    # The commit message must start with 'chore: feedback' (case-sensitive)
    if ! printf '%s\n' "$commit_msg" | grep -qE '^[0-9a-f]+ chore: feedback'; then
      err "feedback-index: audit-history: rogue entry detected in $rel_file"
      err "  Introducing commit prefix must be 'chore: feedback' or 'chore: feedback sweep'"
      err "  Found commit: $commit_msg"
      ok=1
    fi
  done

  return $ok
}

# ---------------------------------------------------------------------------
# Index generation
# ---------------------------------------------------------------------------

render_index() {
  local dir="$1"
  local out="$2"

  local tmp
  tmp="$(mktemp)"

  # Stable timestamp: use the latest mtime of any .md file in dir so that
  # running twice on an unchanged tree produces zero diff (Invariant 4).
  local generated_ts
  local latest_mtime=0
  local f_mtime
  for mf in "$dir"/*.md; do
    [ -f "$mf" ] || continue
    # BSD (macOS) stat: stat -f %m; GNU stat: stat -c %Y
    # Strip non-numeric characters and trailing whitespace to ensure clean integer
    f_mtime="$(stat -f '%m' "$mf" 2>/dev/null || stat -c '%Y' "$mf" 2>/dev/null || echo 0)"
    f_mtime="${f_mtime%%[!0-9]*}"  # keep only leading digits
    f_mtime="${f_mtime:-0}"
    if [ "$f_mtime" -gt "$latest_mtime" ] 2>/dev/null; then
      latest_mtime="$f_mtime"
    fi
  done
  if [ "$latest_mtime" -gt 0 ] 2>/dev/null; then
    # Format the latest mtime as an ISO timestamp in Asia/Bangkok (UTC+7)
    generated_ts="$(TZ=Asia/Bangkok date -r "$latest_mtime" '+%Y-%m-%dT%H:%M:%S+07:00' 2>/dev/null || \
                    date -d "@$latest_mtime" '+%Y-%m-%dT%H:%M:%S+07:00' 2>/dev/null || \
                    date '+%Y-%m-%dT%H:%M:%S+07:00')"
  else
    generated_ts="$(TZ=Asia/Bangkok date '+%Y-%m-%dT%H:%M:%S+07:00' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')"
  fi

  # Collect rows from open entries (state: open)
  local count_open=0
  local count_high=0
  local count_medium=0
  local count_low=0
  local count_graduated_week=0
  local count_stale=0
  local rows=""

  # Determine the current week's start (7 days ago) for graduated-this-week count
  # Use a 7-day window
  local now_epoch
  now_epoch="$(date +%s 2>/dev/null || echo 0)"
  local week_ago_epoch=$(( now_epoch - 7 * 86400 ))

  local file severity date author category slug cost state graduated_to
  for file in "$dir"/*.md; do
    [ -f "$file" ] || continue
    [ "$(basename "$file")" = "INDEX.md" ] && continue
    # Invariant 10: only render YYYY-MM-DD-* named files
    printf '%s' "$(basename "$file")" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-' || continue

    state="$(extract_field "$file" "state")"
    severity="$(extract_field "$file" "severity")"
    date="$(extract_field "$file" "date")"
    author="$(extract_field "$file" "author")"
    category="$(extract_field "$file" "category")"
    cost="$(extract_field "$file" "friction_cost_minutes")"
    graduated_to="$(extract_field "$file" "graduated_to")"

    # Derive slug from filename: strip date-time-author prefix
    local basename
    basename="$(basename "$file" .md)"
    # Filename format: YYYY-MM-DD-HHMM-author-slug or YYYY-MM-DD-author-slug
    slug="$(printf '%s' "$basename" | sed 's/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]-[^-]*-//' | sed 's/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[^-]*-//' )"
    # Fallback: use the full basename
    [ -z "$slug" ] && slug="$basename"

    # Track graduated-this-week
    if [ "$state" = "graduated" ]; then
      # Check if date is within the last 7 days
      local file_epoch
      file_epoch="$(date -j -f '%Y-%m-%d' "$date" '+%s' 2>/dev/null || \
                    date -d "$date" '+%s' 2>/dev/null || echo 0)"
      if [ "$file_epoch" -ge "$week_ago_epoch" ] 2>/dev/null; then
        count_graduated_week=$(( count_graduated_week + 1 ))
      fi
    fi

    # Track stale
    if [ "$state" = "stale" ]; then
      count_stale=$(( count_stale + 1 ))
    fi

    # Only include open entries in the table
    [ "$state" = "open" ] || continue

    count_open=$(( count_open + 1 ))
    case "$severity" in
      high)   count_high=$(( count_high + 1 )) ;;
      medium) count_medium=$(( count_medium + 1 )) ;;
      low)    count_low=$(( count_low + 1 )) ;;
    esac

    rows="$rows${severity}|${date}|${author}|${category}|${slug}|${cost}"$'\n'
  done

  # Sort rows by severity (high → medium → low), then date
  local sorted_rows
  sorted_rows="$(printf '%s' "$rows" | awk -F'|' 'NF>0 {
    sev=$1; date=$2
    order = (sev=="high") ? 1 : (sev=="medium") ? 2 : 3
    print order "|" date "|" $0
  }' | sort -t'|' -k1,1n -k2,2 | sed 's/^[0-9]*|[^|]*|//')"

  # Write the INDEX
  {
    printf '# Open feedback index\n\n'
    printf '_Auto-generated by `scripts/feedback-index.sh`. Do not hand-edit._\n'
    printf '_Generated: %s_\n\n' "$generated_ts"
    printf '| %s | Date | Author | Category | Slug | Cost (min) |\n' "$SEVERITY_COL_HEADER"
    printf '|----------|------------|---------|--------------------------|------------------------------------------|------------|\n'

    if [ -n "$sorted_rows" ]; then
      # Append trailing newline so the last line is read by the while loop
      printf '%s\n' "$sorted_rows" | while IFS='|' read -r sev dt auth cat sl cst; do
        [ -z "$sev" ] && continue
        printf '| %-8s | %-10s | %-7s | %-24s | %-40s | %-10s |\n' \
          "$sev" "$dt" "$auth" "$cat" "$sl" "$cst"
      done
    fi

    printf '\n'
    printf 'Open: %d | High: %d | Medium: %d | Low: %d\n' \
      "$count_open" "$count_high" "$count_medium" "$count_low"
    printf 'Graduated (this week): %d\n' "$count_graduated_week"
    printf 'Stale (pending prune): %d\n' "$count_stale"
  } > "$tmp"

  # Move to destination (atomic)
  mv "$tmp" "$out"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

MODE=""         # check | render
DIR=""
OUT=""
SINGLE_FILE=""
AUDIT_HISTORY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --check)
      MODE="check"
      shift
      ;;
    --audit-history)
      AUDIT_HISTORY=1
      shift
      ;;
    --dir)
      DIR="$2"
      shift 2
      ;;
    --out)
      OUT="$2"
      shift 2
      ;;
    -*)
      err "feedback-index: unknown option: $1"
      exit 1
      ;;
    *)
      # Positional: single file to check
      SINGLE_FILE="$1"
      shift
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------

if [ "$MODE" = "check" ]; then
  if [ -n "$SINGLE_FILE" ]; then
    # Validate a single file
    validate_file "$SINGLE_FILE"
    exit $?
  elif [ -n "$DIR" ]; then
    # Validate all files in directory
    failed=0
    found=0
    for f in "$DIR"/*.md; do
      [ -f "$f" ] || continue
      [ "$(basename "$f")" = "INDEX.md" ] && continue
      # Invariant 10: only process YYYY-MM-DD-* named files in --dir mode
      printf '%s' "$(basename "$f")" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-' || continue
      found=$(( found + 1 ))
      validate_file "$f" || failed=1
    done
    if [ $failed -ne 0 ]; then
      exit 1
    fi
    if [ "$AUDIT_HISTORY" -eq 1 ]; then
      audit_history "$DIR" || exit 1
    fi
    exit 0
  else
    err "feedback-index: --check requires a file argument or --dir"
    exit 1
  fi
else
  # Render mode
  if [ -z "$DIR" ]; then
    err "feedback-index: --dir is required for index generation"
    exit 1
  fi
  if [ -z "$OUT" ]; then
    OUT="$DIR/INDEX.md"
  fi

  # Validate all files first (Invariant 4: idempotent generation requires valid inputs)
  failed=0
  for f in "$DIR"/*.md; do
    [ -f "$f" ] || continue
    [ "$(basename "$f")" = "INDEX.md" ] && continue
    # Invariant 10: in --dir mode, only process files whose names follow the
    # YYYY-MM-DD-* convention. Out-of-place files (plans, READMEs, etc.) are
    # silently skipped so they do not appear in the generated INDEX.
    printf '%s' "$(basename "$f")" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-' || continue
    validate_file "$f" || failed=1
  done
  if [ $failed -ne 0 ]; then
    err "feedback-index: schema errors found — index not generated"
    exit 1
  fi

  render_index "$DIR" "$OUT"

  # Audit history if requested
  if [ "$AUDIT_HISTORY" -eq 1 ]; then
    audit_history "$DIR" || exit 1
  fi

  exit 0
fi
