# PR #32 demo-studio-v3 god PR — plan/ADR fidelity review

**Date:** 2026-04-25
**Repo:** missmp/company-os
**Verdict:** APPROVE (work-scope comment, manual approval needed)
**Review URL:** https://github.com/missmp/company-os/pull/32#issuecomment-4318169687

## Shape

250 commits, 483 files, 303k additions — long-lived `feat/demo-studio-v3` → main. Cumulative ship of nine ADRs (SE/BD/MAL/MAD/MCP-merge/S3-reuse/S5-fullview/S1-new-flow/P1-factory_build) across waves A→D.

## Fidelity-review heuristics for god PRs

When a PR aggregates a long-lived branch with N ADRs:

1. **Don't try to read all commits.** Use `gh api repos/.../pulls/N/commits --paginate --jq '...'` then grep for task-tag prefixes (`T.W*`, `T.P1.*`, wave markers).
2. **Anchor on the most recent fixup commit's message.** It usually documents the deliberate concessions (xfails, contract updates) and tags follow-ups. Verify each concession against its plan section verbatim.
3. **Boundary file spot-check** beats full-diff scan. For session_store.py / firestore-boundary discipline: `for f in <S1 modules>; gh api contents | base64 -d | grep "from google.cloud import firestore"`. Fast and high-signal.
4. **Distinguish SDK-helper imports from data-path bypasses.** `firestore.transactional` decorator, `_fs.Query.DESCENDING` enum, version probe — fine. `db.collection("session-coll").stream()` — boundary violation.
5. **Wave grep against commit log** — confirms structure without diff scan.

## Concession audit — Viktor's a8a7300

- Fixup commit message itself was an audit-grade artifact: lists every test, plan task ID, root-cause hypothesis. Made my review faster.
- T.P1.11 shortcode reclassification: legacy test inverted forbidden-set; new contract puts shortcode in `_UPDATABLE_FIELDS`. Plan-aligned.
- T.P1.8 strict=True xfail with explicit "impl pending" tag is a textbook scope-shrink pattern.
- Smoke `T.P1.X follow-up` xfail with root-cause hypothesis in docstring needs a real ticket before prod flip.

## Anonymity scan trip

`scripts/post-reviewer-comment.sh` denylist caught Azir, Orianna, Heimerdinger, Akali in my draft. Replaced with role descriptors ("the standard plan-lifecycle path", "deploy + QA leads", removed `# azir: boundary` comment quote). Reposted clean.

**Lesson:** when quoting code comments containing agent names, paraphrase or redact the agent token before posting on work-scope. Better: compose work-scope reviews from scratch with role descriptors only.

## Drift note pattern

Single drift note (`GET /sessions` direct Firestore read in debug route) is the textbook output of god-PR fidelity review: one boundary nick from a hotfix, low-blast-radius, surface-but-don't-block. APPROVE-with-followup is the right verdict shape.

## Cross-ref

- `plans/in-progress/work/2026-04-21-demo-studio-v3-e2e-ship-v2.md` (orchestration; should promote to implemented post-merge)
- `plans/in-progress/work/2026-04-22-p1-factory-build-ipad-link.md` (T.P1.* task IDs)
- Memory line 21: work-concern reviewer-auth fallback path used here (post-reviewer-comment.sh under duongntd99).
