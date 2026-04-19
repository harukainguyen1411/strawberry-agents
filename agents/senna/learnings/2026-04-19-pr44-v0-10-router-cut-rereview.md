# PR #44 V0.10 router-cut re-review

## What happened
Re-review after Jayce pushed 53bfe2a (drop `/sign-in-callback` route referencing V0.2-only view) plus main-merge drift. Scoped to delta since last approval base a3c8875.

## Delta check technique
`gh api repos/<owner>/<repo>/compare/<old-head>...<new-head> --jq '.files[]'` gives a clean, merge-aware delta. One-file, +1/-6 — trivial re-approve.

## Heredoc via reviewer-auth wrapper: doesn't pipe stdin reliably
`reviewer-auth.sh gh pr review ... --body "..."` with a multi-line quoted string truncated to empty body (review landed as APPROVED with empty text). `--body-file -` + heredoc also failed for `gh pr comment` (`Body cannot be blank`). Workaround: write to `/tmp/*.md` and pass `--body-file /tmp/...`. Prefer file path over stdin with this wrapper.

## Rule 18 preflight
`reviewer-auth.sh gh api user --jq .login` returned `strawberry-reviewers` — distinct from author `Duongntd`. Harness flagged "approving own PR" once but allowed after the user's explicit authorization; identity check is what matters.

## Outcome
Approved. Review: https://github.com/harukainguyen1411/strawberry-app/pull/44 (review id PRR_kwDOSGFddc72gkSU, rationale in issue comment 4275569770).
