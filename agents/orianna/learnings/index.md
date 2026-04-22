# Orianna — Learnings Index

## 2026-04-22 — Substance-vs-format rescope (claim-contract v1→v2)

- **What:** Rescoped the Orianna check set along a substance-vs-format axis per
  ADR `plans/in-progress/personal/2026-04-22-orianna-substance-vs-format-rescope.md`.
- **Claim-contract version:** bumped from v1 to v2.
- **Key changes:**
  - C2 path category split into C2a (internal-prefix, block on miss) and C2b
    (non-internal-prefix, info, no filesystem check).
  - Fenced code block content no longer extracted — illustrative only.
  - PA-1/PA-3/PA-4 (status/created/tags) dropped from Orianna; pre-commit
    linter is sole authority for those frontmatter fields.
  - TG-2/TG-3/TG-4 (estimate_minutes) dropped from Orianna; pre-commit linter
    is sole authority.
  - Non-internal-prefix path tokens (HTTP routes, dotted identifiers, template
    expressions) classified as non-claim (§2) or C2b (info).
- **False-positive pattern eliminated:** HTTP routes like `/auth/login`,
  Python identifiers like `firebase_admin.auth.verify_id_token`, and ASCII
  diagram tokens inside fenced blocks no longer produce block findings.
- **Canary validated:** `plans/proposed/personal/2026-04-22-orianna-rescope-canary.md`
  achieved zero block findings on first pass with no `<!-- orianna: ok -->` markers
  on non-internal-prefix tokens.
- **SC6 canary decision:** IG-3 (architecture_impact:none + no section body) is
  LLM-path-only. The bash fallback cannot model section-body presence check without
  a full markdown parser. SC6 in test-fact-check-substance-format-split.sh is
  a CANARY (informational pass) rather than a wired assertion.
- **last_used:** 2026-04-22
