# PR #48 — T-new-D canonical start.sh (REQUEST_CHANGES)

**Date:** 2026-04-25
**Concern:** personal
**Author:** Ekko (executor)
**Lane:** Senna (code-quality + security)
**Verdict:** REQUEST_CHANGES
**Review:** https://github.com/harukainguyen1411/strawberry-agents/pull/48#pullrequestreview-4175072577

## What I caught (critical)

PR rewrites `mcps/slack/scripts/start.sh` to the §4.2 canonical `tools/decrypt.sh --exec`
single-secret pattern. Plan §4.2 + T-new-B classify Slack as single-secret (`SLACK_USER_TOKEN`
only). **But the work-vs-personal MCP confusion bites:** `mcps/slack/` in `strawberry-agents`
(personal repo) is the personal Slack MCP — its `tokens.ts::loadTokens()` requires BOTH
`SLACK_BOT_TOKEN` AND `SLACK_USER_TOKEN` and throws `MissingTokenError` if either is missing.
T-new-B's "single-secret" classification is for the *work-side* Slack MCP at
`~/Documents/Work/mmp/workspace/mcps/slack/`, which is a different codebase (FastMCP/Python).

The new start.sh injects only `SLACK_USER_TOKEN`. So even after P1-T2 creates the user-token
blob, the personal MCP will throw at boot. The PR description's "fail until P1-T2" framing
hides a deeper failure: this MCP is multi-secret and should be gated on T-new-C, not T-new-D.

## Class-of-bug to remember

Whenever a plan classifies an MCP by `secret count`, **check WHICH copy of the MCP that
classification was based on**. T-new-B's inventory was authored against the work-side
codebase. If the PR modifies a same-named MCP in the personal repo, re-derive the secret
count from the personal repo's actual server code, not the inventory table.

For Slack specifically: personal-repo `mcps/slack/` consumes 2 tokens (bot + user). The
work-side server consumes 1 (user only). Same name, different contracts.

## What checked clean

- `bash -n` syntax pass on new start.sh.
- All 6 structural tests pass on impl commit.
- `cd "$REPO_ROOT"` + relative paths + `< "secrets/work/encrypted/...age"` stdin redirect
  ordering is correct — exec inherits stdin from parent post-cd.
- Gitignore reorder works empirically: tested in `/tmp/gi-test` with a fresh repo —
  `.gitkeep` is tracked, runtime env files ignored, `*.age` blobs tracked. The
  `!secrets/work/runtime/` un-ignore + content-pattern + `!.gitkeep` exception precedence
  resolves correctly.
- No `$(...)` capture of secrets anywhere.
- `npm install` runs strictly before `exec`; `set -e` aborts on failure cleanly.
- `decrypt.sh` `--target` prefix-check resolves correctly when runtime dir exists
  (first branch of the case-glob).
- Bash-portability Rule 10 exempt — ADR §1 calls this out for MCP `start.sh` files.

## Important findings (non-blocking)

- **Xfail-first technically met but weak:** xfail commit had 1 active `it.fails` (which
  inverts to GREEN against old start.sh) plus 5 `it.skip` placeholders. Cleaner pattern
  for downstream P1-T2..T16: convert all 6 tests to `it.fails` at the xfail commit, then
  flip all 6 to `it` in the impl commit. Then every contract assertion is provably exercised
  red against old code.
- **Regression-guard regex too narrow:** `/\$\(grep.*TOKEN/` catches the exact old pattern
  only. Generalize to `/\$\([^)]*TOKEN[^)]*\)/i` to catch any future `$(...)` token capture.

## Plaintext-on-disk residual

`tools/decrypt.sh` writes `secrets/work/runtime/slack.env` (chmod 600) before exec'ing the
runner. After exec, no trap can fire — file lingers until next start. Documented in ADR §4.2
as accepted residual; flag for downstream MCP authors that a `trap` in start.sh cannot help
post-exec.

## Identity / process

- Posted as `strawberry-reviewers-2` via `scripts/reviewer-auth.sh --lane senna`.
- Personal-concern → reviewer-auth.sh path (not post-reviewer-comment.sh).
- Verdict: CHANGES_REQUESTED.

## Reusable probes

- **Empirical gitignore test:** copy `.gitignore` to `/tmp/<dir>`, `git init`, touch the
  candidate paths, `git add -A`, `git status --short` — the staged set is the ground truth
  for what tracking pattern resolution does. `git check-ignore -v` output for `!`-prefixed
  patterns is misleading (shows the rule that matched but doesn't tell you whether it ignored
  or un-ignored — only `git status` does that cleanly).
- **MCP server token contract:** `grep -rn 'process.env.\|os.environ' mcps/<name>/src/` is
  the fastest way to ground-truth a "single-secret vs multi-secret" claim against the actual
  server code, independent of the plan's inventory.
