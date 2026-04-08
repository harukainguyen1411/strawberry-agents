#!/usr/bin/env bash
# Offline tests for the plan-gdoc-mirror helpers that don't need network or
# credentials. Exercises:
#   - frontmatter get / set / unset
#   - wrap_frontmatter / unwrap_frontmatter round-trip
#
# Run: bash scripts/test_plan_gdoc_offline.sh
#
# Exits 0 on success, nonzero on first failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib_gdoc.sh
. "$SCRIPT_DIR/_lib_gdoc.sh"

PASS=0
FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS+1))
    printf '  ok  %s\n' "$label"
  else
    FAIL=$((FAIL+1))
    printf '  FAIL %s\n    expected: %q\n    actual:   %q\n' "$label" "$expected" "$actual"
  fi
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# --- frontmatter_get / set / unset ---
cat >"$WORK/a.md" <<'EOF'
---
title: hello
status: proposed
owner: swain
created: 2026-04-08
---

# Body

Some content.
EOF

assert_eq "frontmatter_get title" "hello" "$(gdoc::frontmatter_get "$WORK/a.md" title)"
assert_eq "frontmatter_get status" "proposed" "$(gdoc::frontmatter_get "$WORK/a.md" status)"
assert_eq "frontmatter_get missing" "" "$(gdoc::frontmatter_get "$WORK/a.md" gdoc_id)"

gdoc::frontmatter_set "$WORK/a.md" gdoc_id "abc123"
assert_eq "frontmatter_set new" "abc123" "$(gdoc::frontmatter_get "$WORK/a.md" gdoc_id)"

gdoc::frontmatter_set "$WORK/a.md" status "in-progress"
assert_eq "frontmatter_set existing" "in-progress" "$(gdoc::frontmatter_get "$WORK/a.md" status)"

gdoc::frontmatter_unset "$WORK/a.md" gdoc_id
assert_eq "frontmatter_unset" "" "$(gdoc::frontmatter_get "$WORK/a.md" gdoc_id)"

# Body must still be present.
assert_eq "body preserved" "Some content." "$(grep '^Some content' "$WORK/a.md")"

# --- wrap / unwrap round-trip ---
cat >"$WORK/b.md" <<'EOF'
---
title: round trip
status: proposed
gdoc_id: xyz
---

# Heading

- bullet
- bullet two
EOF

gdoc::wrap_frontmatter <"$WORK/b.md" >"$WORK/b.wrapped.md"
# wrapped form starts with the fenced sentinel
FIRST_LINE=$(head -1 "$WORK/b.wrapped.md")
assert_eq "wrap opens with fence" '```yaml plan-frontmatter' "$FIRST_LINE"

# Frontmatter delimiters should be replaced
DELIM_COUNT=$(grep -c '^---[[:space:]]*$' "$WORK/b.wrapped.md" || true)
assert_eq "wrap removed --- delimiters" "0" "$DELIM_COUNT"

gdoc::unwrap_frontmatter <"$WORK/b.wrapped.md" >"$WORK/b.unwrapped.md"

# Should be byte-identical to the original
if cmp -s "$WORK/b.md" "$WORK/b.unwrapped.md"; then
  PASS=$((PASS+1))
  printf '  ok  wrap/unwrap round trip is byte-identical\n'
else
  FAIL=$((FAIL+1))
  printf '  FAIL wrap/unwrap round trip differs\n'
  diff "$WORK/b.md" "$WORK/b.unwrapped.md" || true
fi

# --- doc_title_for ---
assert_eq "doc_title_for" "[strawberry] 2026-04-08-foo" "$(gdoc::doc_title_for plans/proposed/2026-04-08-foo.md)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
