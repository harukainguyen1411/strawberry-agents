---
date: 2026-04-24
topic: PR #117 review — gcloud deploy flag for min-instances
concern: work
repo: missmp/company-os
pr: https://github.com/missmp/company-os/pull/117
verdict: LGTM (advisory, non-blocking) — posted as PR comment
---

# PR #117 — `ops: add --min-instances=1 to demo-config-mgmt deploy`

## New protocol beat: work-scope reviews go via PR comment, not Review

- Duong introduced a new workflow today: on missmp/company-os PRs I review via
  `gh auth switch --user duongntd99` then `gh pr comment <N> --repo missmp/company-os -F <body>`.
- NOT `gh pr review` — actual approval is manual from `harukainguyen1411`.
- This is a deliberate split: reviewer (me, via duongntd99) posts a verdict comment;
  approver (Duong, via harukainguyen1411) clicks Approve. Rule 18 (b) cannot be
  satisfied by me on this workflow — only (a) is in my scope to assert.
- Do NOT use `scripts/reviewer-auth.sh --lane senna` on missmp/* repos. That script
  is strawberry-agents-repo-specific (strawberry-reviewers-2 identity).

## Review mechanics that worked

1. Pull diff + full file of changed script. A one-line diff hides nothing on its
   own, but reading the enclosing command confirmed the backslash continuation
   chain is still intact and that the new flag is not the last line (which would
   be a broken continuation).
2. Sanity-check PR body claims by hitting the API (directory listing confirmed
   no README/DEPLOY docs).
3. Rule 18 (a) sub-check: base was `feat/demo-studio-v3` (feature branch, no
   branch protection → no required checks). Vacuously satisfied. Called this out
   explicitly so the approver isn't surprised.

## Substantive review content

The real story on this PR is that `--min-instances=1` is a workaround, not a fix.
The root bug is in-memory-only S2 session state. Flagged this as a follow-up,
NOT a change-request — it's an emergency ship-blocker and the fix is correct
for the immediate goal. Over-scoping the PR would have been wrong.

## For next time

- Work-scope PR comments sign with `-- reviewer` (generic), never with an agent
  name. Did this correctly.
- Do not include `Co-Authored-By: Claude` or `*@anthropic.com` in comment bodies
  on missmp/*. Did this correctly.
- The `duongntd99` account is the reviewer identity for work PRs. Confirm with
  `gh auth status` before posting.
