# Last Session — 2026-04-05, CLI (Session 5)

- Diagnosed GH_TOKEN not injecting into agent sessions (empty env var on launch)
- Fixed shell scoping bug in `server.py` `launch_agent`: `VAR=$(cmd) cd ...` → `export VAR=$(cmd) && ...` — PR #29
- Fixed per-agent API key isolation: now reads ANTHROPIC_API_KEY from `agents/<name>/.claude/settings.local.json`, writes to `secrets/.agent-key-<name>` (chmod 600), injects at launch — PR #30
- Lissandra flagged missing JSONDecodeError handling in PR #30 — added try/except, pushed fix same session

Open threads:
- PRs #29 and #30 awaiting merge
- Once merged, relaunch agents to pick up GH_TOKEN and per-agent API keys
