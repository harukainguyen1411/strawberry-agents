# PR #87 — S1 set_config PATCH->POST hotfix

**Date:** 2026-04-23
**Concern:** work
**Repo:** missmp/company-os (private)
**Verdict:** APPROVE (file-based fallback — reviewer identity 404'd on repo access)

## Key facts

- Deployed S2 (`demo-config-mgmt-00014-2bn`) returns 405 on `PATCH /v1/config/{sid}`.
- Hotfix replaces PATCH with GET + in-memory dotted-path mutation + POST /v1/config.
- No formal ADR — parallel rewrite at `plans/proposed/work/2026-04-23-agent-owned-config-flow.md`.
- Branch fix/s2-set-config-post → feat/demo-studio-v3 (god branch target, correct).
- Commits: b36b60b (xfail) → 19b07e2 (fix). Rule 12 compliant.
- 2 files, +303/-8, all under `tools/demo-studio-v3/`.

## Review process note

- `strawberry-reviewers` identity lacks access to private `missmp/company-os`: `gh api repos/missmp/company-os` → 404.
- Fallback: wrote verdict to `/tmp/lucian-pr-87-verdict.md` per task instructions.
- Remediation for future: Duong to grant `strawberry-reviewers` collaborator access, or use a different reviewer identity for work-concern PRs.

## Drift note logged (non-blocking)

Test file uses plain `assert` rather than `@pytest.mark.xfail(strict=True)` despite "xfail-first" commit framing. Rule 12 intent (xfail commit would fail if run against pre-fix code) is satisfied; letter is not. Future cleanup pass.

## Contract observation

The agent-owned config flow ADR is still in `proposed/`. Hotfixes to the demo-studio-v3 tool dispatch surface should preserve the current `{path, value}` tool-facing contract until that ADR lands. This PR does.
