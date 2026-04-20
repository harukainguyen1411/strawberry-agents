# Never snapshot env vars to committed files

**Date:** 2026-04-15
**Context:** Heimerdinger wrote cloud-run-config-snapshot.md with all Cloud Run env vars including production secrets. Jhin's leak scan caught it.

**Problem:** When documenting Cloud Run config for redeployment, the agent dumped every env var (including ANTHROPIC_API_KEY, SESSION_SECRET, INTERNAL_SECRET, etc.) into a markdown file that got committed and pushed.

**Fix:** Scrubbed from git history with filter-branch, force-pushed. All 6 keys need rotation.

**Lesson:** 
- NEVER write env var values to committed files, even "documentation" files
- When asking agents to document infra config, explicitly say "do NOT include secret values — use placeholders"
- company-os has zero secret scanning — add a pre-commit hook with detect-secrets or trufflehog
- .env files should always be in .gitignore (demo-factory-cloud .env.prd/.env.stg are tracked but empty — risky pattern)
