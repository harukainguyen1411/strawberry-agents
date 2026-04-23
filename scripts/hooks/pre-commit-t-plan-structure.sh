#!/bin/sh
# pre-commit-plan-structure.sh — Pre-commit structural linter for plan files.
#
# Plan: plans/approved/personal/2026-04-20-plan-structure-prelint.md §3
#
# Checks every staged plans/**/*.md (except plans/_template.md and
# plans/archived/**) for structural validity.
#
# Uses a single awk pass over ALL staged plan files for performance.
# Target: < 200ms for 10 staged plans.
#
# Exit 0 — all staged plan files pass structural checks.
# Exit 1 — one or more staged plan files have BLOCK findings (printed to stderr).
#
# POSIX sh (Rule 10).

set -e

# Resolve repo root from the script location
_hook_dir="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$_hook_dir/../.." && pwd)"

# 1. Get list of staged plan files (added, copied, modified)
staged_plans="$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep '^plans/.*\.md$' || true)"

if [ -z "$staged_plans" ]; then
  exit 0
fi

# 2. Filter: exclude template and archived plans; collect absolute paths into a temp file
_filter_tmp="$(mktemp /tmp/pre-commit-plan-structure-XXXXXX.tmp)"
trap 'rm -f "$_filter_tmp"' EXIT INT HUP TERM
printf '%s\n' "$staged_plans" | while IFS= read -r rel; do
  case "$rel" in
    plans/_template.md|plans/archived/*|plans/pre-orianna/*) continue ;;
  esac
  # Block paths with spaces — plan naming convention forbids them; a space here
  # is a sign something is very wrong (or a symlink attack). Fail loud.
  case "$rel" in
    *\ *) printf '[pre-commit-plan-structure] BLOCK: plan path contains a space (not allowed): %s\n' "$rel" >&2; exit 1 ;;
  esac
  abs="$REPO_ROOT/$rel"
  [ -f "$abs" ] || continue
  printf '%s\n' "$abs"
done > "$_filter_tmp"

if [ ! -s "$_filter_tmp" ]; then
  rm -f "$_filter_tmp"
  exit 0
fi

# 3. Single awk pass over all plan files (POSIX awk — no ENDFILE extension).
#    Tracks file boundaries via FNR==1 to flush per-file state.
#    Validates frontmatter keys, task estimates, and ## Test plan presence.
#    Prints [lib-plan-structure] BLOCK: messages to stderr.
_awk_rc=0
awk -v _sep="__END_OF_FILE__" '
  function flush_file(fname,    i) {
    if (!_started) return
    # Frontmatter checks
    if (!has_status) {
      print "[lib-plan-structure] BLOCK: missing required frontmatter field: `status:`" > "/dev/stderr"
      file_fail = 1
    }
    if (!has_concern) {
      print "[lib-plan-structure] BLOCK: missing required frontmatter field: `concern:`" > "/dev/stderr"
      file_fail = 1
    }
    if (!has_owner) {
      print "[lib-plan-structure] BLOCK: missing required frontmatter field: `owner:`" > "/dev/stderr"
      file_fail = 1
    }
    if (!has_created) {
      print "[lib-plan-structure] BLOCK: missing required frontmatter field: `created:`" > "/dev/stderr"
      file_fail = 1
    }
    if (!has_tests_required) {
      print "[lib-plan-structure] BLOCK: missing required frontmatter field: `tests_required:`" > "/dev/stderr"
      file_fail = 1
    }
    # Test plan check
    if (tests_required_val != "false" && tests_required_val != "False" && tests_required_val != "FALSE") {
      if (!has_test_plan_content) {
        print "[lib-plan-structure] BLOCK: tests_required is true but `## Test plan` section is missing or empty" > "/dev/stderr"
        file_fail = 1
      }
    }
    if (file_fail) {
      print "[pre-commit-plan-structure] BLOCKED: " fname > "/dev/stderr"
      total_fail++
    }
  }

  function reset_file(fname) {
    flush_file(prev_file)
    # Reset per-file state
    in_fm = 0; fm_open = 0; fm_done = 0
    in_tasks = 0; in_test_plan = 0
    has_status = 0; has_concern = 0; has_owner = 0
    has_created = 0; has_tests_required = 0
    tests_required_val = "true"
    has_test_plan_content = 0
    hours_flagged = 0; days_flagged = 0; weeks_flagged = 0
    hparen_flagged = 0; dparen_flagged = 0
    file_fail = 0
    prev_file = fname
    _started = 1
  }

  FNR == 1 { reset_file(FILENAME) }

  # --- Frontmatter parsing ---
  FNR == 1 && /^---[[:space:]]*$/ { fm_open = 1; in_fm = 1; next }
  in_fm && /^---[[:space:]]*$/ { in_fm = 0; fm_done = 1; next }

  in_fm {
    # For each key: extract value (strip key + leading/trailing space) and require non-empty.
    # This matches lib check_plan_frontmatter behaviour — empty value == missing.
    if ($0 ~ /^status:/) {
      v = $0; sub(/^status:[[:space:]]*/, "", v); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      if (length(v) > 0) has_status = 1
    }
    if ($0 ~ /^concern:/) {
      v = $0; sub(/^concern:[[:space:]]*/, "", v); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      if (length(v) > 0) has_concern = 1
    }
    if ($0 ~ /^owner:/) {
      v = $0; sub(/^owner:[[:space:]]*/, "", v); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      if (length(v) > 0) has_owner = 1
    }
    if ($0 ~ /^created:/) {
      v = $0; sub(/^created:[[:space:]]*/, "", v); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      if (length(v) > 0) has_created = 1
    }
    if ($0 ~ /^tests_required:/) {
      v = $0; sub(/^tests_required:[[:space:]]*/, "", v); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      if (length(v) > 0) { has_tests_required = 1; tests_required_val = v }
    }
    next
  }

  !fm_done { next }

  # --- Section tracking ---
  /^## Tasks[[:space:]]*$/ || /^## [0-9]+\. Tasks[[:space:]]*$/ {
    in_tasks = 1; in_test_plan = 0; next
  }
  /^## Test plan[[:space:]]*$/ {
    in_test_plan = 1; in_tasks = 0; next
  }
  /^## / {
    in_tasks = 0; in_test_plan = 0; next
  }

  # --- ## Test plan content ---
  in_test_plan && /[^[:space:]]/ && !/^#/ { has_test_plan_content = 1 }

  # --- ## Tasks validation ---
  in_tasks {
    line = $0
    # Strip inline backtick spans for prose checks
    prose = line
    while (match(prose, /`[^`]*`/)) {
      prose = substr(prose, 1, RSTART-1) substr(prose, RSTART+RLENGTH)
    }

    # Task entry lines
    if (prose ~ /^- \[[ xX]\]/) {
      if (prose !~ /estimate_minutes:/) {
        print "[lib-plan-structure] BLOCK: task entry missing estimate_minutes: field (§D4): " line > "/dev/stderr"
        file_fail = 1
      } else {
        val = prose
        sub(/.*estimate_minutes:[[:space:]]*/, "", val)
        if (match(val, /^[0-9]+/)) {
          n = substr(val, 1, RLENGTH) + 0
          if (n < 1) {
            print "[lib-plan-structure] BLOCK: estimate_minutes: " n " is below minimum (1): " line > "/dev/stderr"
            file_fail = 1
          } else if (n > 60) {
            print "[lib-plan-structure] BLOCK: estimate_minutes: " n " exceeds maximum (60); task must be decomposed (§D4): " line > "/dev/stderr"
            file_fail = 1
          }
        } else if (match(val, /^-[0-9]+/)) {
          n = substr(val, 1, RLENGTH) + 0
          print "[lib-plan-structure] BLOCK: estimate_minutes: " n " is negative (must be 1-60): " line > "/dev/stderr"
          file_fail = 1
        } else {
          print "[lib-plan-structure] BLOCK: estimate_minutes value is not an integer in task: " line > "/dev/stderr"
          file_fail = 1
        }
      }
    }

    # Banned unit literals (outside backtick spans)
    if (!hours_flagged && prose ~ /\bhours\b/) {
      print "[lib-plan-structure] BLOCK: alternative time unit \"hours\" found in ## Tasks section; use estimate_minutes only (§D4)" > "/dev/stderr"
      file_fail = 1; hours_flagged = 1
    }
    if (!days_flagged && prose ~ /\bdays\b/) {
      print "[lib-plan-structure] BLOCK: alternative time unit \"days\" found in ## Tasks section; use estimate_minutes only (§D4)" > "/dev/stderr"
      file_fail = 1; days_flagged = 1
    }
    if (!weeks_flagged && prose ~ /\bweeks\b/) {
      print "[lib-plan-structure] BLOCK: alternative time unit \"weeks\" found in ## Tasks section; use estimate_minutes only (§D4)" > "/dev/stderr"
      file_fail = 1; weeks_flagged = 1
    }
    if (!hparen_flagged && index(prose, "h)") > 0) {
      print "[lib-plan-structure] BLOCK: alternative time unit \"h)\" found in ## Tasks section; use estimate_minutes only (§D4)" > "/dev/stderr"
      file_fail = 1; hparen_flagged = 1
    }
    if (!dparen_flagged && index(prose, "(d)") > 0) {
      print "[lib-plan-structure] BLOCK: alternative time unit \"(d)\" found in ## Tasks section; use estimate_minutes only (§D4)" > "/dev/stderr"
      file_fail = 1; dparen_flagged = 1
    }
  }

  END {
    flush_file(prev_file)
    if (total_fail > 0) {
      print "[pre-commit-plan-structure] Fix the BLOCK findings above before committing." > "/dev/stderr"
      exit 1
    }
    exit 0
  }
' $(tr '\n' ' ' < "$_filter_tmp") || _awk_rc=$?

exit "$_awk_rc"
