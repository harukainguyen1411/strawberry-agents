#!/usr/bin/env bash
# _lib_decision_capture.sh — sourced-only library for decision capture, validation,
# index generation, and preference rollup.
#
# Functions:
#   validate_decision_frontmatter <file>
#   compute_match <coord_pick> <duong_pick> <duong_concurred_silently>
#   infer_slug <question> <log_dir>
#   render_index_row <decision_file>
#   regenerate_decisions_index <coordinator_dir> <output_file>
#   rollup_preferences_counts <coordinator_dir> <preferences_md_file>
#
# Refs: plans/approved/personal/2026-04-21-coordinator-decision-feedback.md §4.1–§4.4
#
# POSIX-portable bash — runs on macOS and Git Bash on Windows (Rule 10)

# ---------------------------------------------------------------------------
# Test-mode support (OQ-T1 resolution)
# DECISION_TEST_MODE=1 activates rename-hook env overrides so mutation-simulation
# tests exercise the production code path.
# ---------------------------------------------------------------------------

# Field name resolution — DECISION_RENAME_* env vars are honoured ONLY when
# DECISION_TEST_MODE=1 is active. In production (DECISION_TEST_MODE unset or 0)
# the overrides are ignored to prevent hostile env vars from causing gratuitous
# bind-contract failures in deployed coordinator sessions.
# Refs: PR #64 review finding I3.
_decision_field_axes() {
  if [ "${DECISION_TEST_MODE:-0}" = "1" ] && [ -n "${DECISION_RENAME_AXES:-}" ]; then
    printf '%s' "${DECISION_RENAME_AXES}"
  else
    printf 'axes'
  fi
}

_decision_field_match() {
  if [ "${DECISION_TEST_MODE:-0}" = "1" ] && [ -n "${DECISION_RENAME_MATCH:-}" ]; then
    printf '%s' "${DECISION_RENAME_MATCH}"
  else
    printf 'match'
  fi
}

_decision_field_coord_conf() {
  if [ "${DECISION_TEST_MODE:-0}" = "1" ] && [ -n "${DECISION_RENAME_COORD_CONF:-}" ]; then
    printf '%s' "${DECISION_RENAME_COORD_CONF}"
  else
    printf 'coordinator_confidence'
  fi
}

_decision_field_decision_id() {
  if [ "${DECISION_TEST_MODE:-0}" = "1" ] && [ -n "${DECISION_RENAME_DECISION_ID:-}" ]; then
    printf '%s' "${DECISION_RENAME_DECISION_ID}"
  else
    printf 'decision_id'
  fi
}

# ---------------------------------------------------------------------------
# validate_decision_frontmatter <file>
#
# Validates required YAML frontmatter fields in a decision log file.
# Returns 0 on valid, non-zero on invalid (with [lib-decision] BLOCK: on stderr).
# ---------------------------------------------------------------------------
validate_decision_frontmatter() {
  local file="$1"

  if [ ! -f "$file" ]; then
    printf '[lib-decision] BLOCK: file not found: %s\n' "$file" >&2
    return 1
  fi

  # Extract frontmatter block (between first pair of ---)
  local in_frontmatter=0
  local frontmatter=""
  while IFS= read -r line; do
    if [ "$in_frontmatter" -eq 0 ] && [ "$line" = "---" ]; then
      in_frontmatter=1
      continue
    fi
    if [ "$in_frontmatter" -eq 1 ] && [ "$line" = "---" ]; then
      break
    fi
    if [ "$in_frontmatter" -eq 1 ]; then
      frontmatter="${frontmatter}${line}
"
    fi
  done < "$file"

  # Determine the actual field names (may be renamed in test mode)
  local axes_field match_field conf_field id_field
  axes_field="$(_decision_field_axes)"
  match_field="$(_decision_field_match)"
  conf_field="$(_decision_field_coord_conf)"
  id_field="$(_decision_field_decision_id)"

  # Check required fields
  local errors=0

  # decision_id (or renamed field)
  if ! printf '%s' "$frontmatter" | grep -qE "^${id_field}:"; then
    printf '[lib-decision] BLOCK: missing required field: %s\n' "$id_field" >&2
    errors=$((errors + 1))
  fi

  # date
  if ! printf '%s' "$frontmatter" | grep -qE "^date:"; then
    printf '[lib-decision] BLOCK: missing required field: date\n' >&2
    errors=$((errors + 1))
  fi

  # coordinator
  if ! printf '%s' "$frontmatter" | grep -qE "^coordinator:"; then
    printf '[lib-decision] BLOCK: missing required field: coordinator\n' >&2
    errors=$((errors + 1))
  fi

  # axes (or renamed field) — must be present AND be a YAML list (square brackets)
  # Bind contract tripwire: if DECISION_RENAME_AXES is set to a non-canonical name,
  # the field has been renamed away from the bind-contract name 'axes' — fail loud.
  if [ -n "${DECISION_RENAME_AXES:-}" ] && [ "${DECISION_RENAME_AXES}" != "axes" ]; then
    printf '[lib-decision] BLOCK: bind-contract violation: axes field renamed to %s — schema bind requires "axes"\n' "${DECISION_RENAME_AXES}" >&2
    errors=$((errors + 1))
  elif ! printf '%s' "$frontmatter" | grep -qE "^${axes_field}:"; then
    printf '[lib-decision] BLOCK: missing required field: %s\n' "$axes_field" >&2
    errors=$((errors + 1))
  else
    # axes must be in list format: [...]
    if ! printf '%s' "$frontmatter" | grep -qE "^${axes_field}: \["; then
      printf '[lib-decision] BLOCK: field %s must be a YAML list (use square-bracket notation)\n' "$axes_field" >&2
      errors=$((errors + 1))
    fi
  fi

  # question
  if ! printf '%s' "$frontmatter" | grep -qE "^question:"; then
    printf '[lib-decision] BLOCK: missing required field: question\n' >&2
    errors=$((errors + 1))
  fi

  # options
  if ! printf '%s' "$frontmatter" | grep -qE "^options:"; then
    printf '[lib-decision] BLOCK: missing required field: options\n' >&2
    errors=$((errors + 1))
  fi

  # coordinator_pick
  if ! printf '%s' "$frontmatter" | grep -qE "^coordinator_pick:"; then
    printf '[lib-decision] BLOCK: missing required field: coordinator_pick\n' >&2
    errors=$((errors + 1))
  fi

  # coordinator_confidence (or renamed field) — must be present AND be valid enum
  # Bind contract tripwire: if renamed away from canonical 'coordinator_confidence', fail.
  if [ -n "${DECISION_RENAME_COORD_CONF:-}" ] && [ "${DECISION_RENAME_COORD_CONF}" != "coordinator_confidence" ]; then
    printf '[lib-decision] BLOCK: bind-contract violation: coordinator_confidence field renamed to %s — schema bind requires "coordinator_confidence"\n' "${DECISION_RENAME_COORD_CONF}" >&2
    errors=$((errors + 1))
  elif ! printf '%s' "$frontmatter" | grep -qE "^${conf_field}:"; then
    printf '[lib-decision] BLOCK: missing required field: %s\n' "$conf_field" >&2
    errors=$((errors + 1))
  else
    local conf_val
    conf_val="$(printf '%s' "$frontmatter" | grep -E "^${conf_field}:" | head -1 | sed "s/^${conf_field}: *//")"
    case "$conf_val" in
      low|medium|medium-high|high)
        # valid
        ;;
      *)
        printf '[lib-decision] BLOCK: invalid %s value: %s (must be one of: low, medium, medium-high, high)\n' "$conf_field" "$conf_val" >&2
        errors=$((errors + 1))
        ;;
    esac
  fi

  # duong_pick
  if ! printf '%s' "$frontmatter" | grep -qE "^duong_pick:"; then
    printf '[lib-decision] BLOCK: missing required field: duong_pick\n' >&2
    errors=$((errors + 1))
  fi

  # match (or renamed field) — must be present
  # Bind contract tripwire: if renamed away from canonical 'match', fail.
  if [ -n "${DECISION_RENAME_MATCH:-}" ] && [ "${DECISION_RENAME_MATCH}" != "match" ]; then
    printf '[lib-decision] BLOCK: bind-contract violation: match field renamed to %s — schema bind requires "match"\n' "${DECISION_RENAME_MATCH}" >&2
    errors=$((errors + 1))
  elif ! printf '%s' "$frontmatter" | grep -qE "^${match_field}:"; then
    printf '[lib-decision] BLOCK: missing required field: %s\n' "$match_field" >&2
    errors=$((errors + 1))
  fi

  # Mutually exclusive flags: duong_concurred_silently and coordinator_autodecided
  local concurred autodecided
  concurred="$(printf '%s' "$frontmatter" | grep -E "^duong_concurred_silently:" | head -1 | sed 's/^duong_concurred_silently: *//')"
  autodecided="$(printf '%s' "$frontmatter" | grep -E "^coordinator_autodecided:" | head -1 | sed 's/^coordinator_autodecided: *//')"
  if [ "$concurred" = "true" ] && [ "$autodecided" = "true" ]; then
    printf '[lib-decision] BLOCK: duong_concurred_silently and coordinator_autodecided are mutually exclusive — both are true\n' >&2
    errors=$((errors + 1))
  fi

  # decision_id must match filename stem — only enforce when the filename looks like
  # a date-prefixed decision file (YYYY-MM-DD-<slug>.md pattern). Temp files created
  # by validators (e.g. valid.md, bad-conf.md) are exempt from this check.
  # Bind contract tripwire: if DECISION_RENAME_DECISION_ID is set to non-canonical name, fail.
  if [ -n "${DECISION_RENAME_DECISION_ID:-}" ] && [ "${DECISION_RENAME_DECISION_ID}" != "decision_id" ]; then
    printf '[lib-decision] BLOCK: bind-contract violation: decision_id field renamed to %s — schema bind requires "decision_id"\n' "${DECISION_RENAME_DECISION_ID}" >&2
    errors=$((errors + 1))
  elif [ "$id_field" = "decision_id" ] && printf '%s' "$frontmatter" | grep -qE "^decision_id:"; then
    local stem id_val
    stem="$(basename "$file" .md)"
    id_val="$(printf '%s' "$frontmatter" | grep -E "^decision_id:" | head -1 | sed 's/^decision_id: *//')"
    # Path-traversal guard (I2): decision_id must match ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]+$
    # Coordinators use mktemp so the date-prefix gate is skipped on real calls; validate
    # the id value unconditionally instead. Rejects '/', '..', spaces, and other unsafe chars.
    if ! printf '%s' "$id_val" | grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]+$"; then
      printf '[lib-decision] BLOCK: decision_id (%s) is not a valid slug — must match YYYY-MM-DD-[a-z0-9-]+\n' "$id_val" >&2
      errors=$((errors + 1))
    else
      # Only enforce filename-stem match when stem looks like a date-prefixed decision
      if printf '%s' "$stem" | grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2}-"; then
        if [ "$id_val" != "$stem" ]; then
          printf '[lib-decision] BLOCK: decision_id (%s) does not match filename stem (%s)\n' "$id_val" "$stem" >&2
          errors=$((errors + 1))
        fi
      fi
    fi
  fi

  if [ "$errors" -gt 0 ]; then
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# compute_match <coord_pick> <duong_pick> <duong_concurred_silently>
#
# Outputs: true, false, or hands-off
# - "hands-off" when duong_pick is hands-off-autodecide (coordinator_autodecided)
# - "true" when picks match OR duong_concurred_silently is true
# - "false" otherwise
# ---------------------------------------------------------------------------
compute_match() {
  local coord_pick="$1"
  local duong_pick="$2"
  local concurred_silently="$3"

  if [ "$duong_pick" = "hands-off-autodecide" ]; then
    printf 'hands-off'
    return 0
  fi

  if [ "$concurred_silently" = "true" ]; then
    printf 'true'
    return 0
  fi

  if [ "$coord_pick" = "$duong_pick" ]; then
    printf 'true'
  else
    printf 'false'
  fi
}

# ---------------------------------------------------------------------------
# infer_slug <question> <log_dir>
#
# Lowercases, replaces whitespace with -, strips punctuation,
# truncates to 40 chars. Handles collision by appending -2, -3 ... -10.
# Outputs the slug string (without date prefix).
# ---------------------------------------------------------------------------
infer_slug() {
  local question="$1"
  local log_dir="$2"
  local date_prefix="${3:-}"

  # Normalise: lowercase, replace non-alphanumeric-non-space with nothing,
  # replace spaces/whitespace with hyphens, collapse multiple hyphens
  local slug
  slug="$(printf '%s' "$question" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9 ]/ /g' \
    | sed 's/  */ /g' \
    | sed 's/^ //;s/ $//' \
    | sed 's/ /-/g')"

  # Truncate to 40 chars
  slug="${slug:0:40}"
  # Remove trailing hyphens after truncation
  slug="${slug%-}"

  # Collision detection: check if log_dir has a file containing this slug
  local base_slug="$slug"
  local candidate="$slug"
  local n=2

  # If date_prefix given, check files matching <date_prefix>-<slug>.md
  # Otherwise check any file whose stem contains the slug
  while true; do
    local found=0
    if [ -d "$log_dir" ]; then
      if [ -n "$date_prefix" ]; then
        if [ -f "${log_dir}/${date_prefix}-${candidate}.md" ]; then
          found=1
        fi
      else
        # Check any file matching *-<candidate>.md (date prefix unknown)
        for existing in "${log_dir}"/*-"${candidate}".md "${log_dir}/${candidate}.md"; do
          if [ -f "$existing" ]; then
            found=1
            break
          fi
        done
      fi
    fi

    if [ "$found" -eq 0 ]; then
      break
    fi

    candidate="${base_slug}-${n}"
    n=$((n + 1))
    if [ "$n" -gt 10 ]; then
      # Exhausted suffix space; fail loud at lib level so caller can handle cleanly.
      # capture-decision.sh already has its own collision guard — this ensures the
      # lib-level contract is explicit rather than silently falling through.
      printf '[lib-decision] BLOCK: infer_slug collision exhausted for slug "%s" (tried -2 through -10)\n' \
        "$base_slug" >&2
      return 1
    fi
  done

  printf '%s' "$candidate"
}

# ---------------------------------------------------------------------------
# _extract_frontmatter_field <frontmatter_string> <field_name>
#
# Internal helper: extract a single field value from raw frontmatter text.
# ---------------------------------------------------------------------------
_extract_frontmatter_field() {
  local frontmatter="$1"
  local field="$2"
  printf '%s' "$frontmatter" | grep -E "^${field}:" | head -1 | sed "s/^${field}: *//"
}

# ---------------------------------------------------------------------------
# _read_frontmatter <file>
#
# Internal helper: read frontmatter block from file, outputs lines.
# ---------------------------------------------------------------------------
_read_frontmatter() {
  local file="$1"
  local in_frontmatter=0
  while IFS= read -r line; do
    if [ "$in_frontmatter" -eq 0 ] && [ "$line" = "---" ]; then
      in_frontmatter=1
      continue
    fi
    if [ "$in_frontmatter" -eq 1 ] && [ "$line" = "---" ]; then
      break
    fi
    if [ "$in_frontmatter" -eq 1 ]; then
      printf '%s\n' "$line"
    fi
  done < "$file"
}

# ---------------------------------------------------------------------------
# render_index_row <decision_file>
#
# Outputs one markdown table row per §3.3 schema.
# Format: | Date | Slug | Axes | Coord | Duong | Match | Confidence |
# ---------------------------------------------------------------------------
render_index_row() {
  local file="$1"
  local fm
  fm="$(_read_frontmatter "$file")"

  local date slug axes coord_pick duong_pick match conf
  date="$(_extract_frontmatter_field "$fm" "date")"
  slug="$(_extract_frontmatter_field "$fm" "decision_id")"
  axes="$(_extract_frontmatter_field "$fm" "axes" | sed 's/^\[//;s/\]$//')"
  coord_pick="$(_extract_frontmatter_field "$fm" "coordinator_pick")"
  duong_pick="$(_extract_frontmatter_field "$fm" "duong_pick")"
  match="$(_extract_frontmatter_field "$fm" "match")"
  conf="$(_extract_frontmatter_field "$fm" "coordinator_confidence")"

  # Remove date prefix from slug for display (decision_id contains full id)
  local display_slug
  display_slug="${slug#${date}-}"

  printf '| %s | %s | %s | %s | %s | %s | %s |\n' \
    "$date" "$display_slug" "$axes" "$coord_pick" "$duong_pick" "$match" "$conf"
}

# ---------------------------------------------------------------------------
# _read_axes_from_file <axes_md_file>
#
# Reads axes.md and extracts axis names. Outputs one axis per line.
# Format: lines like "## axis-name" (may include "## axis-name (deprecated)")
# Also outputs "deprecated:<date>" lines for axes with deprecated: YYYY-MM-DD
# ---------------------------------------------------------------------------
_read_axes_from_file() {
  local axes_file="$1"
  if [ ! -f "$axes_file" ]; then
    return 0
  fi

  local current_axis=""
  local deprecated_date=""
  while IFS= read -r line; do
    # Match axis header: ## axis-name (starts with "## " followed by a lowercase letter)
    # Use bash case for POSIX-portable matching without spawning subshells
    case "$line" in
      "## "[a-z]*)
        if [ -n "$current_axis" ]; then
          if [ -n "$deprecated_date" ]; then
            printf 'deprecated:%s:%s\n' "$deprecated_date" "$current_axis"
          else
            printf '%s\n' "$current_axis"
          fi
        fi
        # Extract axis name: strip "## " prefix, then strip " (deprecated)" suffix
        current_axis="${line#\#\# }"
        case "$current_axis" in
          *" (deprecated)") current_axis="${current_axis% (deprecated)}" ;;
        esac
        deprecated_date=""
        ;;
      "  deprecated: "[0-9]*)
        # Extract deprecation date: strip "  deprecated: " prefix
        deprecated_date="${line#  deprecated: }"
        ;;
    esac
  done < "$axes_file"

  # Output last axis
  if [ -n "$current_axis" ]; then
    if [ -n "$deprecated_date" ]; then
      printf 'deprecated:%s:%s\n' "$deprecated_date" "$current_axis"
    else
      printf '%s\n' "$current_axis"
    fi
  fi
}

# ---------------------------------------------------------------------------
# _parse_frontmatter_fast <file>
#
# Pure-bash frontmatter parser. Sets caller-local variables:
#   _fm_date, _fm_decision_id, _fm_axes, _fm_coordinator_pick,
#   _fm_duong_pick, _fm_match, _fm_coordinator_confidence
# No subshells spawned — reads the file once with a while-read loop.
# ---------------------------------------------------------------------------
_parse_frontmatter_fast() {
  local _pff_file="$1"
  _fm_date=""
  _fm_decision_id=""
  _fm_axes=""
  _fm_coordinator_pick=""
  _fm_duong_pick=""
  _fm_match=""
  _fm_coordinator_confidence=""

  local _pff_in_fm=0
  while IFS= read -r _pff_line; do
    if [ "$_pff_in_fm" -eq 0 ] && [ "$_pff_line" = "---" ]; then
      _pff_in_fm=1
      continue
    fi
    if [ "$_pff_in_fm" -eq 1 ] && [ "$_pff_line" = "---" ]; then
      break
    fi
    if [ "$_pff_in_fm" -eq 1 ]; then
      case "$_pff_line" in
        date:\ *)       _fm_date="${_pff_line#date: }" ;;
        decision_id:\ *) _fm_decision_id="${_pff_line#decision_id: }" ;;
        axes:\ *)       _fm_axes="${_pff_line#axes: }" ;;
        coordinator_pick:\ *) _fm_coordinator_pick="${_pff_line#coordinator_pick: }" ;;
        duong_pick:\ *) _fm_duong_pick="${_pff_line#duong_pick: }" ;;
        match:\ *)      _fm_match="${_pff_line#match: }" ;;
        coordinator_confidence:\ *) _fm_coordinator_confidence="${_pff_line#coordinator_confidence: }" ;;
      esac
    fi
  done < "$_pff_file"
}

# ---------------------------------------------------------------------------
# _str_gt <a> <b>
#
# Returns 0 (true) if string a > b lexicographically, 1 otherwise.
# ISO dates (YYYY-MM-DD) compare correctly with lexicographic order.
# Uses pure bash — no subshells.
# ---------------------------------------------------------------------------
_str_gt() {
  # In bash, [ "$a" \> "$b" ] IS a string comparison (test builtin extension).
  # This is available in bash 3.2+ on macOS and all modern Linux.
  [ "$1" \> "$2" ]
}

# ---------------------------------------------------------------------------
# regenerate_decisions_index <coordinator_dir> <output_file>
#
# Walk coordinator_dir/decisions/log/*.md, sort newest-first by filename (date),
# validate axis declarations, emit INDEX.md.
#
# coordinator_dir: path to coordinator memory root (e.g. /tmp/test/decisions or
#                  the dir that contains decisions/)
# The function resolves decisions/log/ and decisions/axes.md from coordinator_dir.
# ---------------------------------------------------------------------------
regenerate_decisions_index() {
  local coordinator_dir="$1"
  local output_file="$2"

  # Resolve paths — coordinator_dir may be the parent of decisions/ or the
  # direct coordinator memory root.
  local log_dir axes_file
  if [ -d "${coordinator_dir}/decisions/log" ]; then
    log_dir="${coordinator_dir}/decisions/log"
    axes_file="${coordinator_dir}/decisions/axes.md"
  elif [ -d "${coordinator_dir}/log" ]; then
    log_dir="${coordinator_dir}/log"
    axes_file="${coordinator_dir}/axes.md"
  else
    printf '[lib-decision] BLOCK: decisions/log/ not found under %s\n' "$coordinator_dir" >&2
    return 1
  fi

  # Read known axes into a temp file — avoids subshell capture overhead on macOS
  # (fork() is slow; writing directly to a file from the current shell is fast)
  local known_axes_tmp="${TMPDIR:-/tmp}/decisions_axes_$$"
  _read_axes_from_file "$axes_file" > "$known_axes_tmp"

  # Collect and sort log files newest-first by filename (date prefix YYYY-MM-DD)
  # Use ${f##*/} instead of $(basename "$f") — no subshell
  local log_files_tmp="${TMPDIR:-/tmp}/decisions_files_$$"
  > "$log_files_tmp"
  for f in "${log_dir}"/*.md; do
    [ -e "$f" ] || continue
    case "${f##*/}" in .gitkeep) continue ;; esac
    printf '%s\n' "$f" >> "$log_files_tmp"
  done
  sort -r "$log_files_tmp" > "${log_files_tmp}.sorted"

  # Validate axes on all files before writing any output.
  # Uses pure-bash inner loop — no subshells per file/axis.
  local errors=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue

    # Parse frontmatter inline — no subshell
    _parse_frontmatter_fast "$f"
    local file_date="$_fm_date"

    # Strip YAML list brackets: [scope-vs-debt, explicit-vs-implicit] -> scope-vs-debt, explicit-vs-implicit
    local axes_val="${_fm_axes#\[}"
    axes_val="${axes_val%\]}"

    # Parse axes list (comma-separated) — no subshells
    local old_IFS="$IFS"
    IFS=','
    # shellcheck disable=SC2086
    set -- $axes_val
    IFS="$old_IFS"
    local axis_item
    for axis_item in "$@"; do
      # Trim leading/trailing spaces using parameter expansion (no sed/printf subshell)
      local axis="${axis_item# }"
      axis="${axis% }"
      [ -z "$axis" ] && continue

      # Check if axis is known — pure-bash case/while loop, no subshells
      local found_axis=0
      local is_deprecated=0
      local deprecated_on=""
      while IFS= read -r known_line; do
        [ -z "$known_line" ] && continue
        case "$known_line" in
          deprecated:*)
            # Format: deprecated:YYYY-MM-DD:axis-name
            # Extract using parameter expansion — no cut/printf subshells
            local _rest="${known_line#deprecated:}"
            local dep_date="${_rest%%:*}"
            local dep_axis="${_rest#*:}"
            if [ "$dep_axis" = "$axis" ]; then
              found_axis=1
              is_deprecated=1
              deprecated_on="$dep_date"
              break
            fi
            ;;
          *)
            if [ "$known_line" = "$axis" ]; then
              found_axis=1
              break
            fi
            ;;
        esac
      done < "$known_axes_tmp"

      if [ "$found_axis" -eq 0 ]; then
        printf '[lib-decision] BLOCK: undeclared axis "%s" in file %s — add to axes.md before using\n' \
          "$axis" "${f##*/}" >&2
        errors=$((errors + 1))
      elif [ "$is_deprecated" -eq 1 ] && [ -n "$file_date" ] && [ -n "$deprecated_on" ]; then
        # ISO dates compare correctly with lexicographic string comparison
        if _str_gt "$file_date" "$deprecated_on"; then
          printf '[lib-decision] BLOCK: axis "%s" was deprecated on %s; file dated %s must not use it\n' \
            "$axis" "$deprecated_on" "$file_date" >&2
          errors=$((errors + 1))
        fi
      fi
    done
  done < "${log_files_tmp}.sorted"

  if [ "$errors" -gt 0 ]; then
    rm -f "$known_axes_tmp" "$log_files_tmp" "${log_files_tmp}.sorted"
    return 1
  fi

  # Build INDEX.md — inline render to avoid per-file subshell for render_index_row
  local header
  header="| Date | Slug | Axes | Coord | Duong | Match | Confidence |
|------|------|------|-------|-------|-------|------------|"

  {
    printf '%s\n' "$header"
    while IFS= read -r f; do
      [ -z "$f" ] && continue

      # Parse frontmatter inline — no subshell per file
      _parse_frontmatter_fast "$f"

      # Strip brackets from axes for display
      local display_axes="${_fm_axes#\[}"
      display_axes="${display_axes%\]}"

      # Strip date prefix from decision_id for display slug
      local display_slug="${_fm_decision_id#${_fm_date}-}"

      printf '| %s | %s | %s | %s | %s | %s | %s |\n' \
        "$_fm_date" "$display_slug" "$display_axes" "$_fm_coordinator_pick" \
        "$_fm_duong_pick" "$_fm_match" "$_fm_coordinator_confidence"
    done < "${log_files_tmp}.sorted"
  } > "$output_file"

  rm -f "$known_axes_tmp" "$log_files_tmp" "${log_files_tmp}.sorted"
  return 0
}

# ---------------------------------------------------------------------------
# rollup_preferences_counts <coordinator_dir> <preferences_md_file>
#
# In-place update of Samples: and Notable misses: lines in preferences.md.
# Preserves all Summary: prose verbatim.
# Idempotent: re-running produces byte-identical output.
#
# coordinator_dir: dir that contains decisions/ (or decisions/ itself)
# ---------------------------------------------------------------------------
rollup_preferences_counts() {
  local coordinator_dir="$1"
  local preferences_file="$2"

  # Resolve paths
  local log_dir axes_file
  if [ -d "${coordinator_dir}/decisions/log" ]; then
    log_dir="${coordinator_dir}/decisions/log"
    axes_file="${coordinator_dir}/decisions/axes.md"
  elif [ -d "${coordinator_dir}/log" ]; then
    log_dir="${coordinator_dir}/log"
    axes_file="${coordinator_dir}/axes.md"
  else
    printf '[lib-decision] BLOCK: decisions/log/ not found under %s\n' "$coordinator_dir" >&2
    return 1
  fi

  if [ ! -f "$preferences_file" ]; then
    printf '[lib-decision] BLOCK: preferences.md not found: %s\n' "$preferences_file" >&2
    return 1
  fi

  # Collect all log files — no $(basename) subshells
  local log_files=""
  for f in "${log_dir}"/*.md; do
    [ -e "$f" ] || continue
    case "${f##*/}" in .gitkeep) continue ;; esac
    log_files="${log_files}${f}
"
  done

  # For each axis: count (a, b, c), match_count, total_explicit, misses, handsoff_count
  # One python3 invocation does BOTH aggregation AND in-place preferences.md rewriting
  # to avoid the 1s+ startup cost of two separate python3 calls.
  python3 - "$log_dir" "$axes_file" "$log_files" "$preferences_file" <<'PYEOF'
import sys
import os
import re

log_dir = sys.argv[1]
axes_file = sys.argv[2]
log_files_str = sys.argv[3]
pref_file = sys.argv[4]

log_files = [f.strip() for f in log_files_str.strip().split('\n') if f.strip()]

# Parse axes from axes_file
# Format: ## axis-name\n  deprecated: YYYY-MM-DD (optional)
axes_info = {}  # axis_name -> {'deprecated': date_str or None}
# Preserve insertion order for deterministic output
axes_order = []
if os.path.isfile(axes_file):
    current_axis = None
    dep_date = None
    with open(axes_file, 'r') as f:
        for line in f:
            line = line.rstrip('\n')
            m = re.match(r'^## ([a-z].+?)(?:\s+\(deprecated\))?$', line)
            if m:
                if current_axis is not None:
                    axes_info[current_axis] = {'deprecated': dep_date}
                current_axis = m.group(1).strip()
                axes_order.append(current_axis)
                dep_date = None
            elif current_axis and re.match(r'^\s+deprecated:\s+(\d{4}-\d{2}-\d{2})', line):
                dep_m = re.match(r'^\s+deprecated:\s+(\d{4}-\d{2}-\d{2})', line)
                dep_date = dep_m.group(1)
    if current_axis is not None:
        axes_info[current_axis] = {'deprecated': dep_date}

# Per-axis accumulators
stats = {}
for axis in axes_info:
    stats[axis] = {
        'counts': {'a': 0, 'b': 0, 'c': 0, 'other': 0},
        'match_count': 0,
        'total_explicit': 0,
        'handsoff_count': 0,
        'misses': []  # list of (date, decision_id) for non-matching explicit picks
    }

def extract_fm_field(lines, field):
    for line in lines:
        if line.startswith(field + ':'):
            return line[len(field)+1:].strip()
    return ''

def extract_axes_list(axes_str):
    # axes_str is like "[scope-vs-debt, explicit-vs-implicit]"
    s = axes_str.strip()
    if s.startswith('[') and s.endswith(']'):
        s = s[1:-1]
    items = [x.strip() for x in s.split(',') if x.strip()]
    return items

# Sort files by filename for deterministic order (newest-first by name)
log_files_sorted = sorted(log_files, key=lambda f: os.path.basename(f), reverse=True)

for fpath in log_files_sorted:
    if not os.path.isfile(fpath):
        continue
    with open(fpath, 'r') as f:
        content = f.read()

    # Extract frontmatter
    lines = content.split('\n')
    fm_lines = []
    in_fm = False
    for line in lines:
        if not in_fm and line == '---':
            in_fm = True
            continue
        if in_fm and line == '---':
            break
        if in_fm:
            fm_lines.append(line)

    date = extract_fm_field(fm_lines, 'date')
    decision_id = extract_fm_field(fm_lines, 'decision_id')
    axes_str = extract_fm_field(fm_lines, 'axes')
    duong_pick = extract_fm_field(fm_lines, 'duong_pick')
    coordinator_pick = extract_fm_field(fm_lines, 'coordinator_pick')
    match_str = extract_fm_field(fm_lines, 'match')
    concurred = extract_fm_field(fm_lines, 'duong_concurred_silently')
    autodecided = extract_fm_field(fm_lines, 'coordinator_autodecided')

    file_axes = extract_axes_list(axes_str)
    is_handsoff = (autodecided == 'true') or (duong_pick == 'hands-off-autodecide')

    for axis in file_axes:
        if axis not in stats:
            continue  # skip unknown axes silently (already gated by regenerate_decisions_index)

        # Check deprecation: if axis is deprecated AND file date > deprecated_on, skip
        dep_date = axes_info[axis].get('deprecated')
        if dep_date and date > dep_date:
            continue  # new decision after deprecation — skip for rollup

        if is_handsoff:
            stats[axis]['handsoff_count'] += 1
        else:
            stats[axis]['total_explicit'] += 1
            # Count pick
            pick = duong_pick
            if pick in ('a', 'b', 'c'):
                stats[axis]['counts'][pick] += 1
            else:
                stats[axis]['counts']['other'] += 1

            # Match
            is_match = (match_str == 'true') or (concurred == 'true')
            if is_match:
                stats[axis]['match_count'] += 1
            else:
                # Record miss (date + decision_id for display)
                stats[axis]['misses'].append((date, decision_id))

# Build per-axis lookup for preferences.md rewriting
# axis_name -> {samples_str, match_str, conf_str, misses_str}
axis_lookup = {}
for axis, s in stats.items():
    total = s['total_explicit']
    a_count = s['counts']['a']
    b_count = s['counts']['b']
    c_count = s['counts']['c']
    handsoff = s['handsoff_count']

    # Match rate = coordinator-vs-Duong agreement rate (match_count / total_explicit)
    # Per plan §4.3 + §6: match_rate = sum(match) / count.
    # Do NOT use count_a/total — that measures Duong's preference for option 'a',
    # not prediction accuracy. match_count is accumulated at line 797.
    match_count = s['match_count']
    match_rate = int(round(match_count * 100.0 / total)) if total > 0 else 0

    if total < 5:
        confidence = 'low'
    elif total < 15:
        confidence = 'medium'
    elif total < 40:
        confidence = 'medium-high'
    else:
        confidence = 'high'

    if handsoff > 0:
        samples_str = f'Samples: {total} (a: {a_count}, b: {b_count}, c: {c_count}; +{handsoff} hands-off)'
    else:
        samples_str = f'Samples: {total} (a: {a_count}, b: {b_count}, c: {c_count})'

    match_str_out = f'Match rate: {match_rate}%'
    conf_str = f'Confidence: {confidence}'

    misses_sorted = sorted(s['misses'], key=lambda x: (x[0], x[1]), reverse=True)[:3]
    if misses_sorted:
        misses_str = ', '.join(m[1] for m in misses_sorted)
    else:
        misses_str = 'none yet.'

    axis_lookup[axis] = {
        'samples': samples_str,
        'match': match_str_out,
        'conf': conf_str,
        'misses': misses_str,
    }

# Rewrite preferences.md in-place
if os.path.isfile(pref_file):
    with open(pref_file, 'r') as f:
        lines = f.readlines()

    out_lines = []
    current_axis = None
    i = 0
    while i < len(lines):
        line = lines[i]

        # Detect axis section headers: ## Axis: axis-name
        # Trailing whitespace is tolerated (\s*$ instead of $) — editors sometimes
        # leave trailing spaces on header lines.
        m = re.match(r'^## Axis: (.+?)(?:\s+\(deprecated\))?\s*$', line.rstrip('\n'))
        if m:
            current_axis = m.group(1).strip()
            out_lines.append(line)
            i += 1
            continue

        # Replace Samples: line (inline with Match rate and Confidence)
        if current_axis and line.lstrip().startswith('Samples:'):
            indent = len(line) - len(line.lstrip())
            leading = ' ' * indent
            if current_axis in axis_lookup:
                d = axis_lookup[current_axis]
                out_lines.append(f'{leading}{d["samples"]} · {d["match"]} · {d["conf"]}\n')
            else:
                out_lines.append(line)
            i += 1
            continue

        # Replace Notable misses: line
        if current_axis and line.lstrip().startswith('Notable misses:'):
            indent = len(line) - len(line.lstrip())
            leading = ' ' * indent
            if current_axis in axis_lookup:
                out_lines.append(f'{leading}Notable misses: {axis_lookup[current_axis]["misses"]}\n')
            else:
                out_lines.append(line)
            i += 1
            continue

        out_lines.append(line)
        i += 1

    with open(pref_file, 'w') as f:
        f.writelines(out_lines)

PYEOF

  return 0
}
