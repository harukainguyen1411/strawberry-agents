---
plan: plans/proposed/personal/2026-04-21-commit-msg-no-ai-coauthor-hook.md
checked_at: 2026-04-21T12:56:56Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 1
warn_findings: 0
info_findings: 8
external_calls_used: 0
---

## Block findings

1. **Step C — Claim:** `scripts/hooks/commit-msg-no-ai-coauthor.sh` (cited on line 63, Task 4 detail, without suppression marker) | **Anchor:** `test -e scripts/hooks/commit-msg-no-ai-coauthor.sh` | **Result:** not found | **Severity:** block. This path is cited without a `<!-- orianna: ok -->` marker on line 63, whereas the same path is correctly suppressed on lines 29, 60, 61. Add the suppression marker to line 63 (the Task 4 "Add a row for …" sentence), since the file is being created by this plan and does not yet exist on disk.

## Warn findings

None.

## Info findings

1. **Step A — Frontmatter:** `status: proposed` present and valid.
2. **Step A — Frontmatter:** `owner: karma` present.
3. **Step A — Frontmatter:** `created: 2026-04-21` present.
4. **Step A — Frontmatter:** `tags: [hooks, git, ai-attribution, enforcement, commit-msg]` present.
5. **Step C — Path (author-suppressed via `<!-- orianna: ok -->`):** `scripts/hooks/commit-msg-no-ai-coauthor.sh` on lines 29, 60, 61; `scripts/hooks/tests/commit-msg-no-ai-coauthor.test.sh` on line 60; `install_dispatcher "commit-msg"` on line 62.
6. **Step C — Path anchor confirmed:** `scripts/install-hooks.sh`, `scripts/hooks/pre-commit-secrets-guard.sh`, `architecture/key-scripts.md`, `scripts/hooks/test-hooks.sh`, `scripts/hooks/tests/pre-compact-gate.test.sh`, `agents/syndra/learnings/` all resolve under `test -e`.
7. **Step C — Unknown path prefix:** `.git/hooks/commit-msg` (line 62 DoD) uses `.git/` prefix, not in routing table. Add to contract if load-bearing; otherwise informational.
8. **Step D — Sibling files:** no `-tasks.md` or `-tests.md` sibling files found; one-plan-one-file rule satisfied.

## External claims

None. (Step E trigger heuristic did not fire — no named library/SDK/framework, version number, URL, or RFC citation in the plan body. POSIX bash / `grep -iE` / git hooks are implicit-tool references handled by Step C.)
