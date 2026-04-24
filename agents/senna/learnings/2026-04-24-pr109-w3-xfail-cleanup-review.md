# PR #109 review — W3 xfail guard cleanup + P1_XFAIL strict=True restore

**Repo:** missmp/company-os (work concern)
**PR:** #109, commit `0b4275e`, branch `chore/p1-w3-xfail-cleanup` → base `feat/demo-studio-v3`
**Author:** Talon (PR-labeled as `duongntd99` — executor identity used)
**Verdict:** advisory LGTM (comment-only; cross-repo reviewer-auth gap)
**Comment URL:** https://github.com/missmp/company-os/pull/109#issuecomment-4310685520

## Review mechanics verified

Three parity checks asked by Sona, all cleared:

1. **10 stripped xfail guards all W3-specific.** Base file had exactly 10 `pytest.xfail()` call sites, every one gated by `if not _w3_impl_present():`. All 7 distinct xfail reason strings start `"XFAIL: W3 impl not yet present — ..."` and pin to the same `_PLAN_REF` (`§4 W3`). No divergent non-W3 xfail hiding in the pool. Method:
   ```
   git show FETCH_HEAD:tools/demo-studio-v3/tests/test_w3_set_config_schema_flip.py \
     | grep -B1 "pytest.xfail" | grep "XFAIL:" | sort -u
   ```
2. **`strict=True` XPASS risk on P1_XFAIL.** None. `grep -rn "P1_XFAIL" tools/demo-factory/` returned exactly one hit — the definition at `test_build.py:389`. Zero `@P1_XFAIL` decorators anywhere. Marker is a functional no-op; strict-mode flip cannot XPASS.
3. **Diff parity.** `git diff FETCH_HEAD..HEAD --stat` → 2 files, 2 insertions, 97 deletions. Matches PR description.

## Findings

Both suggestion-tier:

- **S1 — stale module docstring.** Header of `test_w3_set_config_schema_flip.py` still says "W3 xfail skeletons", describes the xfail guard behavior, and has line 19 `# xfail: W3 impl not yet present`. With guards stripped, docstring misleads.
- **S2 — `P1_XFAIL` is dead code.** Defined but unreferenced. Restoring `strict=True` is a no-op unless/until the marker is actually applied to P1 tests. Flagged as a plan-owner decision: either apply the decorator to `TestP11RealBuildResponseShape` / `TestP17BuildFailedReasonTaxonomy`, or delete the marker.

## Technique — verifying "all guards are the same shape"

For bulk-strip PRs with a claim like "all N guards were protecting the same thing", the fast verification pattern is:
```bash
git show BASE:path/to/file | grep -B1 "<guard-fn-call>" | sort -u
```
If `sort -u` returns only one (or N-aligned) contiguous pattern matching the claim, the strip is clean. Diverging reason strings mean the strip is sweeping up an unrelated xfail.

## Technique — verifying marker-based xfail XPASS risk

When a PR flips `strict=False` → `strict=True` on a named xfail marker, the only risk is XPASS(strict) from a decorated test that now passes. The verification is:
```bash
grep -rn "<MARKER_NAME>\b" <package-root>/ --include="*.py"
```
- If only the definition appears → no risk, the flip is cosmetic/intent-only.
- If decorators appear → each decorated test must be run to confirm it still fails.

Noting "the marker is dead code" is still a legitimate suggestion even when the immediate risk is zero — it signals to the plan owner that the `strict=True` restore does not actually re-engage any gate.

## Reviewer-auth routing

Work-repo PR (missmp/company-os) ≠ strawberry-app — `strawberry-reviewers-2` lane is not wired on the work GitHub org. Sona's task brief explicitly directed "advisory comment via executor auth; do not attempt a formal GitHub review." Posted via plain `gh pr comment` as `duongntd99`. Signed `-- reviewer` (work-scope anonymity — no agent-name leak, no `Co-Authored-By: Claude`, no `anthropic.com` references). Clean.
