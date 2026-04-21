# Fastlane pattern for post-impl plan promotion

**Date:** 2026-04-21
**Session:** 0cf7b28e (third leg)
**Trigger:** Ship-day directive to push all four ADRs + E2E ship + claim-contract to `implemented` in one batch after implementation had already landed on branches.

## Context

Normal plan lifecycle: proposed → (Orianna sign) → approved → (impl dispatch) → in-progress → (impl verified) → implemented. Each transition has audit artifacts.

Ship-day scenario: implementation is already done on branches, tests are green, and the plan status markers are just lagging reality. Spending time on full signing ceremony for every downstream transition delays actual ship work.

## Pattern that worked

1. **Document the directive** — commit trailer `Sona-Admin-Directive: Duong 2026-04-21 ship-day fastlane` on every fastlane commit.
2. **Identify which transitions are mechanically unguarded** — `approved → in-progress` and `in-progress → implemented` have no Orianna hook; raw `git mv` + status rewrite works under plain `Duongntd`.
3. **Batch the fastlane commits** — one commit per plan per transition, with explicit messages referencing the directive. Commit SHAs `09f6421` through `4fe29b4` are the audit trail.
4. **Keep `proposed → approved` gated** — that transition requires `plan-promote.sh` (Orianna gate) or an `Orianna-Bypass:` trailer from `harukainguyen1411`. The E2E ship plan went through Ekko's bypass attempt (`863804b`) — which worked mechanically but triggered the security hook. For future fastlanes, if `proposed → approved` must be bypassed, use Duong's admin session directly rather than agent impersonation.
5. **File the audit** — `assessments/ship-day-deploy-checklist-2026-04-21.md` + shard references constitute the audit trail.

## When to apply

Only under explicit Duong "fastlane everything" or equivalent ship-day directive. Not a routine pattern — the normal signing ceremony exists for a reason (Orianna catches real claim failures). Fastlane is appropriate when: implementation is verified, time is constrained, and the plan status markers are purely administrative.

## What not to do

Do not have agents impersonate admin identity to bypass the `proposed → approved` gate. Even under ship-day directive, the `harukainguyen1411` identity restriction on `Orianna-Bypass:` trailers exists to maintain an auditable chain of human authorization. If the bypass is truly needed, Duong executes it directly.
