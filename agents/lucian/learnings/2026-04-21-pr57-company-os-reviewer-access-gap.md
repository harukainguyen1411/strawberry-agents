# PR #57 company-os — reviewer bot access gap + S3 plan fidelity

**Date:** 2026-04-21
**Repo:** `missmp/company-os` (work concern, first Lucian review there)
**PR:** https://github.com/missmp/company-os/pull/57
**Plan:** `plans/in-progress/work/2026-04-21-s3-project-reuse-and-s4-trigger.md`

## Key finding — infra gap

`strawberry-reviewers` bot identity (lane default in `scripts/reviewer-auth.sh`) is
NOT a collaborator on `missmp/company-os`. `scripts/reviewer-auth.sh gh api repos/missmp/company-os`
returns 404. Also `gh pr review --comment/--approve` fails with
"Could not resolve to a Repository".

Workaround used: post as a regular PR comment via default `gh pr comment`
(authenticates as `duongntd99`, the PR author). Plain comments on one's own
PRs are allowed; formal reviews are not. This means **no distinct reviewer
identity on work-concern PRs** — both Lucian and Senna have to degrade to
PR comments until the reviewer bot is granted access to `missmp/company-os`.

**Follow-up for Sona:** grant `strawberry-reviewers` + `strawberry-reviewers-2`
collaborator access to `missmp/company-os` (or add a work-lane token). Without it,
Rule 18's "one approving review from an account other than the PR author"
can't be satisfied by agent reviewers on work PRs.

## S3 PR review verdict — comment-only

53 commits on the branch, only last 3 are S3 scope (Duong pre-accepted). Audit
restricted to `94f9013` xfail / `f861dfd` impl / `5d9f57b` flip. All plan tasks
T.S3.1–T.S3.8 accounted for. Two drift notes:

1. **Option A contract pick** — plan assumed a single `/build` to extend but
   existing code had SSE `POST /v1/build`. Agent shipped new non-streaming
   `POST /build` alongside. Reasonable reading of the plan; amend plan wording
   at close-out.
2. **S4 retry delays `[1, 2, 4]`** — third value unreachable because guard
   `if attempt < len(delays)` prevents post-attempt-3 sleep. Operationally
   correct (2 sleeps between 3 attempts) but the plan text "1s/2s/4s back-off"
   implies 3 sleeps. Clarify in code comment or prune to `[1, 2]`.

One follow-up surfaced: in-memory `_projects` / `_builds` / `_build_events`
dicts should be Firestore per plan §Decision. Plan §Open questions item 1
explicitly listed `demo-factory-projects` collection name as open. PR body
tracks this as an unchecked box. Acceptable as a follow-up task.

Rule 12 compliant (xfail-first strict); xfail reason strings reference plan
slug; conventional `test(demo-studio-v3):` / `feat(demo-studio-v3):` commit
prefixes. Architectural out-of-scope (S1/S4/Wallet-Studio internals, UI)
honoured — diff is confined to `tools/demo-factory/`.

## Process note

Default Lucian verdict on first contact with a new repo should verify reviewer
bot access (`scripts/reviewer-auth.sh gh api repos/<owner>/<repo>`) BEFORE
drafting the review body — saves rewriting the posting path.
