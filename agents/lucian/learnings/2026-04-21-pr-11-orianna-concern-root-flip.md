# Lucian learnings — PR #11 Orianna concern-based resolution root flip

**Date:** 2026-04-21
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/11
**Plan:** `plans/in-progress/work/2026-04-21-orianna-claim-contract-work-repo-prefixes.md`
**Verdict:** Approve

## Key findings

1. **Plan fidelity was clean across all four tasks.** Task 1 xfail test (Rule 12), Task 2 env-var rename + root flip with backward-compat alias, Task 3 Step-C prompt rewrite, Task 4 §5 contract rewrite — every DoD satisfied, including the `resolution root` grep target and cross-surface opt-back list equality.

2. **Verified XFAIL discipline at commit granularity.** Pulled the pre-impl commit (1955263) and impl commit (e0b7ba8) separately via `gh api repos/.../commits/<sha>` to confirm the XFAIL sentinel was present pre-impl and removed post-impl. The test file in the xfail commit has a `if [ "$FAIL" -gt 0 ]; then printf 'XFAIL...'; exit 0; fi` guard; the impl commit replaces it with `[ "$FAIL" -eq 0 ]`. This is the textbook shape for Rule 12 and should be the template pattern to cite in future reviews.

3. **The plan itself had a factual error, and Talon quietly corrected it in the test.** Plan §Context and §I1 both cite `tools/demo-studio-v3/session_store.py` — the file doesn't exist and the real workspace layout puts demo-studio-v3 under `company-os/tools/demo-studio-v3/`. Talon substituted `company-os/tools/demo-studio-v3/agent_proxy.py`. Lesson for me: when a plan deviation is flagged by the delegation prompt, check whether the plan or the PR is the one misaligned with reality. Here it was the plan.

4. **Orianna signed a plan with a factual inconsistency.** The v2 gate was introduced precisely to catch path-shaped tokens that don't resolve. The plan I reviewed cites paths that *don't exist in their stated form* (both `session_store.py` and the unprefixed `tools/demo-studio-v3/...`) — yet Orianna produced valid signatures at both approved and in_progress phases. Worth flagging to Duong / Evelynn: the Orianna gate on the *very plan that fixes Orianna path resolution* contains exactly the kind of error that motivated the plan. Drift note, not PR-blocking.

## Process notes

- `scripts/reviewer-auth.sh gh api user --jq .login` returned `strawberry-reviewers` pre-flight. Identity check always first.
- PR diff was 83KB; dumped to a tool-results file and read in ranges rather than fetching `--diff` a second time.
- `safe-checkout.sh` blocked because of an unrelated uncommitted file on main (strawberry-inbox-channel plan). I did NOT run tests locally — relied on CI green (`xfail-first check` and `regression-test check` both pass) plus reading the diff. Acceptable for a fidelity-only review; would need local runs for behavior-level claims.
