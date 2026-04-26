#!/usr/bin/env bash
# tests/invariants/plan-template-uxspec.sh
#
# xfail: T-B1 — plan-template §UX Spec scaffolding
# Plan: plans/approved/personal/2026-04-25-frontend-uiux-in-process.md T-B1
#
# Asserts the canonical plan template at architecture/agent-network-v1/taxonomy.md
# (plan-template section) contains:
#   1. The literal section header "## UX Spec"
#   2. The six required subsection stubs from D1 (User flow, Component states,
#      Responsive behavior, Accessibility, Figma link, Out of scope)
#   3. A path-glob comment block referencing the D1 UI path-glob
#      (apps/**/src/** or apps/**/components/** or apps/**/pages/** etc.)
#
# Currently FAILS because T-B2 (the implementation) has not landed yet.
# Tagged xfail-for: plans/approved/personal/2026-04-25-frontend-uiux-in-process.md T-B2
#
# Run: bash tests/invariants/plan-template-uxspec.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

TEMPLATE="$REPO_ROOT/architecture/agent-network-v1/taxonomy.md"

pass=0
fail=0

_pass() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
_fail() { printf 'FAIL: %s\n' "$1" >&2; fail=$((fail + 1)); }

# ---------------------------------------------------------------------------
# XFAIL guard — implementation (T-B2) not yet present
# ---------------------------------------------------------------------------

MISSING=""

if [ ! -f "$TEMPLATE" ]; then
  MISSING="$MISSING architecture/agent-network-v1/taxonomy.md"
elif ! grep -q '^## UX Spec' "$TEMPLATE" 2>/dev/null; then
  MISSING="$MISSING taxonomy.md:##UX-Spec-header"
fi

if [ -n "$MISSING" ]; then
  printf 'XFAIL (expected — missing:%s)\n' "$MISSING"
  for c in \
    TB1_UXSPEC_HEADER_PRESENT \
    TB1_SUBSECTION_USER_FLOW \
    TB1_SUBSECTION_COMPONENT_STATES \
    TB1_SUBSECTION_RESPONSIVE_BEHAVIOR \
    TB1_SUBSECTION_ACCESSIBILITY \
    TB1_SUBSECTION_FIGMA_LINK \
    TB1_SUBSECTION_OUT_OF_SCOPE \
    TB1_D1_PATHGLOB_COMMENT
  do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 8 xfail (expected — T-B2 template update not yet implemented)\n'
  exit 0
fi

# ---------------------------------------------------------------------------
# Live assertions — only reached after T-B2 lands
# ---------------------------------------------------------------------------

# 1. "## UX Spec" header is present in the template
if grep -q '^## UX Spec' "$TEMPLATE"; then
  _pass "TB1_UXSPEC_HEADER_PRESENT"
else
  _fail "TB1_UXSPEC_HEADER_PRESENT — '## UX Spec' header missing in $TEMPLATE"
fi

# 2–7. Required subsection stubs (D1 list)
for subsection in \
  "User flow" \
  "Component states" \
  "Responsive behavior" \
  "Accessibility" \
  "Figma link" \
  "Out of scope"
do
  slug="$(printf '%s' "$subsection" | tr ' ' '_' | tr '[:lower:]' '[:upper:]')"
  label="TB1_SUBSECTION_${slug}"
  if grep -qi "$subsection" "$TEMPLATE"; then
    _pass "$label"
  else
    _fail "$label — subsection '$subsection' missing under ## UX Spec in $TEMPLATE"
  fi
done

# 8. Path-glob comment block referencing D1 UI paths
# Must mention at least apps/**/src or apps/**/components or apps/**/pages
if grep -qE 'apps/\*\*/src|apps/\*\*/components|apps/\*\*/pages|apps/\*\*/routes' "$TEMPLATE"; then
  _pass "TB1_D1_PATHGLOB_COMMENT"
else
  _fail "TB1_D1_PATHGLOB_COMMENT — D1 path-glob comment (apps/**/src/**, apps/**/components/**, etc.) missing in $TEMPLATE"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf '\nResults: %d passed, %d failed\n' "$pass" "$fail"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
