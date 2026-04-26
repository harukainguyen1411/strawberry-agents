#!/usr/bin/env bash
# scripts/ci/pr-lint-frontend-markers.sh
#
# Lint a PR body for required Frontend / UI markers (Rule 22, D7).
#
# Plan: plans/approved/personal/2026-04-25-frontend-uiux-in-process.md T-E2
#
# Usage:
#   printf '%s' "$PR_BODY" | bash scripts/ci/pr-lint-frontend-markers.sh - "$CHANGED_FILES"
#   bash scripts/ci/pr-lint-frontend-markers.sh <body-file> "$CHANGED_FILES"
#
# Arguments:
#   $1  — PR body: path to a file containing the PR body, or "-" to read from stdin
#   $2  — space-separated list of changed file paths (used to classify UI vs non-UI
#          without touching $GITHUB_EVENT_PATH in local/unit-test mode)
#
# UI-scope heuristic (D1 path globs):
#   apps/**/src/**/*.{vue,tsx,jsx,ts,js,css,scss}
#   apps/**/components/**
#   apps/**/pages/**
#   apps/**/routes/**
#   (also: apps/**/*.vue, apps/**/*.tsx, apps/**/*.jsx, apps/**/*.css, apps/**/*.scss)
#
# Pass conditions:
#   1. No UI files in changed-file list → exempt, exit 0
#   2. UI PR with at least ONE non-empty marker from:
#        Design-Spec:          <non-empty value>
#        Accessibility-Check:  <non-empty value>
#        Visual-Diff:          <non-empty value>
#      OR a UX-Waiver: line (substitutes for Design-Spec: per D7 bypass)
#
# Fail conditions:
#   - UI PR with no markers at all → exit 1
#   - UI PR with only empty-value markers (e.g. "Design-Spec:" alone) → exit 1
#
# Exit codes:
#   0 — exempt (non-UI PR) OR markers satisfied
#   1 — UI PR missing required markers

set -uo pipefail

# ---------------------------------------------------------------------------
# 1. Read PR body — then strip HTML comment blocks before scanning.
#
# HTML comments (<!-- ... -->) must be removed before grepping for markers.
# Without this, template scaffold lines inside comments (e.g. the default
# pull_request_template.md which ships uncommented placeholder values inside
# an HTML comment block) would be matched, silently satisfying the gate for
# every PR that never edits the template.
#
# Strategy: use awk to delete everything between <!-- and --> (multiline-safe,
# POSIX awk, no GNU extensions needed).
# ---------------------------------------------------------------------------
rawfile="$(mktemp)"
tmpfile="$(mktemp)"
trap 'rm -f "$rawfile" "$tmpfile"' EXIT INT TERM HUP

if [ "${1:--}" = "-" ]; then
  cat > "$rawfile"
else
  if [ ! -f "$1" ]; then
    printf 'error: PR body file not found: %s\n' "$1" >&2
    exit 1
  fi
  cat "$1" > "$rawfile"
fi

# Strip <!-- ... --> blocks (multiline). awk accumulates lines inside a
# comment block and discards them; lines outside are passed through.
awk '
  /<!--/ { in_comment = 1 }
  !in_comment { print }
  /-->/ { in_comment = 0 }
' "$rawfile" > "$tmpfile"

# ---------------------------------------------------------------------------
# 2. Classify changed files — UI vs non-UI
#    $2 is space-separated; iterate word by word.
# ---------------------------------------------------------------------------
changed_files="${2:-}"

is_ui=0
for filepath in $changed_files; do
  case "$filepath" in
    # D1 primary globs — bash `case` `*` already matches `/`, so only the
    # deepest wildcard form is needed (no redundant `apps/*/src/*.vue` +
    # `apps/*/src/**/*.vue` pairs — `apps/*/src/*.vue` already matches any
    # depth under src/).  Added in v2: composables/, layouts/, stores/,
    # views/, app/ (Nuxt/Next routers and state layers).
    apps/*/src/*.vue|apps/*/src/*.tsx|apps/*/src/*.jsx|\
    apps/*/src/*.ts|apps/*/src/*.js|apps/*/src/*.css|apps/*/src/*.scss|\
    apps/*/components/*|\
    apps/*/composables/*|\
    apps/*/layouts/*|\
    apps/*/pages/*|\
    apps/*/routes/*|\
    apps/*/stores/*|\
    apps/*/views/*|\
    apps/*/app/*|\
    apps/**/*.vue|apps/**/*.tsx|apps/**/*.jsx|apps/**/*.css|apps/**/*.scss)
      is_ui=1
      break
      ;;
  esac
done

# ---------------------------------------------------------------------------
# 3. Non-UI PR — exempt
# ---------------------------------------------------------------------------
if [ "$is_ui" = "0" ]; then
  printf 'pr-frontend-markers: non-UI PR — exempt from frontend marker check.\n'
  exit 0
fi

# ---------------------------------------------------------------------------
# 4. UI PR — scan for markers
#
# Required markers (D7): at least ONE non-empty value from:
#   Design-Spec:          <value>
#   Accessibility-Check:  <value>
#   Visual-Diff:          <value>
# OR a UX-Waiver: line (any non-empty value) substitutes for Design-Spec:.
#
# Empty values ("Design-Spec:" with trailing whitespace only) are treated as absent.
# ---------------------------------------------------------------------------

# Helper: extract value after "Marker-Key:" on a line; print value stripped of
# leading/trailing whitespace; empty if not found or value is blank.
extract_marker() {
  local key="$1"
  local val
  # grep for the key at the start of a line (case-sensitive per D7 spec)
  val="$(grep -m1 "^${key}" "$tmpfile" 2>/dev/null | sed "s/^${key}//" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' || true)"
  printf '%s' "$val"
}

design_spec="$(extract_marker 'Design-Spec:')"
accessibility_check="$(extract_marker 'Accessibility-Check:')"
visual_diff="$(extract_marker 'Visual-Diff:')"
ux_waiver="$(extract_marker 'UX-Waiver:')"

has_marker=0

# UX-Waiver: substitutes for Design-Spec: (bypass case per D7)
[ -n "$ux_waiver" ] && has_marker=1

# Any of the three marker lines with a non-empty value
[ -n "$design_spec" ]        && has_marker=1
[ -n "$accessibility_check" ] && has_marker=1
[ -n "$visual_diff" ]         && has_marker=1

# ---------------------------------------------------------------------------
# 5. Verdict
# ---------------------------------------------------------------------------
if [ "$has_marker" = "1" ]; then
  printf 'pr-frontend-markers: UI PR — frontend markers satisfied.\n'
  exit 0
fi

printf '\n' >&2
printf 'pr-frontend-markers: FAIL — UI PR is missing required frontend markers.\n' >&2
printf '\n' >&2
printf 'This PR touches UI file paths and must include at least ONE of:\n' >&2
printf '  Design-Spec:         <plan-path-or-figma-link>\n' >&2
printf '  Accessibility-Check: pass | deferred-<reason>\n' >&2
printf '  Visual-Diff:         <Akali-report-path-or-link> | n/a-no-visual-change | waived-<reason>\n' >&2
printf '\n' >&2
printf 'Or a UX-Waiver: line (substitutes for Design-Spec: for refactors / parent-plan\n' >&2
printf 'approved specs / explicit Duong waiver — see D7 in the plan).\n' >&2
printf '\n' >&2
printf 'See plans/approved/personal/2026-04-25-frontend-uiux-in-process.md D7.\n' >&2
exit 1
