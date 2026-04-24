# 2026-04-24 — Sona MCP Suite: P1-T1 scaffold + T-new-B inventory

## Context

P1-T1 and T-new-B from `plans/approved/work/2026-04-24-sona-secretary-mcp-suite.md`.

## Key findings

### secrets/work gitignore pattern

The `secrets/*` rule in root `.gitignore` ignores all of `secrets/work/` by default.
To carve out a committable subdirectory under `secrets/work/`:

```
!secrets/work/
secrets/work/*
!secrets/work/encrypted/
!secrets/work/REVOCATION.md
secrets/work/encrypted/*
!secrets/work/encrypted/*.age
!secrets/work/encrypted/*.age.sha256
!secrets/work/encrypted/.gitkeep
secrets/work/runtime/
```

The `!secrets/work/` un-ignores the directory itself (required for git to descend into
it and see its children). Then `secrets/work/*` re-ignores everything inside, and
individual `!` lines carve out the committable artifacts. `secrets/work/runtime/` is
explicitly re-ignored as it holds ephemeral plaintext.

### Multi-secret inventory — summary

| MCP | secret count | classification |
|---|---|---|
| slack | 1 (`SLACK_USER_TOKEN`) | single |
| gdrive | 2 (OAuth client JSON + user refresh token) | multi |
| gcalendar | 2 (OAuth client JSON + user refresh token) | multi |
| mmp-fathom | 3 (`FATHOM_API_KEY`, `HUBSPOT_USER_TOKEN`, `SLACK_WEBHOOK_URL`) | multi |
| postgres | 6 (6 DB connection strings) | multi |
| wallet-studio | 3 (`WALLET_STUDIO_API_KEY`, `WALLET_STUDIO_TOKEN`, `MCP_AUTH_TOKEN`) | multi |
| mcp-atlassian | 2 (`CONFLUENCE_TOKEN`, `JIRA_TOKEN`) | multi |
| gmail | 1 (OAuth refresh token — post T14-Duong) | single |

Slack is SINGLE — the `SLACK_WEBHOOK_URL` in .env is NOT consumed by server.py
(only `SLACK_USER_TOKEN` and `SLACK_TOKEN` alias are). `SLACK_DEFAULT_USER` is a
user-ID config value, not a credential.

### T-new-C blocking scope

T-new-C (multi-var decrypt.sh extension) blocks 6/8 Phase-1 MCPs. Only slack (P1-T2)
and gmail (post T14-Duong) can migrate on the canonical single-token pattern.

## Commit SHAs

- Task A (P1-T1): `81edd095`
- Task B (T-new-B): `b2469e98`
