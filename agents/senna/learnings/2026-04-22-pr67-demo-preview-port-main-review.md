# PR #67 demo-preview port-main review — Senna learnings
Date: 2026-04-22
Session: S41
Repo: missmp/company-os
PR: #67 (fix(demo-preview): port origin/main server.py, wire /preview, brand-correctness)
Base: feat/demo-studio-v3 / Head: feat/demo-preview-port-main
Verdict: ADVISORY LGTM (non-blocking important items)

## Context
Yesterday a colleague accidentally deployed origin/main's `server.py` to the preview Cloud Run service, which ironically fixed the "every session renders Allianz" bug because main.py on the feat branch had a hardcoded-Allianz stub. This PR is the correct-direction resolution per Karma plan: port main's real 550-LOC stdlib + Jinja2 server.py onto feat, restore /fullview + CORS, fix studio.js paths (/v1/preview/ → /preview/ per api-spec), add a branch-check deploy guard. 4 commits, +5673/−352, 31 files. Rule 12 chain clean (c1c6590 xfail → 07a0764 port → f72aaab /fullview+CORS → 0a75d35 studio.js+guard+flip).

## Verdict mechanism
Posted to /tmp/senna-pr-67-verdict.md per task-brief contingency. Reviewer-auth lane `strawberry-reviewers-2` still has no missmp/* access (S27 gap, now 11 consecutive sessions). Yuumi to post as comment under duongntd99.

## Findings summary
- Critical: 0
- Important: 5 (IMP-1 port number drift across 3 files; IMP-2 /fullview drops ?v= cache-bust; IMP-3 log_message override loses status+size; IMP-4 400s unlogged; IMP-5 deploy guard is branch-name only, misses dirty-tree + unpushed-HEAD class of same incident)
- Suggestions: 7
- What's right: 8 items (Allianz root cause actually fixed, Rule 12, regex defense-in-depth, /fullview routing order, static path traversal, hmac compare_digest, startup fail-closed, surgical studio.js)

## New patterns codified (added to memory)

1. **Port-plus-additions review structure**: when a PR ports an older file onto a newer branch AND adds surgical changes on top, fence scope to commits-on-branch and scrutinize the additive delta much harder than the mechanical port body. The port is audited against `git show origin/main:path`; the additions are where new bugs enter.

2. **Port number triple-alignment smell**: whenever three places define a port (Dockerfile ENV, server default in code, api spec file) they drift silently. Grep all three every time. Here: 8080 / 8090 / 8004. Container wins via Cloud Run injection, but local dev gets 8090 while spec says 8004 — confusion is guaranteed.

3. **Branch-name-only deploy guard is the weakest of three defenses**: the same "wrong version deployed" incident class has at least three orthogonal triggers — (a) wrong branch checked out, (b) dirty worktree with uncommitted changes, (c) local HEAD not matching origin (unpushed commit). Guard (a) alone addresses one of three. Both (b) and (c) are one-liner `git diff --quiet`/`git merge-base --is-ancestor` additions. Always suggest the other two.

4. **`log_message` override check**: for any stdlib `http.server` subclass, when `log_message` is overridden, grep how many positional args it consumes. Dropping `args[1:]` is a silent observability regression — status codes and response sizes disappear. `f"  {args[0]}"` also raises IndexError if the handler ever invokes log_message with no args.

5. **400s should log, too**: in `_respond_error`-style helpers that gate log emission on status code, excluding 400s from logging is a security observability miss — regex-rejected session_ids are exactly the enumeration/injection probe signal you want captured. Especially when the log buffer is Bearer-gated (so no cross-origin exposure concern).

6. **Regression-test template-grep proof**: for hardcoded-value-bug regression tests that use `assert BAD_VALUE not in html`, grep the rendered template (and any static assets referenced by default fixtures) for the BAD_VALUE string. Here: 0 hits of "Allianz" in preview.html; `allianz-*.svg` files exist in static/logos/ but fixture sets logos.{wideLogo,squareLogo}="" so they never land in the body. Test is non-vacuous.

## Reviewer-auth missmp gap — 11 consecutive sessions
Still unresolved since S27 (2026-04-21). `strawberry-reviewers-2` lane has no access to missmp/* GraphQL (returns "Could not resolve to a Repository"). Work-concern PR reviews continue to post via default identity (duongntd99) as comment-only, which leaves the lane-separation structural fix from PR #45 unusable for this repo. Worth prioritizing with Sona — this is the 6th+ week of the gap and blocks formal CHANGES_REQUESTED / APPROVED state on every work-concern PR.

## Cross-agent signal
- Spec drift (`/fullview`, `/health` not in api/preview.yaml) surfaced as S6 for Lucian's plan-contract lane, not mine.
- The `--no-allow-unauthenticated` Cloud Run IAM vs spec saying "unauthenticated — publicly accessible" is a pre-existing inconsistency, also Lucian's lane.
