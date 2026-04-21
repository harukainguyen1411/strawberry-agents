## Session 2026-04-21 (S65, cli, direct)

Azir god-plan demo-studio-v3 ship day. Three services deployed to GCP (S1/S3/S5). Viktor Wave 2 (PR #61) complete with Talon hotfix for SSE auth + MCP validation. Playwright MCP wired to Akali/Rakan/Vi. Swain Option B plan (vanilla Messages API) authored and promoted to in-progress. Akali live QA in flight at session end.

### Delta notes for consolidation

- **GCP deploy live:** S5 `00006-57w`, S3 `00007-qjd` (`PROJECTS_FIRESTORE=1`), S1 `00016-5rw` (`MANAGED_AGENT_MCP_INPROCESS=1`, `S5_BASE=...`). No real stg env — single GCP project, Firestore `demo-studio-staging` is the stg analogue.
- **Talon critical fixes on #61:** C1 = SSE auth (`session_logs_sse` must use FastAPI Cookie DI, not call `require_session` directly); C2 = MCP session_id regex validation ported from server.ts.
- **Playwright MCP video:** no `--save-video=on` always-on flag. Video via `browser_start_video`/`browser_stop_video` tools; agent must invoke explicitly. Wired to Akali/Rakan/Vi frontmatter.
- **Syndra co-author third incident:** force-amended, def patched. Agent caching means patch only effective on fresh session spawn. Add prohibition line to every Syndra commit prompt until hook lands.
- **D1A discipline held:** Aphelios tasks + Xayah tests inlined into Swain Option B parent ADR body. Sibling files deleted. Required full demote/re-sign/re-promote cycle due to body hash change — expected pattern.
- **Reviewer-access gap persists:** `strawberry-reviewers` lacks access to `missmp/company-os`. Lucian review posted as comment-only (no approve/request-changes). Senna review same constraint. Duong must approve directly.
- **Pre-orianna-plan-archive plan:** flagged for retroactive sign + promote from proposed → implemented (PR #14 already shipped the content).
