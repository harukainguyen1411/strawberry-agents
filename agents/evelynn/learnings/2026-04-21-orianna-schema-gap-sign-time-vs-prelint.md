# Orianna sign-time schema is stricter than commit-time pre-lint

**Date:** 2026-04-21
**Source:** Multiple Orianna block findings on inbox, memory-consolidation, managed-agent-lifecycle, and dashboard-tab ADRs this session

## What happened

Across four ADRs signed this session, Orianna returned blocks that the commit-time pre-lint hook did not catch. Common categories:

- **Bare filenames** — a path fragment without a qualifying directory prefix that Orianna flags as a prospective-file reference requiring a suppression marker.
- **Cross-repo tool paths** — references to `tools/` or `scripts/` in external repos that Orianna can't resolve against the current repo's tree.
- **Forward self-refs** — plan referring to its own future sections or companion-plan files before they exist.
- **External URL tokens** — URL fragments that Orianna's claim-verification pass treats as unverifiable external claims.
- **Company-OS org slugs** — references to org names in the work-concern repo that Orianna can't verify from the personal concern's context.

The pre-commit hook's `plan-prelint` step does not check any of these. It checks YAML schema, status field, date format, and commit-message prefix only.

## The structural gap

```
Pre-commit hook (plan-prelint)          Orianna sign-time schema
--------------------------------        --------------------------------
YAML frontmatter validity               + bare filename refs
status: field present                   + cross-repo tool paths
date format                             + forward self-refs
commit prefix                           + external claim verifiability
                                        + company-os org slug resolution
                                        + suppression marker completeness
```

Everything in the right column can only be caught at Orianna invocation time. Today, that first happens at the `plan-promote.sh` → proposed → approved gate. By that point, the plan has already gone through multiple author/amendment/commit cycles.

## Consequence

Blocks at promotion time require amendment → commit → re-promote cycles. Each round has an Orianna budget cost. With 4 ADRs today, the total amendment commits for Orianna block remediation exceeded 10.

## Remediation path

`plans/proposed/personal/2026-04-21-plan-prelint-shift-left.md` — Karma quick-lane plan to expand the commit-time pre-lint to cover at least the subset of Orianna block categories that are statically detectable: bare filenames, cross-repo tool paths, company-os org slugs, and forward self-refs with known patterns.

This does not eliminate the gap entirely (some Orianna checks require semantic understanding) but shifts the cheapest catches to author time.

## Temporary practice

Until the quick-lane plan is implemented, plan authors should run `scripts/orianna-fact-check.sh <plan>` manually before their first `plan-promote.sh` call and fix all returned blocks. This costs one Orianna budget unit per plan but eliminates the back-and-forth amendment cycle at promotion time.
