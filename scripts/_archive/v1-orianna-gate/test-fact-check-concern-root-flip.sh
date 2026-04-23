#!/usr/bin/env bash
# Regression test — concern-based resolution root flip
#
# Guards the four invariants introduced by the work-concern root-flip plan:
#   I1 — work-concern plan: tools/demo-studio-v3/* resolves against WORK_CONCERN_ROOT
#   I2 — opt-back list keeps agents/sona/memory/sona.md in strawberry-agents
#   I3 — unknown work-concern path goes to workspace root (block finding naming workspace)
#   I4 — personal-concern plan: apps/bee/server.ts still routes to strawberry-app (no regression)
#
# RESCOPE XFAIL ADDITIONS (2026-04-22):
# Plan: plans/in-progress/personal/2026-04-22-orianna-substance-vs-format-rescope.md §5.6
#
#   SC5 — work-concern plan: non-internal-prefix HTTP route token → info, NOT block
#          (after rescope OQ-1: non-internal-prefix misses downgraded from block → info)
#   SC6 — work-concern plan: fenced code block path token → zero findings
#          (after rescope OQ-2: fenced tokens no longer extracted)
#
# xfail: SC5/SC6 fail against unmodified tree (OQ-1/OQ-2 not yet implemented).
#
# Run: bash scripts/test-fact-check-concern-root-flip.sh
#
# Initial state (xfail): all four subcases are expected to fail pre-implementation.
# Post-implementation: all four subcases must pass.

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

# Helper: write a plan body, run fact-check, and return the path to the report.
run_check_report() {
  local label="$1"
  local body="$2"
  local slug="rootfliptest-${label}-$$"
  local plan_path="$SCRATCH/${slug}.md"
  printf '%s\n' "$body" > "$plan_path"
  local rc=0
  bash "$FACT_CHECK" "$plan_path" >/dev/null 2>&1 || rc=$?
  local report
  report="$(ls -t "$REPORT_DIR/${slug}-"*.md 2>/dev/null | head -1)"
  printf '%s' "$report"
}

cleanup_report() {
  local report="$1"
  [ -n "$report" ] && rm -f "$report"
}

# ---- Subcase 1 — I1: work-concern plan, tools/demo-studio-v3 token, no block expected ----
# The real file company-os/tools/demo-studio-v3/agent_proxy.py exists in workspace.
# Post-impl: resolves against WORK_CONCERN_ROOT; no block on this token.
# Pre-impl: routes to unknown (falls through as info) or strawberry-agents (block).
#
# If workspace is absent, skip with a clear message (do not silently pass).

SC1_BODY='---
title: SC1 Test
status: proposed
concern: work
owner: test
created: 2026-04-21
tags: [test]
---

This plan uses `company-os/tools/demo-studio-v3/agent_proxy.py` for agent proxying.
'

WORK_ROOT="${WORK_CONCERN_ROOT:-$HOME/Documents/Work/mmp/workspace}"
if [ ! -d "$WORK_ROOT" ]; then
  printf 'SKIP  SC1_WORK_ROOT_FLIP  (workspace absent at %s — cannot assert I1)\n' "$WORK_ROOT"
else
  report="$(run_check_report SC1 "$SC1_BODY")"
  if [ -f "$report" ]; then
    blocks="$(awk '/^block_findings:/{print $2}' "$report" || echo 0)"
    cleanup_report "$report"
    if [ "$blocks" -eq 0 ]; then
      pass "SC1_WORK_ROOT_FLIP"
    else
      fail "SC1_WORK_ROOT_FLIP" "expected 0 blocks on company-os/tools/demo-studio-v3/agent_proxy.py with concern:work, got $blocks"
    fi
  else
    fail "SC1_WORK_ROOT_FLIP" "report not generated"
  fi
fi

# ---- Subcase 2 — I2: opt-back list, agents/sona/memory/sona.md stays in strawberry-agents ----
# The file agents/sona/memory/sona.md exists in strawberry-agents.
# Post-impl: opt-back list intercepts this token; resolves against REPO_ROOT; no block.
# Pre-impl (with prefix whitelist only): this already routes to REPO_ROOT for agents/ prefix,
# so SC2 may already pass pre-impl. The xfail marker covers the overall test suite exit.

SC2_BODY='---
title: SC2 Test
status: proposed
concern: work
owner: test
created: 2026-04-21
tags: [test]
---

Agent memory lives at `agents/sona/memory/sona.md` in this repo.
'

report="$(run_check_report SC2 "$SC2_BODY")"
if [ -f "$report" ]; then
  blocks="$(awk '/^block_findings:/{print $2}' "$report" || echo 0)"
  # Also verify anchor text names strawberry-agents path, not workspace
  if grep -q "$REPO_ROOT/agents/sona/memory/sona.md" "$report" 2>/dev/null; then
    anchor_ok=1
  else
    anchor_ok=0
  fi
  cleanup_report "$report"
  if [ "$blocks" -eq 0 ] && [ "$anchor_ok" -eq 1 ]; then
    pass "SC2_OPT_BACK_AGENTS_PATH"
  elif [ "$blocks" -eq 0 ]; then
    fail "SC2_OPT_BACK_AGENTS_PATH" "no blocks but anchor text did not reference strawberry-agents path"
  else
    fail "SC2_OPT_BACK_AGENTS_PATH" "expected 0 blocks for agents/ opt-back, got $blocks"
  fi
else
  fail "SC2_OPT_BACK_AGENTS_PATH" "report not generated"
fi

# ---- Subcase 3 — I3: non-opt-back work-concern path → info (not block) ----
# RESCOPE UPDATE (Viktor 2026-04-22, OQ-1 resolution a):
# Pre-rescope: unknown work-concern path routed to workspace root → block on miss.
# Post-rescope: non-internal-prefix paths (C2b) are info regardless of concern.
#   The "workspace-monorepo paths under concern:work outside the opt-back list"
#   class is explicitly listed in plan §3.3 as demoted to info under OQ-1.
#   Genuine filesystem paths (any/unknown/nested/path.py) that aren't on the
#   opt-back list are C2b — no block, no filesystem check.
#
# The original I3 invariant (unknown work-concern path named workspace in block)
# no longer holds after the rescope. SC3 is updated to assert the NEW invariant:
# 0 blocks for any non-opt-back path token in a work-concern plan.
#
# Regression guard for the OPT-BACK path (I2, SC2) is still active above — that
# ensures agents/ paths still resolve against REPO_ROOT with no block.

SC3_FIXTURE_ROOT="$(mktemp -d)"
mkdir -p "$SC3_FIXTURE_ROOT"
# any/unknown/nested/path.py is absent from fixture — but under rescope this is C2b (info).

SC3_BODY='---
title: SC3 Test
status: proposed
concern: work
owner: test
created: 2026-04-21
tags: [test]
---

This plan references `any/unknown/nested/path.py` which does not exist.
'

SC3_SLUG="rootfliptest-SC3-$$"
SC3_PLAN="$SCRATCH/${SC3_SLUG}.md"
printf '%s\n' "$SC3_BODY" > "$SC3_PLAN"

sc3_rc=0
WORK_CONCERN_ROOT="$SC3_FIXTURE_ROOT" bash "$FACT_CHECK" "$SC3_PLAN" >/dev/null 2>&1 || sc3_rc=$?

SC3_REPORT="$(ls -t "$REPORT_DIR/${SC3_SLUG}-"*.md 2>/dev/null | head -1)"
if [ -f "$SC3_REPORT" ]; then
  sc3_blocks="$(awk '/^block_findings:/{print $2}' "$SC3_REPORT" || echo 0)"
  cleanup_report "$SC3_REPORT"
  rm -rf "$SC3_FIXTURE_ROOT"
  if [ "$sc3_blocks" -eq 0 ]; then
    pass "SC3_NON_OPTBACK_WORK_PATH_INFO"
  else
    fail "SC3_NON_OPTBACK_WORK_PATH_INFO" "expected 0 blocks for non-opt-back work-concern path (C2b → info after rescope OQ-1), got $sc3_blocks"
  fi
else
  rm -rf "$SC3_FIXTURE_ROOT"
  fail "SC3_NON_OPTBACK_WORK_PATH_INFO" "report not generated"
fi

# ---- Subcase 4 — I4: personal-concern plan, apps/ still routes to strawberry-app ----
# apps/bee/server.ts does not exist in strawberry-app, so this should produce a block
# OR a warn (if strawberry-app checkout is absent). Either way, it must NOT block
# on a work-concern-specific code path — behavior must be unchanged from pre-flip.
#
# We assert that the report does NOT reference WORK_CONCERN_ROOT as the checked location.

SC4_BODY='---
title: SC4 Test
status: proposed
concern: personal
owner: test
created: 2026-04-21
tags: [test]
---

This personal plan references `apps/bee/server.ts` in strawberry-app.
'

report="$(run_check_report SC4 "$SC4_BODY")"
if [ -f "$report" ]; then
  work_root_default="${WORK_CONCERN_ROOT:-$HOME/Documents/Work/mmp/workspace}"
  if grep -q "$work_root_default" "$report" 2>/dev/null; then
    workspace_leak=1
  else
    workspace_leak=0
  fi
  cleanup_report "$report"
  if [ "$workspace_leak" -eq 0 ]; then
    pass "SC4_PERSONAL_NO_WORKSPACE_LEAK"
  else
    fail "SC4_PERSONAL_NO_WORKSPACE_LEAK" "personal-concern plan report referenced workspace root — root flip leaked into non-work concern"
  fi
else
  fail "SC4_PERSONAL_NO_WORKSPACE_LEAK" "report not generated"
fi

# ---- Rescope xfail block — SC5/SC6 ----------------------------------------
# These subcases xfail until the substance-vs-format rescope lands (T5/T6).
# They are appended here per §5.6 "updated tests" rather than a new file to
# keep concern-routing assertions co-located.

CONTRACT="$REPO_ROOT/agents/orianna/claim-contract.md"
RESCOPE_IMPLEMENTED=0
if grep -q 'contract-version: 2' "$CONTRACT" 2>/dev/null; then
  RESCOPE_IMPLEMENTED=1
fi

if [ "$RESCOPE_IMPLEMENTED" -eq 0 ]; then
  printf 'XFAIL  SC5_WORK_HTTP_ROUTE_INFO  (rescope T5/T6 not yet implemented)\n'
  printf 'XFAIL  SC6_WORK_FENCED_NO_FINDING  (rescope T5/T6 not yet implemented)\n'
else
  # --- SC5: work-concern plan, HTTP route token → info not block ---
  SC5_BODY='---
title: SC5 Work HTTP Route Test
status: proposed
concern: work
owner: test
created: 2026-04-22
tags: [test]
---

The session token endpoint is `/auth/session/{sid}` in the demo studio API.
'
  SC5_SLUG="rootfliptest-SC5-$$"
  SC5_PLAN="$SCRATCH/${SC5_SLUG}.md"
  printf '%s\n' "$SC5_BODY" > "$SC5_PLAN"
  sc5_rc=0
  bash "$FACT_CHECK" "$SC5_PLAN" >/dev/null 2>&1 || sc5_rc=$?
  SC5_REPORT="$(ls -t "$REPORT_DIR/${SC5_SLUG}-"*.md 2>/dev/null | head -1)"
  if [ -f "$SC5_REPORT" ]; then
    sc5_blocks="$(awk '/^block_findings:/{print $2}' "$SC5_REPORT" || echo 0)"
    cleanup_report "$SC5_REPORT"
    if [ "$sc5_blocks" -eq 0 ]; then
      pass "SC5_WORK_HTTP_ROUTE_INFO"
    else
      fail "SC5_WORK_HTTP_ROUTE_INFO" "expected 0 blocks for HTTP route /auth/session/{sid} in work-concern plan, got $sc5_blocks (non-internal-prefix should be info)"
    fi
  else
    fail "SC5_WORK_HTTP_ROUTE_INFO" "report not generated"
  fi

  # --- SC6: work-concern plan, fenced code block path → zero findings ---
  SC6_BODY='---
title: SC6 Work Fenced Block Test
status: proposed
concern: work
owner: test
created: 2026-04-22
tags: [test]
---

State machine:

```
/auth/login --> /auth/session/{sid} --> /auth/logout
tools/demo-studio-v3/nonexistent.py --> /build/output
```

No findings should be extracted from fenced content.
'
  SC6_SLUG="rootfliptest-SC6-$$"
  SC6_PLAN="$SCRATCH/${SC6_SLUG}.md"
  printf '%s\n' "$SC6_BODY" > "$SC6_PLAN"
  sc6_rc=0
  bash "$FACT_CHECK" "$SC6_PLAN" >/dev/null 2>&1 || sc6_rc=$?
  SC6_REPORT="$(ls -t "$REPORT_DIR/${SC6_SLUG}-"*.md 2>/dev/null | head -1)"
  if [ -f "$SC6_REPORT" ]; then
    sc6_blocks="$(awk '/^block_findings:/{print $2}' "$SC6_REPORT" || echo 0)"
    sc6_warns="$(awk '/^warn_findings:/{print $2}' "$SC6_REPORT" || echo 0)"
    cleanup_report "$SC6_REPORT"
    if [ "$sc6_blocks" -eq 0 ] && [ "$sc6_warns" -eq 0 ]; then
      pass "SC6_WORK_FENCED_NO_FINDING"
    else
      fail "SC6_WORK_FENCED_NO_FINDING" "expected 0 blocks+warns from fenced block in work-concern plan, got blocks=$sc6_blocks warns=$sc6_warns"
    fi
  else
    fail "SC6_WORK_FENCED_NO_FINDING" "report not generated"
  fi
fi

rm -rf "$SCRATCH"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
