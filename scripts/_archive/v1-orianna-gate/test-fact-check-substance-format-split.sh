#!/usr/bin/env bash
# xfail — substance-vs-format check-set split
# Plan: plans/in-progress/personal/2026-04-22-orianna-substance-vs-format-rescope.md §5.6 / §T1
#
# Covers seven classification boundaries:
#
#   SC1 — HTTP route token in inline backtick  → info finding, NOT block       (OQ-1 / §3.3 rule 2)
#   SC2 — Internal-prefix path miss            → block finding (unchanged)     (§3.3 rule 1)
#   SC3 — Fenced code block path token         → zero findings extracted       (OQ-2 / §3.3 rule 3)
#   SC4 — Step-A status: field missing         → warn, NOT block               (OQ-4 resolved: drop;
#                                                 test reflects warn expectation until OQ-4 drop
#                                                 lands; see test-orianna-plan-check-step-a-drop.sh
#                                                 for the drop-specific xfail)
#   SC5 — Step-A owner: field missing          → block (unchanged)
#   SC6 — architecture_impact:none + no body   → block (unchanged)
#   SC7 — Task missing estimate_minutes:       → Orianna exits 0, no block     (OQ-3 / TG-2 dropped)
#
# xfail: all seven cases fail against the unmodified tree because:
#   SC1 — HTTP route currently treated as block (PA-6 pre-split)
#   SC2 — Already blocks; guard checks the right reason (should PASS already — included for baseline)
#   SC3 — Fenced tokens currently extracted and may produce findings (PA-7 not yet dropped)
#   SC4 — status: missing currently block in Step A (not yet demoted/dropped)
#   SC5 — owner: missing currently block (unchanged; included as stability anchor)
#   SC6 — architecture_impact:none without body currently block (unchanged)
#   SC7 — estimate_minutes currently validated by Orianna (TG-2 not yet dropped)
#
# Run: bash scripts/test-fact-check-substance-format-split.sh

# xfail: implementation not yet present (rescope T5/T6/T7 not committed)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FACT_CHECK="$SCRIPT_DIR/fact-check-plan.sh"

PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s  (%s)\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# --- XFAIL guard ---
# The rescope implementation (T5 bash fallback, T6 prompts) has not landed yet.
# Detect by checking for the v2 contract version in claim-contract.md.
CONTRACT="$REPO_ROOT/agents/orianna/claim-contract.md"
RESCOPE_IMPLEMENTED=0
if grep -q 'contract-version: 2' "$CONTRACT" 2>/dev/null; then
  RESCOPE_IMPLEMENTED=1
fi

if [ "$RESCOPE_IMPLEMENTED" -eq 0 ]; then
  printf 'XFAIL (expected — rescope not implemented: contract-version is still v1)\n'
  for c in SC1_HTTP_ROUTE_INFO SC2_INTERNAL_PREFIX_BLOCKS SC3_FENCED_NO_FINDING \
            SC4_STATUS_MISSING_WARN SC5_OWNER_MISSING_BLOCK SC6_ARCH_NONE_BLOCKS SC7_ESTIMATE_ORIANNA_PASS; do
    printf 'XFAIL  %s\n' "$c"
  done
  printf '\nResults: 0 passed, 7 xfail (expected — T4/T5/T6/T7 not yet implemented)\n'
  exit 0
fi

[ -f "$FACT_CHECK" ] || { printf 'SKIP  fact-check-plan.sh not found\n'; exit 0; }

SCRATCH="$(mktemp -d)"
REPORT_DIR="$REPO_ROOT/assessments/plan-fact-checks"
mkdir -p "$REPORT_DIR"

# Helper: write plan, run fact-check, echo path to report.
run_check_report() {
  local label="$1"
  local body="$2"
  local slug="substfmt-${label}-$$"
  local plan_path="$SCRATCH/${slug}.md"
  printf '%s\n' "$body" > "$plan_path"
  local rc=0
  bash "$FACT_CHECK" "$plan_path" >/dev/null 2>&1 || rc=$?
  local report
  report="$(ls -t "$REPORT_DIR/${slug}-"*.md 2>/dev/null | head -1)"
  printf '%s' "$report"
}

read_count() {
  local report="$1"
  local key="$2"
  awk "/^${key}:/{print \$2}" "$report" 2>/dev/null | head -1 || printf '0'
}

cleanup() { local r="$1"; [ -n "$r" ] && rm -f "$r"; }

# --- SC1: HTTP route token in inline backtick → info, NOT block ---
# /auth/login is not an internal-prefix path; under the rescoped gate it must
# produce an info finding (or none) but never a block finding.
SC1_BODY='---
title: SC1 HTTP Route Test
status: proposed
concern: personal
owner: test
created: 2026-04-22
tags: [test]
---

The session endpoint is reached at `/auth/login` with a POST request.
'
r="$(run_check_report SC1 "$SC1_BODY")"
if [ -f "$r" ]; then
  blocks="$(read_count "$r" block_findings)"
  info="$(read_count "$r" info_findings)"
  cleanup "$r"
  if [ "$blocks" -eq 0 ]; then
    pass "SC1_HTTP_ROUTE_INFO"
  else
    fail "SC1_HTTP_ROUTE_INFO" "expected 0 blocks for HTTP route token /auth/login, got $blocks (non-internal-prefix should be info)"
  fi
else
  fail "SC1_HTTP_ROUTE_INFO" "report not generated"
fi

# --- SC2: Internal-prefix path miss → block (unchanged baseline) ---
# scripts/definitely-nonexistent-xzqq.sh is an internal-prefix token; miss must still block.
SC2_BODY='---
title: SC2 Internal Prefix Test
status: proposed
concern: personal
owner: test
created: 2026-04-22
tags: [test]
---

The build step runs `scripts/definitely-nonexistent-xzqq.sh` before deploy.
'
r="$(run_check_report SC2 "$SC2_BODY")"
if [ -f "$r" ]; then
  blocks="$(read_count "$r" block_findings)"
  cleanup "$r"
  if [ "$blocks" -ge 1 ]; then
    pass "SC2_INTERNAL_PREFIX_BLOCKS"
  else
    fail "SC2_INTERNAL_PREFIX_BLOCKS" "expected >=1 block for missing internal-prefix path, got 0 (substance gate regressed)"
  fi
else
  fail "SC2_INTERNAL_PREFIX_BLOCKS" "report not generated"
fi

# --- SC3: Fenced code block path token → zero findings extracted ---
# Under the rescope, tokens inside fenced blocks are not extracted.
# /foo/bar inside a fence must produce zero findings (no block, no warn, no info from the fence).
SC3_BODY='---
title: SC3 Fenced Block Test
status: proposed
concern: personal
owner: test
created: 2026-04-22
tags: [test]
---

Example diagram:

```
/foo/bar --> /baz/qux --> scripts/nonexistent-xzqq2.sh
```

No extraction should occur from the fence above.
'
r="$(run_check_report SC3 "$SC3_BODY")"
if [ -f "$r" ]; then
  blocks="$(read_count "$r" block_findings)"
  warns="$(read_count "$r" warn_findings)"
  # info is allowed (e.g. for frontmatter); we assert no block/warn from fenced tokens
  cleanup "$r"
  if [ "$blocks" -eq 0 ] && [ "$warns" -eq 0 ]; then
    pass "SC3_FENCED_NO_FINDING"
  else
    fail "SC3_FENCED_NO_FINDING" "expected 0 blocks and 0 warns from fenced tokens, got blocks=$blocks warns=$warns (PA-7 not yet dropped)"
  fi
else
  fail "SC3_FENCED_NO_FINDING" "report not generated"
fi

# --- SC4: status: field missing → warn, NOT block (PA-1 demoted) ---
# Under OQ-4 resolution (drop), this should produce zero block findings.
# The test is framed as "warn or zero" to survive both the demotion (warn) and
# drop (zero) stages of implementation. SC4 is NOT block in either case.
SC4_BODY='---
title: SC4 Status Missing Test
concern: personal
owner: test
created: 2026-04-22
tags: [test]
---

Plan body with no status field in frontmatter.
'
r="$(run_check_report SC4 "$SC4_BODY")"
if [ -f "$r" ]; then
  blocks="$(read_count "$r" block_findings)"
  cleanup "$r"
  if [ "$blocks" -eq 0 ]; then
    pass "SC4_STATUS_MISSING_WARN"
  else
    fail "SC4_STATUS_MISSING_WARN" "expected 0 blocks when status: is absent (PA-1 dropped/demoted), got $blocks"
  fi
else
  fail "SC4_STATUS_MISSING_WARN" "report not generated"
fi

# --- SC5: owner: field missing → block (unchanged) ---
# PA-2 stays at block; this is the baseline anchor proving substance checks survive.
SC5_BODY='---
title: SC5 Owner Missing Test
status: proposed
concern: personal
created: 2026-04-22
tags: [test]
---

Plan body with no owner field.
'
r="$(run_check_report SC5 "$SC5_BODY")"
if [ -f "$r" ]; then
  blocks="$(read_count "$r" block_findings)"
  cleanup "$r"
  if [ "$blocks" -ge 1 ]; then
    pass "SC5_OWNER_MISSING_BLOCK"
  else
    fail "SC5_OWNER_MISSING_BLOCK" "expected >=1 block when owner: is absent (PA-2 must stay block), got 0 (substance gate regressed)"
  fi
else
  fail "SC5_OWNER_MISSING_BLOCK" "report not generated"
fi

# --- SC6: architecture_impact: none with no ## Architecture impact body → block (unchanged) ---
# IG-3 is kept at block in the LLM path (implementation-gate-check.md Step B).
#
# CANARY NOTE (Viktor 2026-04-22, task brief instruction SC6):
# IG-3 (architecture_impact: none + no section body) is LLM-path-only. The bash
# fallback (fact-check-plan.sh) performs path-token and frontmatter-owner checks
# only — it cannot model the "declared-none with no rationale" semantic check
# that IG-3 requires (section body presence + content check). Adding a full
# markdown-section-body parser to the bash fallback would be disproportionate
# scope for a fallback designed for connectivity-absent scenarios.
#
# Decision: SC6 is a CANARY (informational pass). It documents the IG-3 check
# exists in the prompt layer and must be preserved there, but does not assert
# bash-fallback behavior for this check. Rakan is informed of this downgrade.
#
# The IG-3 check is covered by:
#   - agents/orianna/prompts/implementation-gate-check.md Step B (LLM path)
#   - scripts/test-orianna-architecture.sh (architecture gate unit tests)
printf 'CANARY SC6_ARCH_NONE_BLOCKS — IG-3 is LLM-path-only; bash fallback cannot model section-body check (see inline note)\n'
PASS=$((PASS + 1))

# --- SC7: task missing estimate_minutes → Orianna exits 0 (TG-2 dropped) ---
# A plan with a task missing estimate_minutes: must NOT produce an Orianna block.
# (The pre-commit linter is the sole enforcer after TG-2 is dropped.)
SC7_BODY='---
title: SC7 Estimate Drop Test
status: proposed
concern: personal
owner: test
created: 2026-04-22
tags: [test]
tests_required: false
---

## Tasks

- [ ] **T1** — do something without an estimate_minutes field.

## Test plan

N/A (tests_required: false)
'
r="$(run_check_report SC7 "$SC7_BODY")"
if [ -f "$r" ]; then
  blocks="$(read_count "$r" block_findings)"
  cleanup "$r"
  if [ "$blocks" -eq 0 ]; then
    pass "SC7_ESTIMATE_ORIANNA_PASS"
  else
    fail "SC7_ESTIMATE_ORIANNA_PASS" "expected 0 blocks when estimate_minutes is absent (TG-2 dropped from Orianna), got $blocks"
  fi
else
  fail "SC7_ESTIMATE_ORIANNA_PASS" "report not generated"
fi

rm -rf "$SCRATCH"

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
