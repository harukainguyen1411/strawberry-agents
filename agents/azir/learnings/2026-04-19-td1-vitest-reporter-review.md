# TD.1 Vitest reporter review — retention-semantics as an architectural wedge between writer and aggregator (2026-04-19)

## Context

Reviewed PR #49 on `harukainguyen1411/strawberry-app` (TD.1 Vitest reporter package) against `plans/approved/2026-04-19-tests-dashboard.md` (ADR) and the tasks plan (TD.1 section).

## Lesson — where retention belongs depends on the aggregator contract

ADR D10 declares archive-spill semantics ("Older runs spill into a compressed archive file … Zero data loss; bounded memory footprint") but ADR §Architecture names the aggregator as the 50-run cap enforcer. The writer and aggregator therefore have two different retention roles, and the ADR does not resolve which one *archives*:

- **Writer role** (TD.1): emits per-run output into its local `.test-dashboard/`. Retention here is a defensive cap against unbounded local disk, not an archive contract.
- **Aggregator role** (TD.2): merges across repos, enforces the 50-run cross-repo cap, and is the natural home for archive spill.

TD.1 chose a simple `.slice(-50)` drop. That is safe for v1 (50 local runs is long) but violates the "zero data loss" phrase in D10 *if read literally*. The correct structural resolution is to pin retention semantics in TD.2's PR — the aggregator archives, and the writer's local cap is a soft bound. Flagging this in TD.1 review (not blocking) and explicitly deferring to TD.2 is the right call: blocking TD.1 for a question only TD.2 can answer is the wrong cycle to burn.

**Generalizable pattern:** when an ADR distributes one contract across two components (writer + aggregator here), the boundary is often ambiguous until one side lands. Review the first landing against invariants only, defer boundary questions to the second landing's PR, and flag explicitly in both review and memory so the second reviewer sees the open question.

## Lesson — cross-repo fs paths in test code are a code smell even when fails-open

TD.1's xfail test hardcoded `../../../../agents/schemas/...` relative to a test file, gated by `fs.existsSync`. Technically works, technically non-blocking. But it bakes in an unstated cross-repo checkout layout that the ADR does not specify. Two repos can be checked out anywhere, and CI may clone only one. The tasks plan OQ-A default ("vendor a copy per writer with a byte-for-byte CI check") is architecturally cleaner because it keeps the writer self-contained.

**Generalizable pattern:** cross-repo references in code (even in test code, even when fails-open) are coupling the ADR didn't specify. Flag them. They usually disappear when the canonical source lands, but surfacing them in review saves a later cleanup pass.

## Lesson — ADR invariants vs code-level smells, two different review modes

The PR also had three code-level issues: operator precedence in `nodeIdOf`, unused `vi` import, dead `polling` variable. None are architectural — they're lint-level. Including them in an architectural review as "breadcrumbs, not change requests" is the right separation. Request-changes is reserved for structural issues; comments carry both structural follow-ups and code-level breadcrumbs, labeled distinctly.

## Applied to memory

- Added to Key Knowledge: "PR architectural review posture — judge against ADR invariants only; code-level smells are breadcrumbs, not change requests. Use `--comment` not `--request-changes` when invariants hold."
