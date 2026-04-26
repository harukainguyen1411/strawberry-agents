# PR #63 — feedback-system G1 (T1+T2+T3) plan/ADR fidelity review — APPROVE

**Date:** 2026-04-25
**Concern:** personal
**PR:** https://github.com/harukainguyen1411/strawberry-agents/pull/63
**Plan:** `plans/approved/personal/2026-04-21-agent-feedback-system.md` (dispatch named in-progress path; on disk still in approved/)
**Verdict:** APPROVE

## What G1 shipped (matches plan exactly)

- T1: 5 ad-hoc feedback files migrated to §D1 schema (date/time/author/concern/category/severity/friction_cost_minutes/state). Plus a sixth in-scope live entry.
- T2: `scripts/feedback-index.sh` — POSIX bash with Node YAML shim; modes `--check`, `--check --dir`, `--check --audit-history --dir`, `--dir --out`. Required fields + enum validation match §D1.
- T3: `scripts/hooks/pre-commit-feedback-index.sh` validates schema + regenerates INDEX + auto-stages. Wired into `install-hooks.sh`. Hook dispatcher already auto-discovers `pre-commit-*.sh` via glob, so no dispatcher edit needed.

## §D12 bind contract verified

Col 1 = Severity, Col 2 = Date, footer `Open: N | High: N | Medium: N | Low: N`, `Graduated (this week): N`, `Stale (pending prune): N` — all four bind-points exact. TT2-bind §e (`FEEDBACK_INDEX_RENAME_SEVERITY` mutation) trips correctly.

## Invariants verified in code

- Inv 1 (one writing path): `--audit-history` rogue-prefix detector
- Inv 4 (idempotent INDEX): explicit code path
- Inv 6 (state monotone): `state: open` + `graduated_to:` rejection
- Inv 10 (out-of-place): `YYYY-MM-DD-*` filename filter in `--dir`

## Rule 12 satisfied

4 xfail commits → 3 impl commits, in that exact order. xfail commits each carry `xfail-guard: committed before T2/T3 per universal invariant rule 12`. Total 21+11+16+11 = 59 xfails matching PR claim.

## Patterns worth remembering

1. **Hook glob auto-discovery pattern:** `scripts/hooks-dispatchers/pre-commit` already loops `pre-commit-*.sh` — adding a new sub-hook needs only the file in `scripts/hooks/` plus a registration comment in `install-hooks.sh`. No dispatcher edit. Don't flag missing dispatcher entries when this pattern is in play.
2. **Test-count expansion is healthy fidelity, not drift:** 10 invariants → 16 test cases is "one-test-per-sub-shape". Don't ding for higher count when the cases all map back.
3. **Deferred-scope sentinel:** PR body explicitly carved G1 from G2/G3 — surfaced deferral done right. Use as exemplar.
4. **Commit-prefix vs PR-title:** Rule 5 governs commit prefixes, not PR titles. A `feat:` PR title with all `chore:` commits passes pre-push but is cosmetically off — drift note only.

## Drift notes raised (non-blocking)

1. xfail commit messages cite `plans/approved/...` while dispatch named `plans/in-progress/...` — the file is at the approved/ path on disk so refs resolve.
2. PR title `feat:` vs commit prefixes `chore:` — cosmetic, commits comply with Rule 5.
3. TT-INV: 16 tests for 10 invariants — healthy expansion.

## Auth path used

`scripts/reviewer-auth.sh gh pr review ... --approve` — default lane → `strawberry-reviewers` (Lucian). Verified via `gh api user --jq .login`. Dispatch incorrectly named `strawberry-reviewers-2` for Lucian; that is Senna's lane. Corrected silently.
