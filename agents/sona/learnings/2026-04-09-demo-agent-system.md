# 2026-04-09 — Demo agent system lessons

## Verify real data before mapping logic
Our first parity_check.py plan assumed semantic iOS field IDs (`header`, `primary`, `policy`, `holder`) and matching Google IDs. Ekko's field ID verification on project 10796 showed iOS uses positional IDs (`primary_1`, `header_1`, `secondary_2`) and Google uses UUIDs. Always run a one-shot recon on real project data before writing mapping code.

## Python import-time side effects block CLI flags
`factory.py --from verify` failed because `from research import research_brand` at module top loaded anthropic SDK eagerly, which authed against `ANTHROPIC_API_KEY` regardless of whether research would actually run. Lazy-import inside the step lambda fixes it. Watch for SDK modules that auth on import.

## Slack bot 3-second rule
Slack retries event webhooks if no 200 within 3 seconds. Bot was triple-responding because Gemini call was `await`ed synchronously before returning 200. Fix: (1) dedup by `event_id` in-memory, (2) ignore `X-Slack-Retry-Num` header, (3) schedule all heavy work via `BackgroundTasks`, return 200 immediately.

## Cloud Run env vars vs secrets are exclusive per key
Can't mix `--set-env-vars` and `--update-secrets` for the same key name. If a service was deployed with secrets and you want to switch to plain env vars, run `--clear-secrets` first, then `--update-env-vars`. But `--clear-secrets` also wipes any plain env vars set at the same time — add them back in a second update.

## Field ID mapping: label-based > ID-based
When three surfaces (iOS, Google, demo-UI) use different ID schemes for the same logical field, match by normalized label string (trim + casefold + collapse whitespace) instead of IDs. Support an explicit override map (`parity_map.json`) as escape hatch.

## Google Wallet class types are immutable
You can't PATCH a project from offerClass to genericClass — the class type is fixed at creation. TSE has a dedicated endpoint `POST /v3/projects/{id}/gpay-class-style` that creates a new class and re-links the project, and there's a tested migration script at `tse/cmd/scripts/switch-project-google-offer-to-generic/`. Use that, don't try to PATCH.

## Generic class listTemplateOverride needs object.* paths
When migrating offer→generic, `classTemplateInfo.listTemplateOverride` must be rewritten: `class.localizedTitle` → `object.header`, `class.localizedIssuerName` → `object.cardTitle`. The cardTemplateOverride references to `object.textModulesData[uuid]` can stay as-is.

## Subagent tool permissions vary
Azir doesn't have Write/Edit (read-only research agent). When delegating file-writing tasks, pick agents with the right tool set (Ekko, Jayce, Viktor, Camille have write). Check by looking at the agent's frontmatter `tools` list.

## Local dev launcher scripts beat terminal paste
Complex multi-line shell commands break when pasted into terminals (line wrapping breaks `source`). Write a `.sh` script and chmod +x instead. Also use `python3 -m uvicorn` instead of `uvicorn` when PATH doesn't include the pip bin dir.
