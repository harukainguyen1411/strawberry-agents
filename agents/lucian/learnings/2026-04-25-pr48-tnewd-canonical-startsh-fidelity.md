# 2026-04-25 — PR #48 T-new-D canonical Slack start.sh fidelity review

## Context

`harukainguyen1411/strawberry-agents` PR #48, branch `chore/t-new-d-slack-canonical-start-sh`. Task T-new-D of `plans/approved/work/2026-04-24-sona-secretary-mcp-suite.md` — author the canonical `tools/decrypt.sh --exec` start.sh template, using Slack as the reference single-secret MCP. Author: Ekko (commits authored by Orianna identity on the worktree).

## Verdict

APPROVE. Personal-concern lane (`scripts/reviewer-auth.sh`, `strawberry-reviewers`).

## Fidelity verification approach

- Cloned shallow (`git clone --depth 5 --branch ...`) into `/tmp/pr48-review` to inspect actual files.
- Read §4.2 of the plan and walked the canonical template line-by-line against `mcps/slack/scripts/start.sh`. All four contract points (stdin redirect, `--target` runtime path, `--var SLACK_USER_TOKEN`, `--exec --` shell-replacing exec) match exactly.
- Verified xfail-first ordering via `git log` on the branch — `51843cd2` (xfail) precedes `29dbd9a9` (impl) by 83 seconds. xfail commit has one `it.fails(...)` regression guard plus five `it.skip(...)` markers describing the impl target. Impl commit converts skips → live tests and rewrites the `it.fails` into a now-passing regression guard. Clean Rule 12 compliance.
- Scope containment: no `tools/decrypt.sh` change (T-new-C clean), no `slack-user-token.age` creation or `.env` deletion (P1-T2 clean), only `mcps/slack/` touched plus the necessary `.gitignore` carve-out for the runtime dir.

## Drift items flagged (non-blocking)

1. `secrets/slack-bot-token.txt` plaintext still on disk — T-new-D doesn't delete it (correct, P1-T2's job), but the new start.sh references a non-existent `.age` blob, so Slack MCP will be down between T-new-D merge and P1-T2 land. PR body acknowledges this. Worth sequencing P1-T2 immediately after merge.
2. Two-token → single-token shape change: old start.sh set both `SLACK_BOT_TOKEN` and `SLACK_USER_TOKEN`; new one sets only the user token. Plan-sanctioned by T-new-B's inventory (Slack classified single-secret) but worth Senna verifying in-flight that `mcps/slack/src/server.ts` doesn't actually read `SLACK_BOT_TOKEN` at runtime.
3. `npm install` before `exec` — sensible non-secret design call, no fidelity concern.

## Lessons / patterns

- T-new-D pattern: "deliver script structure, defer ciphertext/cleanup to next task" is a clean way to break the secret-migration handshake into reviewable atomic PRs. The intermediate state (script references blob that doesn't exist) is a known temporary downtime window — call it out explicitly in the PR body so reviewers and the next executor sequence correctly.
- Reference-template tasks benefit from a copy-paste guide in the docstring (substitution recipe for env var name, blob path, runtime path, runner command). T-new-D's start.sh has a great example of this — worth referencing if Lucian reviews future template-style tasks.
- TDD pattern: `it.fails` for the explicit pre-impl divergence, `it.skip` for impl-target assertions, then impl commit flips skip → live and rewrites fails → regression guard. Clean two-phase.

## Cross-concern note

PR was in personal-concern repo (`harukainguyen1411/strawberry-agents`) implementing work-concern infrastructure (Sona's MCP suite). Reviewer auth is determined by repo, not by what the code does — personal-concern lane (`reviewer-auth.sh`) was correct.

## Review URL artifact

API confirmed: `strawberry-reviewers` posted `APPROVED` state on PR 48.
