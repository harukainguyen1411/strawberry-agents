# Phase 0 merge queue audit — 2026-04-18

| PR | Title | State | Review | CI summary | Admin-merge candidate? | Notes |
|----|-------|-------|--------|------------|------------------------|-------|
| #146 | chore: J1 — regression lane scaffold + PR template Testing section | MERGED | — | all pass (Firebase preview fail only) | NO (already merged) | Merged 2026-04-18T07:46:20Z; was dual-green prior to merge |
| #148 | ops: I2 Cloud Run service account IAM for test dashboard | MERGED | — | all pass (Firebase preview fail only) | NO (already merged) | Merged 2026-04-18T07:43:11Z; was dual-green prior to merge |
| #152 | feat: G1 routing skeleton + layout — React Router, route placeholders, /monitoring/* reserved | OPEN | none | 4 red (Firebase preview, Lint+Test+Build, QA report, unit-tests) | NO | Real CI failures: Lint+Test+Build (14s, non-billing) + unit-tests + QA report — not billing-only |
| #153 | chore: F1+F2 auth middleware — ingest token + Firebase ID token | MERGED | — | all fail (1-2s, billing hardstop pattern) | NO (already merged) | Merged 2026-04-18T09:50:48Z; admin-merged under billing hardstop per plan D5 |
| #154 | chore: B3 signed URL helpers (V4, 15min, upload + download) | MERGED | — | all fail (1-3s, billing hardstop pattern) | NO (already merged) | Merged 2026-04-18T09:50:39Z; admin-merged under billing hardstop per plan D5 |
| #161 | chore: C2 — dashboards hook wiring verification | OPEN | none | all fail (2-3s, billing hardstop pattern) | NO | OPEN but no reviewDecision (not APPROVED) — cannot admin-merge without review |
| #165 | ops: C2 — pre-commit unit test hook wiring for dashboards (pnpm) | MERGED | — | all fail (1-2s, billing hardstop pattern) | NO (already merged) | Merged 2026-04-18T09:50:25Z; admin-merged under billing hardstop per plan D5 |
| #169 | chore: D1 report-run.sh — POSIX reporter normalizer | MERGED | — | all fail (2-3s, billing hardstop pattern) | NO (already merged) | Merged 2026-04-18T09:50:12Z; admin-merged under billing hardstop per plan D5 |
| #170 | chore: health endpoint xfail flip + firestore-rules syntax fix | MERGED | — | all fail (2-4s, billing hardstop pattern) | NO (already merged) | Merged 2026-04-18T09:50:06Z; admin-merged under billing hardstop per plan D5 |
| #175 | chore: xfail grep fix — add it.fails + verification step in testing.md | MERGED | — | all pass (Firebase preview fail only) | NO (already merged) | Merged 2026-04-18T09:49:55Z; was dual-green prior to merge |
| #177 | feat: D2 POST /api/runs — create run + cases, return upload URLs | MERGED | — | all fail (2-3s, billing hardstop pattern) | NO (already merged) | Merged 2026-04-18T09:53:31Z; admin-merged under billing hardstop per plan D5 |
| #180 | chore: fix dashboards.sh — correct AR host + allow-unauthenticated comment | MERGED | — | all fail (2-3s, billing hardstop pattern) | NO (already merged) | Merged 2026-04-18T09:49:38Z; admin-merged under billing hardstop per plan D5 |
| #182 | chore: F3 CORS middleware — UI origin allow, ingestion deny | MERGED | — | all fail (2-4s, billing hardstop pattern) | NO (already merged) | Merged 2026-04-18T09:49:31Z; admin-merged under billing hardstop per plan D5 |

---

## Summary

**Total admin-merge candidates: 0**

All 13 PRs in the plan have already been acted on. 11 are MERGED. 2 remain OPEN:

- **#152** — OPEN but has real CI failures (Lint+Test+Build, unit-tests, QA report all failing at 14s durations — not billing hardstop). Not a candidate regardless.
- **#161** — OPEN but has no reviewDecision (not APPROVED). CI shows billing-hardstop pattern (1-3s durations, all checks fail). Cannot admin-merge without an approving review.

---

## Changed state since plan was written

The plan listed 13 PRs as "cannot merge because required status checks cannot dequeue." Since the plan was authored, the following state changes occurred (all on 2026-04-18, during or after the plan's approval):

| PR | Plan state (implied) | Actual state at audit |
|----|---------------------|-----------------------|
| #146 | OPEN (dual-green) | MERGED |
| #148 | OPEN (dual-green) | MERGED |
| #153 | OPEN (billing-blocked) | MERGED (admin-bypass) |
| #154 | OPEN (billing-blocked) | MERGED (admin-bypass) |
| #165 | OPEN (billing-blocked) | MERGED (admin-bypass) |
| #169 | OPEN (billing-blocked) | MERGED (admin-bypass) |
| #170 | OPEN (billing-blocked) | MERGED (admin-bypass) |
| #175 | OPEN (dual-green) | MERGED |
| #177 | OPEN (billing-blocked) | MERGED (admin-bypass) |
| #180 | OPEN (billing-blocked) | MERGED (admin-bypass) |
| #182 | OPEN (billing-blocked) | MERGED (admin-bypass) |

**Conclusion:** Phase 0 has already been executed (partially or fully) by a prior session. The admin-bypass merges for billing-blocked PRs appear to have happened before this audit session.

---

## Recommended merge order

Moot — no OPEN APPROVED candidates remain to order.

For the two remaining OPEN PRs, next steps are:

1. **#161** — Needs a human review (APPROVED) before any merge path. CI pattern looks billing-hardstop, so if approved, admin-merge is the only path while minutes remain 0.
2. **#152** — Has real CI failures. Needs the underlying Lint+Test+Build, unit-tests, and QA report failures debugged and fixed before it can merge via any path.

---

## Additional open PRs not in the plan's 13 — APPROVED scan

Scanned all open PRs via `gh pr list --state open --json number,title,reviewDecision,updatedAt`.

**No open PR has reviewDecision = APPROVED.**

Notable open PRs for context (all unreviewed):
- #179 feat(p1.2): implement scripts/deploy/_lib.sh — 8 helper contracts
- #181 chore: F3 — CORS middleware (UI origin allow, ingestion deny) — appears to be a duplicate/re-open of already-merged #182; worth closing
- #176, #174, #171, #157 — bump/dependency PRs (Dependabot or manual)
- #162, #160, #164, #163, #167, #168 — Dependabot action/dep bumps
- Many older Dependabot PRs (#28–#59 range) still open

None qualify as admin-merge candidates (no approvals, and most are Dependabot which will re-open in strawberry-app post-migration anyway).
