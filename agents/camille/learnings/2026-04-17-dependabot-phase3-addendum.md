# Dependabot Phase 3 Addendum — field notes

**Context:** 2026-04-17, drafted Phase 3 addendum after Phase 1-2 resolved 79/104 alerts. 25 remain.

## Key lessons

1. **Pattern reuse > re-planning.** When drafting a phase addendum, the highest-leverage move is to cross-reference the executor's learnings (Viktor) and verifier's learnings (Vi) into an explicit pattern table in the plan. Implementers then don't have to re-derive what worked.

2. **Pre-flight re-query is mandatory for addenda.** Dependabot alerts auto-close on merge propagation. Between Phase 2 merge and Phase 3 start, more alerts may already be resolved. Always re-query `gh api .../dependabot/alerts?state=open` before drafting a patch for any specific alert number. Alert #66 (vite 6.x in myapps) is the canary — likely auto-closed by B8 propagation.

3. **Batch serialization by manifest, not by phase.** Two batches touching the same lockfile cannot run in parallel — they will merge-conflict. In Phase 3, B3c and B3d both touch `apps/myapps/package-lock.json` → must serialize. B3a and B3b have no shared manifest → safe parallel.

4. **minimatch per-major override specificity.** A single unconditional `overrides[minimatch]=^10.0.1` breaks parent packages that require `<=3.x` or `<=5.x` API. Must write one override entry per major, each pinning to that major's latest patched (3.1.2, 5.1.7, 6.0.1, 10.0.1). This matters because npm `overrides` can be chained by parent path but most implementers reach for the flat form.

5. **bee-worker vitest upgrade has unusual zero-blast-radius profile.** Vi's learning ("no test files found") means vitest 2→3 API drift cannot break anything inside bee-worker. The green gate is `tsc --noEmit` + build, not vitest. This inverts the usual test-coupled-upgrade risk calculus.

6. **Surgical vs regen decision: size threshold.** Root lockfile regen is safe only if the lockfile is small enough for the drift diff to be reviewable. Rule of thumb from Viktor's pattern: >5k lines → surgical; else regen-small with drift-pin follow-up.
