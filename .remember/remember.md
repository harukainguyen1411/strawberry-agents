# Handoff

## State
Autodeploy pipeline fully live — push to main rebuilds all 4 Windows services via webhook.darkstrawberry.com (GitHub webhook verified 200). PR #89 merged. SubagentStop sentinel in settings.json. Three-agent PR review team protocol in architecture/pr-rules.md. Vex wired as Windows head agent. darkstrawberry.com purchased on Cloudflare.

## Next
1. B10 Bee smoke test — blocked on Duong: sister's Firebase UID, style-rules.md content, Firebase service account JSON
2. Issues #92/#93/#94 queued for coder-worker (2 LOWs from PR #89 + auto-review team feature)
3. SubagentStop sentinel needs empirical testing — session_id field name in hook stdin is unverified

## Context
- Vex is Windows head agent — route all Windows tasks to her. Her agent folder is agents/vex/
- .claude/ files can only be written by Evelynn directly — subagents are blocked by harness
- darkstrawberry.com on Cloudflare; webhook tunnel is webhook.darkstrawberry.com -> port 9000
- SendMessage can reach running background agents mid-flight — use it instead of kill+respawn
