# Last Session — 2026-04-08 (S30, Mac, Direct mode)

Four-hour delivery-pipeline marathon. Landed a working Discord → Gemini → GitHub issue triage bot for MyApps, full Firebase Hosting CI/CD with preview channels + approval gate + prod deploy on merge. Protocol migration sequence closed. Delivery-pipeline team spawned via TeamCreate (Swain/Pyke/Katarina/Fiora); all idle.

## Critical for next session — read first

1. **Triage bot is OFFLINE until Duong runs `install-discord-relay.ps1` on his Windows computer.** Cloud Run torn down tonight. Encrypted secrets (`secrets/encrypted/{gemini-api-key,discord-bot-token,github-triage-pat}.age`) ready to pull. Decrypt on Windows via `tools/decrypt.sh`. Bot will reconnect as Evelynn#7838 and watch Discord channel `1489570533103112375` (`#suggestions` forum) once running.
2. **coder-worker is ALSO offline** until Duong runs `install-service.ps1`. Scaffolded at `apps/coder-worker/` with hardened `--allowedTools Edit,Write,Read,Glob,Grep,LS` (no Bash) and per-job JSONL audit log at `%USERPROFILE%\coder-worker\var\logs\{jobId}.jsonl`. Shares runlock at `%USERPROFILE%\.claude-runlock\claude.lock` per `architecture/claude-runlock.md`.
3. **Bee is parked.** Build plan at `plans/approved/2026-04-09-bee-mvp-build.md` (Syndra, 10 PRs sequenced). Architecture at `plans/approved/2026-04-09-sister-research-agent-karma.md`. Ready to delegate after delivery-pipeline fully smokes green. Top 3 to delegate first: B1 scaffold `apps/bee-worker/`, B3 `comments.py` OOXML helper, B7 Firestore+Storage rules.
4. **Branch protection is LIVE on main** with 1-approval review + required status checks `Validate Scope / validate-scope` + `Firebase Hosting PR Preview / preview`. Admin can bypass (enforce_admins: false). `allow_auto_merge` is OFF.
5. **Hetzner VPS + runner deleted.** Zero residual cloud cost anywhere in the project. Delivery pipeline is fully free-tier.
6. **Two new feedback memories saved tonight** and should bite on the next session: `feedback_google_claude_free_default.md` (Google+Claude free-tier default, escalate paid) and `feedback_verify_before_redelegating.md` (read the file before re-delegating a patch).
7. **Session jsonl had two secret-scanner trips** — `github-pat` at line 552 (real PAT, Duong scrubbed, rotate if not already done), `age-pubkey` at line 904 (false positive — age public keys are not secret; the cleaner's `age-pubkey` rule is overreaching and should be downgraded in a future plan).

## What shipped this session

- **Protocol migration closed**: Commit 8 (Shen, port-then-delete `GIT_WORKFLOW.md`, `8d41ed0`) + Commit 10 (Fiora drift sweep, `55b20fd`) + plan promoted to implemented (`f450a06`).
- **MCP restructure phase-1 landed by Fiora** (`b95e2fe` + `3c55222` + `f5e87ec`) — agent-manager archived, `/agent-ops` skill, wiring of `apps/myapps/` peer dirs.
- **Shen + Fiora profiles wired** at `.claude/agents/{shen,fiora}.md` per Rule 15.
- **Syndra wrote Bee architecture plan** three separate times as directional pivots landed. Final at `f482034`. Then wrote the MVP build plan at `09d5091`.
- **Delivery-pipeline team**: Swain plan v1→v5 (final at `a63bbf1`), Pyke assessment REV 0→REV 3 (final at `1aa196c`), all 13 tasks completed across Waves A-S except end-to-end smoke test (waits on Duong's Windows install).
- **Workflow files**: added `auto-label-ready.yml`, `auto-rebase.yml`, `myapps-pr-preview.yml`, `myapps-prod-deploy.yml`, `validate-scope.yml`. Killed `contributor-pipeline.yml` + `contributor-merge-notify.yml` (Hetzner self-hosted Claude invocation, ToS wall).
- **apps/discord-relay/**: Gemini 2.5-flash-lite triage bot. Scaffold landed, smoke-tested live end-to-end against Duong's Discord `#suggestions` forum — filed a real `[Read Tracker] Vietnamese date picker broken on Safari` issue via a forum post. Now reshaped for Windows NSSM execution.
- **apps/coder-worker/**: Scaffold + hardening shipped at `8b87396`. Polls GitHub for issues labeled `myapps+ready+!bot-in-progress`, atomic label swap, acquires runlock, invokes `claude -p` locally, commits on `bot/issue-{number}`, opens PR with `bot-authored` label.
- **mcps/discord/**: Wrapper script for upstream `mcp-discord` npm package (barryyip0625). `.mcp.json` entry added. Not boot-tested yet — follow-up for next session.
- **architecture/claude-runlock.md**: Shared runlock contract between coder-worker and future bee-worker.
- **docs/delivery-pipeline-setup.md**: Full runbook for Duong. Windows prereqs, PAT rotation, Firebase SA scoping, branch protection, Windows worker install flow, physical security asks.
- **Branch protection applied** directly via admin push with the full payload (required_pull_request_reviews + required_status_checks + dismiss_stale_reviews true + enforce_admins false).
- **72 Dependabot vulnerabilities** surfaced on MyApps — backlog, not blocking.

## Open threads (priority order)

1. **Duong runs `install-discord-relay.ps1` on Windows** → verify `StrawberryDiscordRelay` service is running and triage bot reconnects as Evelynn#7838. Test by posting a new forum post in `#suggestions`.
2. **Duong runs `install-service.ps1` for coder-worker** → verify service runs, label a test issue `ready`, watch coder-worker open a PR within ~60 seconds.
3. **End-to-end smoke test** after both services are running: Discord post → issue → `ready` label → coder-worker PR → Firebase preview URL → Duong merges → prod deploy. If all green, delivery pipeline is shipped.
4. **Bee MVP execution** (after delivery pipeline is smoke-green): delegate B1 → B3 → B7 as first wave from Syndra's build plan.
5. **Rotate the GitHub PAT one more time** if it hasn't been since the cleaner flagged it at jsonl line 552. The value was in my working-context memory tonight; belt-and-braces is to rotate even though the file was scrubbed.
6. **Boot-test `mcp-discord`** — Bard scaffolded the wrapper but we skipped the actual `npx -y mcp-discord` boot because it needed network in the subagent sandbox. Do it from a top-level session on Mac.
7. **Fix the cleaner's `age-pubkey` false positive** — age public keys are intentionally public (they go in `secrets/recipients.txt` which is committed). The cleaner's rule should downgrade to warn-not-fail for `age1...` pubkeys. Worth a small plan.
8. **72 MyApps Dependabot vulnerabilities** — triage when bandwidth allows. `npm audit fix` on each `apps/myapps/*` workspace as a first pass.
9. **GHAS paywall for secret scanning on private repos** — known gap, documented. Either make MyApps public (bad idea), accept the gap, or pay for GHAS (against free-tier rule).
10. **Cleaner dropped false-positive for `age16zn6u...`** — consider reducing cleaner noise in S31.

## Lessons saved (cross-reference)

- `feedback_google_claude_free_default.md` — new this session, failed twice to apply it
- `feedback_verify_before_redelegating.md` — new this session, triple-re-delegation mistake with Katarina
- All prior memories still apply

## Ended cleanly

Second successful end-session of tonight (first was S29). Cleaner tripped on two secret patterns (one real, one false positive), Duong scrubbed both, cleaner passed on the third probe. Session transcript archived at `agents/evelynn/transcripts/2026-04-08-6563945f.md`. Handing off to S31 with a live triage product queued for first-boot on Duong's Windows computer.
