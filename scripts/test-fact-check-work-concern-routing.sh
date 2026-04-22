#!/usr/bin/env bash
# Regression test — fact-check-plan.sh work-concern routing
#
# Plan: 2026-04-21-orianna-work-repo-routing
#
# Invariants covered:
#   I1 — concern: work routes apps/* to $WORK_CONCERN_REPO (not $STRAWBERRY_APP)
#   I2 — concern: personal (and no concern field) keeps apps/* → $STRAWBERRY_APP (backward compat)
#   I3 — missing work-concern checkout emits warn naming the work-concern repo path
#
# Run: bash scripts/test-fact-check-work-concern-routing.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FACT_CHECK="$SCRIPT_DIR/fact-check-plan.sh"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

[ -f "$FACT_CHECK" ] || { printf 'SKIP  fact-check-plan.sh not found\n'; exit 0; }

SCRATCH="$(mktemp -d)"
REPORT_DIR="$REPO_ROOT/assessments/plan-fact-checks"
mkdir -p "$REPORT_DIR"

# Helper: write a plan with given body, run fact-check with given env overrides.
# Returns block count. Reports are cleaned up.
run_check() {
  local label="$1"
  local body="$2"
  shift 2
  local slug="wcrtest-${label}-$$"
  local plan_path="$SCRATCH/${slug}.md"
  trap "rm -rf \"$REPORT_DIR/${slug}-\"*.md \"$plan_path\"" EXIT INT TERM
  printf '%s\n' "$body" > "$plan_path"
  local rc=0
  env "$@" bash "$FACT_CHECK" "$plan_path" >/dev/null 2>&1 || rc=$?
  local report
  report="$(ls -t "$REPORT_DIR/${slug}-"*.md 2>/dev/null | head -1)"
  local blocks=0
  if [ -f "$report" ]; then
    blocks="$(awk '/^block_findings:/{print $2}' "$report" || echo 0)"
    rm -f "$report"
  fi
  rm -f "$plan_path"
  trap - EXIT INT TERM
  printf '%s' "$blocks"
}

# Helper: like run_check but returns the warn text for I3.
run_check_warn() {
  local label="$1"
  local body="$2"
  shift 2
  local slug="wcrtest-${label}-$$"
  local plan_path="$SCRATCH/${slug}.md"
  trap "rm -rf \"$REPORT_DIR/${slug}-\"*.md \"$plan_path\"" EXIT INT TERM
  printf '%s\n' "$body" > "$plan_path"
  env "$@" bash "$FACT_CHECK" "$plan_path" >/dev/null 2>&1 || true
  local report
  report="$(ls -t "$REPORT_DIR/${slug}-"*.md 2>/dev/null | head -1)"
  local warn_text=""
  if [ -f "$report" ]; then
    warn_text="$(cat "$report")"
    rm -f "$report"
  fi
  rm -f "$plan_path"
  trap - EXIT INT TERM
  printf '%s' "$warn_text"
}

# A fake work-concern checkout and a fake strawberry-app — both have the token file.
FAKE_WORK="$(mktemp -d)"
FAKE_APP="$(mktemp -d)"
mkdir -p "$FAKE_WORK/apps/demo-studio/backend"
touch "$FAKE_WORK/apps/demo-studio/backend/session_store.py"
mkdir -p "$FAKE_APP/apps/demo-studio/backend"
touch "$FAKE_APP/apps/demo-studio/backend/session_store.py"

WORK_TOKEN="apps/demo-studio/backend/session_store.py"

# ---- I1: concern: work routes apps/* to WORK_CONCERN_REPO ------------------
# Plan with concern: work — token exists in FAKE_WORK, absent in FAKE_APP.
# We point WORK_CONCERN_REPO to a dir WITH the file and STRAWBERRY_APP to a dir WITHOUT it.
FAKE_APP_MISSING="$(mktemp -d)"  # does not have the token

I1_BODY="---
title: I1 Work Routing Test
status: proposed
owner: talon
created: 2026-04-21
concern: work
tags: [test]
---

Depends on \`${WORK_TOKEN}\` being present in the work repo.
"

blocks="$(run_check I1 "$I1_BODY" \
  "WORK_CONCERN_REPO=$FAKE_WORK" \
  "STRAWBERRY_APP=$FAKE_APP_MISSING")"
if [ "$blocks" -eq 0 ]; then
  pass "I1_WORK_CONCERN_ROUTES_TO_WORK_REPO"
else
  fail "I1_WORK_CONCERN_ROUTES_TO_WORK_REPO" "expected 0 blocks (file exists in work repo), got $blocks"
fi

# RESCOPE UPDATE (Viktor 2026-04-22, OQ-1 resolution a):
# Pre-rescope: concern:work path absent from WORK_CONCERN_REPO → block.
# Post-rescope: apps/* under concern:work is a non-internal-prefix C2b token
#   (opt-back list covers only agents/, plans/, scripts/, architecture/,
#   assessments/, .claude/, secrets/, tools/decrypt.sh, tools/encrypt.sh).
#   C2b tokens are info (no filesystem check) per v2 contract §6 / rescope OQ-1.
#   The check "apps/demo-studio/backend/session_store.py" under concern:work
#   → not on opt-back list → C2b → 0 blocks (info finding only).
#
# New assertion: 0 blocks (info) for absent work-concern non-opt-back path.
FAKE_WORK_MISSING="$(mktemp -d)"  # does not have the token
blocks="$(run_check I1_missing "$I1_BODY" \
  "WORK_CONCERN_REPO=$FAKE_WORK_MISSING" \
  "STRAWBERRY_APP=$FAKE_APP_MISSING")"
if [ "$blocks" -eq 0 ]; then
  pass "I1_WORK_CONCERN_MISSING_FILE_INFO_ONLY"
else
  fail "I1_WORK_CONCERN_MISSING_FILE_INFO_ONLY" "expected 0 blocks for absent work-concern C2b path (rescope OQ-1: non-internal-prefix → info), got $blocks"
fi

# ---- I2: concern: personal routes apps/* to STRAWBERRY_APP (backward compat) ---
I2_BODY="---
title: I2 Personal Routing Test
status: proposed
owner: talon
created: 2026-04-21
concern: personal
tags: [test]
---

Depends on \`${WORK_TOKEN}\` being present in the personal app repo.
"

# FAKE_APP has the file; FAKE_WORK_MISSING does not — work concern would block.
blocks="$(run_check I2 "$I2_BODY" \
  "WORK_CONCERN_REPO=$FAKE_WORK_MISSING" \
  "STRAWBERRY_APP=$FAKE_APP")"
if [ "$blocks" -eq 0 ]; then
  pass "I2_PERSONAL_CONCERN_ROUTES_TO_STRAWBERRY_APP"
else
  fail "I2_PERSONAL_CONCERN_ROUTES_TO_STRAWBERRY_APP" "expected 0 blocks (file exists in app), got $blocks"
fi

# Also check: no concern field at all still routes to strawberry-app.
I2_NO_CONCERN_BODY="---
title: I2 No Concern Test
status: proposed
owner: talon
created: 2026-04-21
tags: [test]
---

Depends on \`${WORK_TOKEN}\` being present.
"
blocks="$(run_check I2_noconcern "$I2_NO_CONCERN_BODY" \
  "WORK_CONCERN_REPO=$FAKE_WORK_MISSING" \
  "STRAWBERRY_APP=$FAKE_APP")"
if [ "$blocks" -eq 0 ]; then
  pass "I2_NO_CONCERN_FIELD_ROUTES_TO_STRAWBERRY_APP"
else
  fail "I2_NO_CONCERN_FIELD_ROUTES_TO_STRAWBERRY_APP" "expected 0 blocks (legacy plan routes to app), got $blocks"
fi

# ---- I3: missing work-concern checkout behavior (post-rescope) ----
# RESCOPE UPDATE (Viktor 2026-04-22, OQ-1 resolution a):
# Pre-rescope: if work-concern checkout is absent, a warn was emitted naming
#   the checkout path, because the path token was routed there for test -e.
# Post-rescope: non-opt-back work-concern tokens are C2b (info) — the filesystem
#   check is never attempted, so no "checkout absent" warn is emitted.
#   The test asserts the new invariant: 0 blocks when checkout absent and token
#   is C2b (plan exits clean, author is informed via info finding only).
#
# For OPT-BACK tokens (e.g. agents/sona/memory/sona.md), the checkout-absent
#   warn still applies for cross-repo personal refs (apps/, dashboards/).
#   This case is covered by SC4 in the concern-root-flip test.
FAKE_ABSENT="/tmp/strawberry-work-repo-NONEXISTENT-$$"
I3_BODY="---
title: I3 Missing Checkout Test
status: proposed
owner: talon
created: 2026-04-21
concern: work
tags: [test]
---

Depends on \`${WORK_TOKEN}\` being present.
"

blocks="$(run_check I3 "$I3_BODY" \
  "WORK_CONCERN_REPO=$FAKE_ABSENT" \
  "STRAWBERRY_APP=$FAKE_APP")"
if [ "$blocks" -eq 0 ]; then
  pass "I3_MISSING_WORK_CHECKOUT_C2B_CLEAN"
else
  fail "I3_MISSING_WORK_CHECKOUT_C2B_CLEAN" "expected 0 blocks (C2b token, no filesystem check attempted), got $blocks"
fi

# ---- I4: concern: "work" (YAML-quoted) still routes to WORK_CONCERN_REPO -----
# Locks the behavior: quoted values must not silently fall back to strawberry-app.
I4_BODY='---
title: I4 Quoted Work Routing Test
status: proposed
owner: talon
created: 2026-04-21
concern: "work"
tags: [test]
---

Depends on `'"${WORK_TOKEN}"'` being present in the work repo.
'

blocks="$(run_check I4_quoted "$I4_BODY" \
  "WORK_CONCERN_REPO=$FAKE_WORK" \
  "STRAWBERRY_APP=$FAKE_APP_MISSING")"
if [ "$blocks" -eq 0 ]; then
  pass "I4_QUOTED_CONCERN_WORK_ROUTES_TO_WORK_REPO"
else
  fail "I4_QUOTED_CONCERN_WORK_ROUTES_TO_WORK_REPO" "expected 0 blocks (quoted concern:work routes to work repo), got $blocks"
fi

# ---- I5: dashboards/* with concern: work routes to WORK_CONCERN_REPO ---------
FAKE_WORK_DASH="$(mktemp -d)"
mkdir -p "$FAKE_WORK_DASH/dashboards/analytics"
touch "$FAKE_WORK_DASH/dashboards/analytics/main.py"
DASH_TOKEN="dashboards/analytics/main.py"

I5_BODY="---
title: I5 Dashboards Work Routing Test
status: proposed
owner: talon
created: 2026-04-21
concern: work
tags: [test]
---

Depends on \`${DASH_TOKEN}\` being present in the work repo.
"

blocks="$(run_check I5_dashboards "$I5_BODY" \
  "WORK_CONCERN_REPO=$FAKE_WORK_DASH" \
  "STRAWBERRY_APP=$FAKE_APP_MISSING")"
if [ "$blocks" -eq 0 ]; then
  pass "I5_DASHBOARDS_CONCERN_WORK_ROUTES_TO_WORK_REPO"
else
  fail "I5_DASHBOARDS_CONCERN_WORK_ROUTES_TO_WORK_REPO" "expected 0 blocks (dashboards/* routes to work repo), got $blocks"
fi

# ---- I6: .github/workflows/* with concern: work routes to WORK_CONCERN_REPO --
FAKE_WORK_GH="$(mktemp -d)"
mkdir -p "$FAKE_WORK_GH/.github/workflows"
touch "$FAKE_WORK_GH/.github/workflows/deploy.yml"
GH_TOKEN=".github/workflows/deploy.yml"

I6_BODY="---
title: I6 GitHub Workflows Work Routing Test
status: proposed
owner: talon
created: 2026-04-21
concern: work
tags: [test]
---

Depends on \`${GH_TOKEN}\` being present in the work repo.
"

blocks="$(run_check I6_ghworkflows "$I6_BODY" \
  "WORK_CONCERN_REPO=$FAKE_WORK_GH" \
  "STRAWBERRY_APP=$FAKE_APP_MISSING")"
if [ "$blocks" -eq 0 ]; then
  pass "I6_GITHUB_WORKFLOWS_CONCERN_WORK_ROUTES_TO_WORK_REPO"
else
  fail "I6_GITHUB_WORKFLOWS_CONCERN_WORK_ROUTES_TO_WORK_REPO" "expected 0 blocks (.github/workflows/* routes to work repo), got $blocks"
fi

# Clean up fake dirs
rm -rf "$FAKE_WORK" "$FAKE_APP" "$FAKE_APP_MISSING" "$FAKE_WORK_MISSING"
rm -rf "$FAKE_WORK_DASH" "$FAKE_WORK_GH"
rm -rf "$SCRATCH"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
