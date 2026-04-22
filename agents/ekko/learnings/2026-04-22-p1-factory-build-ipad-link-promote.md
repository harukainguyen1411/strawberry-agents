# Learning: P1 Factory Build Plan Promote (proposed→approved)

Date: 2026-04-22

## Summary

Promoted `2026-04-22-p1-factory-build-ipad-link.md` proposed→approved with 3 sign iterations
(and 1 parallel-agent sign that landed first).

## Sign Loop

- **Iteration 1 (first sign):** Gate passed (0 blocks), sign committed at `2e18348`. Then I
  incorrectly proceeded to add suppressors AFTER signing, which invalidated the signature.
  The body must be final BEFORE signing.

- **Commit 8e14a83:** Added 26 suppressors for work-workspace path tokens (factory.py, main.py,
  sys.exit, demos/{slug}/.factory/, httpx.AsyncClient, content.logos.wordmark, apple.py/gpay.py/
  journey.py, colors.primary, logos.wordmark, outputUrls.demoUrl, static/studio.js, requirements.txt,
  factory_bridge_v2.py, session.py, tests/test_*, ops/cloud-run/, app.walletstudio.com,
  demo.missmp.tech, factory_build.py). Removed stale signature.

- **Commit 46168f3:** Changed `[ ]` to `[x]` on OQ-1 through OQ-7 (Orianna Step B fires on
  unresolved `?` + `[ ]` checkbox in the OQ section even if Pick is present).

- **Iteration 2 (second sign):** Gate passed (0 blocks), sign committed at `84afcac`. But a
  PARALLEL second orianna-sign.sh invocation (from the background job race) also ran and added a
  duplicate signature line at `645235c`. Removed duplicate at `3cef244`.

- **Commit 1d3aa1a:** Added 2 more suppressors found by plan-promote.sh's pre-commit hook
  (project.py in D4 section, static/studio.js section header in D5). plan-promote.sh runs
  lib-plan-structure on the PROMOTED (approved) copy, which can catch tokens the approved-phase
  gate missed. Must add suppressors in proposed copy first, then re-sign.

- **Parallel agent completion:** While I was iterating on the 4th sign, another sign commit
  (`0ffd686`) and promote commit (`dac5dad`) landed from a concurrent session. Final state clean.

## Key Learnings

1. **Sign body must be final before signing.** Any body edit after signing requires removing the
   stale sig field, committing, then re-signing. Do not edit plan body after a successful sign.

2. **OQ checkboxes matter.** Orianna Step B fires on `[ ]` + `?` in the OQ section even when
   `Pick:` is resolved. Change `[ ]` to `[x]` on all resolved OQs before signing.

3. **plan-promote.sh's pre-commit runs a SECOND hook pass** (lib-plan-structure) on the approved/
   destination copy with different behavior than the approved-phase gate. Tokens like `project.py`
   (bare filename, no company-os/ prefix) and section headers like `static/studio.js` may slip
   through the Orianna gate (classified C2b under work concern) but still block the promote commit.
   Run `bash scripts/fact-check-plan.sh` locally before signing to catch these.

4. **Parallel sign race:** Background orianna-sign.sh invocations can race and produce duplicate
   signature lines in frontmatter. Always run orianna-sign.sh synchronously (not backgrounded) to
   avoid this.

5. **Restore pattern before each sign:** Always `git restore --staged .` before calling
   orianna-sign.sh to prevent staging contamination from parallel agents.
