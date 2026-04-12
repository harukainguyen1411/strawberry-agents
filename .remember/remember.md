# Handoff

## State
- Dark Strawberry platform live: darkstrawberry.com (landing) + apps.darkstrawberry.com (portal). SSL working on both.
- Platform architecture (3 phases) + deployment architecture (Turborepo + Changesets) merged to main. PRs #95, #96, #97, #100 all merged.
- GCE VMs running: bee-worker (35.222.48.28, e2-micro) + coder-worker (136.113.135.178, e2-small). Health check cron every 6h.
- Discord: #request-your-app + #showcase channels, invite discord.gg/MuqGY2yHNh in landing page.
- 3 new agents wired: Lux (frontend), Viktor (backend), Ekko (fullstack). Self-close rule updated across all 14 agents.

## Next
1. Redeploy portal with composite deploy — standalone app architecture merged but apps.darkstrawberry.com may still serve old monolith.
2. Fix Lux agent def — she keeps asking for plans on trivial tasks. Update .claude/agents/lux.md.
3. Follow-ups from reviews: fork slug collision (M1), Cloud Function idempotency (L1), bee URL prefix validation (M2).

## Context
- Claude auth on GCE expires periodically — health check alerts Discord. SSH in: `sudo -u bee claude login` / `sudo -u coder claude login`.
- Compute Engine billing enabled on myapps-b31ea — e2-micro free, e2-small is NOT free.
- "team" = TeamCreate. "have someone" = background Agent. Never confuse them.
- Agent defs cached at startup — mid-session .claude/agents/ edits don't take effect until restart.
