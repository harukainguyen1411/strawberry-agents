---
plan: plans/proposed/work/2026-04-22-demo-dashboard-service-split.md
checked_at: 2026-04-22T07:50:08Z
auditor: orianna
check_version: 3
claude_cli: present
block_findings: 0
warn_findings: 0
info_findings: 4
external_calls_used: 0
---

## Block findings

None.

## Warn findings

None.

## Info findings

1. **Step C — Claim:** HTTP route tokens on lines 30–34, 58–65, 129, 159 (e.g. `/dashboard`, `/healthz`, `/health`, `/auth/*`, `/session/*`, `/api/test-results`, `/test-dashboard`) contain `/` and are thus path-shaped per the extraction heuristic, but are clearly HTTP route references in prose context, not filesystem path claims. The top-of-file blanket comment (line 21) documents this intent. | **Severity:** info (not a repo-path claim under C2)
2. **Step C — Claim:** `dashboard.mmp.tech`, `*.run.app` on line 158 — hostnames / DNS wildcards, not filesystem paths or allowlisted integration names. Appear in speculative/deferred context ("Deferred — not in this plan's scope."). | **Severity:** info
3. **Step A — Frontmatter:** all four required fields present (`status: proposed`, `owner: sona`, `created: 2026-04-22`, `tags: [...]`). `orianna_gate_version: 2` declared; `concern: work` routing active. | **Severity:** info (clean pass)
4. **Step D — Sibling files:** no `2026-04-22-demo-dashboard-service-split-tasks.md` or `-tests.md` found under `plans/`; `## Tasks` and `## Test plan` already inlined per §D3. | **Severity:** info (clean pass)

## External claims

None. No versioned library pins, URLs, or RFC citations in the plan body trigger Step E. Library names (`FastAPI`, `uvicorn`, `google-cloud-firestore`, `firebase-admin`, `httpx`, `itsdangerous`, `jinja2`, `pillow`) appear without version constraints inside lines carrying `<!-- orianna: ok -->` markers or in prose contexts where Step E's trigger heuristic (version / URL / RFC) does not fire.
