---
plan: plans/proposed/personal/2026-04-21-commit-msg-no-ai-coauthor-hook.md
checked_at: 2026-04-21T12:54:15Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 1
warn_findings: 0
info_findings: 9
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `scripts/hooks/commit-msg-no-ai-coauthor.sh` (line 29, §2 Decision: "Add `scripts/hooks/commit-msg-no-ai-coauthor.sh`, wire it via `install-hooks.sh`, ...") | **Anchor:** `test -e scripts/hooks/commit-msg-no-ai-coauthor.sh` | **Result:** not found (proposed new file; mention is un-suppressed in Decision prose) | **Severity:** block. Fix: append `<!-- orianna: ok -->` to line 29 to mark the proposed-creation reference explicitly, matching the Tasks §1/§2 pattern already in place.

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** `status: proposed`, `owner: karma`, `created: 2026-04-21`, `tags: [hooks, git, ai-attribution, enforcement, commit-msg]` all present and valid | **Severity:** info.
2. **Step B — Gating questions:** no `## Open questions`, `## Gating questions`, or `## Unresolved` sections present; no unresolved markers | **Severity:** info.
3. **Step C — Claim:** `scripts/install-hooks.sh` (lines 25, 64) | **Anchor:** `test -e` passes | **Severity:** info.
4. **Step C — Claim:** `scripts/hooks/` (line 25), `scripts/hooks/tests/` (line 77), `scripts/hooks/test-hooks.sh` (line 77) | **Anchor:** `test -e` passes | **Severity:** info.
5. **Step C — Claim:** `architecture/key-scripts.md` (lines 29, 63) | **Anchor:** `test -e` passes | **Severity:** info.
6. **Step C — Claim (author-suppressed):** `scripts/hooks/tests/commit-msg-no-ai-coauthor.test.sh` (line 60, Task 1) | **Anchor:** `<!-- orianna: ok -->` on line | **Severity:** info (author-suppressed; proposed new file).
7. **Step C — Claim (author-suppressed):** `scripts/hooks/commit-msg-no-ai-coauthor.sh` (lines 60–62 Tasks §1, §2, §3 and §I5) | **Anchor:** `<!-- orianna: ok -->` on each line | **Severity:** info (author-suppressed; proposed new file).
8. **Step C — Claim:** `install-hooks.sh` (bare filename, line 29) — path-shaped (`.sh` extension) but no prefix | **Result:** unknown path prefix; resolved by context to `scripts/install-hooks.sh` which exists | **Severity:** info.
9. **Step C — Claim:** `commit-msg-*.sh` (line 25, glob pattern); `#!/usr/bin/env bash` (line 61, shebang); `pre-compact-gate.test.sh` (line 77, bare filename referring to existing `scripts/hooks/tests/pre-compact-gate.test.sh`) | **Result:** unknown-prefix / non-resolvable tokens; not load-bearing | **Severity:** info.
10. **Step D — Sibling files:** no `2026-04-21-commit-msg-no-ai-coauthor-hook-tasks.md` or `-tests.md` siblings found under `plans/` | **Severity:** info (clean).

## External claims

None. (Step E trigger heuristic did not fire: no URLs, no named SDKs/frameworks/versions, no RFC citations. The "Claude Opus 4.7 1M context" and "anthropic.com" strings appear only as meta-examples of the exact trailer being blocked, not as factual claims about library behavior.)
