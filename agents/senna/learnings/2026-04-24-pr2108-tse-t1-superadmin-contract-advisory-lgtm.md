# PR #2108 (missmp/tse) — T1 SuperAdmin invite contract stub — advisory LGTM

## Verdict
Advisory LGTM on `api/v3/superadmin_invites.go` (contract-only). Posted as `gh pr comment` (work-scope protocol), signed `-- reviewer`.

Review URL: https://github.com/missmp/tse/pull/2108#issuecomment-4312611582

## Findings summary
- **Critical:** none.
- **Important:** none blocking T1.
- **Suggestions for T3 (non-blocking):**
  1. `reason` field contract/audit ambiguity — request carries it, audit field-set omits it, plan §A.1 omits it. T3 must pick: log reason or drop it from the type.
  2. `previousRole` null-vs-empty asymmetry — `*string` → JSON `null`, audit → `""`. Helper recommended.
  3. No struct-tag validation — correct for repo idiom (CUE-based), but T3 handoff should name the validation mechanism explicitly.
  4. `echo.HeaderXRequestID` requires request-ID middleware registered before the superadmin group — verify in T3.

## Rule 18(a)
16/17 checks green. `snapshot-test` FAILED on Docker Hub 502 (infra flake pulling `python:3`) — not code-related; rerun should clear. Could not inspect branch-protection `required_status_checks` from outside admin; merging agent must verify.

## Branch hygiene concern (flagged, out of Senna scope)
PR branch `feat/superadmin-invite-user-to-org` is `ahead_by: 4, behind_by: 24` from main and carries three unrelated commits:
- pass HTML renderer (2026-04-07)
- CUE discriminated-union type field (2026-04-17)
- CUE refactor to flat struct (2026-04-17)

Plus the actual T1 contract commit `fbed7f90c`. ~1,200 LOC of unrelated code in a "contract-only" PR. Flagged for rebase before T2/T3 stack.

## Process notes
- `gh auth switch --user duongntd99` + `gh pr comment` (not `gh pr review`) — work-scope reviewer protocol worked as documented.
- `gh api .../branches/main/protection` returned 404 — no admin scope on duongntd99 token; cannot enumerate required checks. Honest "verify externally" is the right move.
- Kept review narrow to `superadmin_invites.go` per Sona's scope; noted other-file inclusion as branch-hygiene flag not a review gate.

## Reusable heuristic for contract-only PRs
For contract/stub PRs:
1. Confirm request/response types match JSON body spec verbatim.
2. Verify constants set is closed (no outside-spec values).
3. Walk the comment doc top-to-bottom for drift between prose and types (this is where the `reason`/`previousRole` mismatches surfaced).
4. Check handler signature against 2-3 sibling handlers in the same package — picks up "is this the repo idiom" instantly.
5. Panic stub is good; silent-return stubs are a smell.
