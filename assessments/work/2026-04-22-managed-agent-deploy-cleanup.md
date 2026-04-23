# Managed-Agent deploy.sh Cleanup — Advisory

**Date:** 2026-04-22
**Scope:** demo-studio-v3 — `deploy.sh` env-var guards and `setup_agent.py` lifecycle
**Status:** Read-only assessment; hand off to Ekko.

## Finding: managed-agent code is NOT dead

Caller premise ("managed-agent removed from code") is **not accurate** as of today. The
vanilla path is the primary SSE route (Wave 4, T.C.2b), but the managed-session branch
is still reachable and imports still `_require_env(...)`:

- `main.py:44` — `from agent_proxy import create_managed_session, send_message, send_message_and_stream`
- `main.py:59` — `from managed_session_client import managed_session_client`
- `main.py:1785` — `create_managed_session(...)` called inside `/chat` when a legacy
  managed-session branch is taken (see `main.py:1575-1848`).
- `main.py:2860` — `managed_session_client.list_active()` (dashboard still lists by `MANAGED_AGENT_ID`).
- `main.py:3095` — `managed_session_client.stop(...)`.
- `session_store.py:32, 490` — terminal-state hook calls `stop_managed_session`.
- `agent_proxy.py:602-612` — `create_managed_session` hard-requires `MANAGED_AGENT_ID`
  and `MANAGED_ENVIRONMENT_ID`; `MANAGED_VAULT_ID` optional.
- `managed_session_client.py:62-83` — `_agent_id()` raises if `MANAGED_AGENT_ID` unset
  (fires on every `list_active`/`stop`).

Startup validation in `main.py:308-313` lists `MANAGED_AGENT_ID` and
`MANAGED_ENVIRONMENT_ID` as REQUIRED and the process `sys.exit(1)`s without them
(`main.py:362-368`). Removing the deploy-time guards would crash the container on boot.

## Recommendation

**Do NOT drop the guards yet. Do NOT delete `setup_agent.py` yet.** The cleanup is a
code change, not a deploy-script change.

## Punch list (sequenced for Ekko)

**Phase 1 — code-level retirement (PR, not ops):**
1. Remove managed-session branch from `POST /chat` (`main.py:~1575-1848`) and delete
   imports on lines 44, 59.
2. Strip `list_active` / `stop` paths: `main.py:2854-2860`, `3073-3095`;
   `session_store.py:32, 411-490` terminal hook.
3. Delete `agent_proxy.create_managed_session`, `send_message`,
   `send_message_and_stream`, `stop_managed_session` (keep `run_turn`,
   `get_client`, `SYSTEM_PROMPT`).
4. Delete `managed_session_client.py` entirely.
5. Drop `MANAGED_AGENT_ID` and `MANAGED_ENVIRONMENT_ID` from `REQUIRED_ENV_VARS`
   (`main.py:308-313`) and from `/debug` env_keys (`main.py:644-645`, `683-685`)
   and lifespan log (`main.py:389-391`).
6. Delete `setup_agent.py` and `.agent-ids.env` references.
7. Drop stale comment in `main.py:402-404` about "Anthropic managed-agent MCP
   handshake" if `redirect_slashes=False` is no longer required by the vanilla path
   (verify before removing).

**Phase 2 — deploy.sh simplification (after Phase 1 merged + deployed):**
8. Remove guards `deploy.sh:16-18` (`MANAGED_AGENT_ID`, `MANAGED_ENVIRONMENT_ID`,
   `MANAGED_VAULT_ID`).
9. Remove `MANAGED_AGENT_ID=${…},MANAGED_ENVIRONMENT_ID=${…},MANAGED_VAULT_ID=${…}`
   from `--set-env-vars` on line 28.
10. Update header comment `deploy.sh:4-5` — drop the three vars from the required list.
11. Keep `BASE_URL` guard and env var.

**Phase 3 — ops cleanup (optional, post-verify):**
12. `gcloud run services update demo-studio --remove-env-vars=MANAGED_AGENT_ID,MANAGED_ENVIRONMENT_ID,MANAGED_VAULT_ID`
    in stg and prod (or let next deploy drop them naturally).
13. Do NOT delete the Anthropic managed Agent/Environment/Vault platform resources
    until both stg and prod have run at least one full release without them — they
    are cheap and provide rollback insurance.

## Rollback

Phase 1 is revert-by-PR. Phase 2 cannot go before Phase 1 or the container crashes at
startup. Phase 3 is reversible via `setup_agent.py --force` (while it still exists in
git history) to recreate the platform resources.
