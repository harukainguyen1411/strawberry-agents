# PR #21 review — Orianna substance-vs-format rescope (claim-contract v1→v2)

**Date:** 2026-04-22
**Verdict:** APPROVE (advisory LGTM; no critical or important findings)
**PR:** `harukainguyen1411/strawberry-agents#21`, branch `feat/orianna-substance-rescope`
**Paired reviewer:** Lucian also APPROVED on plan/ADR fidelity lane (`strawberry-reviewers`)
**Plan:** `plans/in-progress/personal/2026-04-22-orianna-substance-vs-format-rescope.md`

## What the PR does

Rescopes Orianna gate checks along a substance-vs-format axis, per Duong's six OQ resolutions:

- OQ-1a — non-internal-prefix path tokens demoted from block to info
- OQ-2a — fenced code blocks no longer extracted (hard drop)
- OQ-3a — `estimate_minutes` validation dropped from Orianna entirely (pre-commit linter is sole authority)
- OQ-4b — PA-1/PA-3/PA-4 frontmatter fields dropped entirely (not demoted to warn — divergence from Swain's recommendation)
- OQ-5b — parallel with speedups PR (merged)
- OQ-6b — claim-contract bumped v1→v2 with a v1→v2 delta section

~2,100 lines of diff: claim-contract.md, three prompt files, fact-check-plan.sh, plan-lifecycle.md, three new xfail scripts, three updated test scripts, canary plan + report.

## Substance-check preservation audit (my core responsibility)

Verified that no substance check was dropped beyond what OQ resolutions authorized:

- **PA-2 owner check** — newly added to the bash fallback (was LLM-only). Upgrade, not regression. `fact-check-plan.sh:343-347`.
- **IG-3 architecture_impact:none requires `## Architecture impact` section body** — preserved in `implementation-gate-check.md` Step B Option 2. The SC6 xfail canary downgrade is legitimate: bash fallback cannot model markdown section-body presence without a real parser. IG-3 remains enforced at the LLM path + `test-orianna-architecture.sh`.
- **Signature carry-forward** — `implementation-gate-check.md` Steps D/E still invoke `orianna-verify-signature.sh` for approved + in_progress. GF1/GF2 grandfather tests pass.
- **Allowlist / integration-name strict default (§4)** — unchanged for C1 + C2a. C2b info-demotion is explicitly scoped to path-shape category only.

## Key patterns to remember

### Strict-shrink property for claim-contract version bumps

The v1→v2 delta section documents explicitly: "Every plan that passed the v1 gate trivially passes the v2 gate." When reviewing contract changes, verify this property holds — if a v2 gate *adds* any check not in v1, grandfathering is at risk and existing signed plans can become invalid.

### The is_internal_prefix / _is_optback / route_path triplet

Three prefix lists exist inline in `fact-check-plan.sh` (plus contract §1 and `plan-check.md` Step C). They must stay in sync. The contract says "must enumerate identical entries" but there's no mechanical enforcement. When reviewing touches to any of the three, check the others. A future refactor could extract a shared shell lib; today it's a latent drift bug.

### OQ decisions can override plan §N content

Plan §5.1 item 1 said "demote PA-1/PA-3/PA-4 to warn" but OQ-4 resolution (b) later picked "drop entirely." Viktor correctly implemented the *later* decision. This is expected for any plan where OQ resolutions postdate the delta manifest — trust the OQ block over the §5 wording. Flag the plan-body staleness to Lucian, not yourself.

### Security posture: `test -e "$repo_root/$token"` is safe

Double-quoted arguments prevent shell expansion of token contents. Token extraction is bounded by backticks and whitespace-rejection. Leading/trailing punctuation stripping uses a fixed set. No command-injection exposure even with adversarial backtick content in a plan.

### The awk fence-boundary suppression reset

`/^\`\`\`/ { in_fence = ... ; suppress_next = 0 ; next }` — resetting `suppress_next` on fence lines means a standalone `<!-- orianna: ok -->` immediately before a ``` fence has its suppression dropped. Matches v1 and is fine while fenced content is dropped entirely (v2); becomes relevant if OQ-2 alt-b is ever revisited.

## Review artifact

Review posted via `scripts/reviewer-auth.sh --lane senna` — state APPROVED as `strawberry-reviewers-2`, ID `PRR_kwDOSGFeXc73iBY_`. Lucian's separate approval (`strawberry-reviewers`, ID `PRR_kwDOSGFeXc73iANa`) did NOT mask mine — the dual-lane structure from the PR #45 incident worked.

## Follow-ups worth doing later (not for this PR)

- Consolidate the three internal-prefix lists into a sourceable shell lib (`scripts/_lib_orianna_prefixes.sh` or similar).
- Fix the pre-existing `is_allowlisted` subshell-while-loop return-value bug (not in this PR's scope; it's been broken since fact-check-plan.sh was written).
