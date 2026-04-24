# Work-Concern MCP Credentials — Revocation Table

Tracks every work-concern MCP credential managed under `secrets/work/encrypted/*.age`.
One row per credential blob. Fill in `last-rotated` and `revocation-runbook-link` as
each T2..T16 migration task lands.

> **Rule:** rotate immediately on suspicion; the "rotation cadence" column is the
> normal ceiling, not a substitute for incident-driven rotation.

| credential | owner-of-rotation | last-rotated | revocation-runbook-link | notes |
|---|---|---|---|---|
| `slack-user-token.age` (`SLACK_USER_TOKEN` — `xoxp-`) | Duong (Slack workspace admin) | TBD | TBD | Single token; no bot token on work-side MCP. Revoke at Slack admin → OAuth tokens. |
| `gdrive-oauth-keys.age` (OAuth client JSON — `client_id` / `client_secret`) | Duong (GCP project owner) | TBD | TBD | OAuth client identity, not user session. Rotation requires creating a new GCP OAuth client + re-auth. |
| `gdrive-server-credentials.age` (user refresh token) | Duong (Google account) | TBD | TBD | Non-rotatable without re-auth flow. Health-check before migration (OQ-P1-1). Revoke at myaccount.google.com → Security → Third-party access. |
| `gcalendar-oauth-keys.age` (OAuth client JSON) | Duong (GCP project owner) | TBD | TBD | May be same GCP app as gdrive — check at T9. |
| `gcalendar-credentials.age` (user refresh token) | Duong (Google account) | TBD | TBD | May be same refresh token as gdrive — check at T9 (OQ-P1-5). |
| `gmail-oauth.age` (OAuth refresh token) | Duong (Google account) | TBD | TBD | Requires Duong-in-the-loop auth flow (T14-Duong). Revoke at myaccount.google.com → Security → Third-party access. |
| `fathom-api-token.age` (`FATHOM_API_KEY`) | Duong (Fathom account) | TBD | TBD | Multi-secret MCP — also needs hubspot and slack webhook. Gated on T-new-C. |
| `hubspot-private-app-token.age` (`HUBSPOT_USER_TOKEN`) | Duong (HubSpot account) | TBD | TBD | Bundled with fathom MCP. Revoke at HubSpot settings → Integrations → Private Apps → Revoke. |
| `fathom-slack-webhook.age` (`SLACK_WEBHOOK_URL`) | Duong (Slack workspace admin) | TBD | TBD | Notification webhook used by fathom MCP for alerts. Revoke at Slack → App → Incoming Webhooks. |
| `postgres-dev-tse.age` (`DB_DEV_TSE_URL`) | TBD | TBD | TBD | Dev connection string. Flag if non-rotatable service account embedded (OQ-P1-2). |
| `postgres-dev-email.age` (`DB_DEV_EMAIL_URL`) | TBD | TBD | TBD | Dev connection string. |
| `postgres-dev-mailrouter.age` (`DB_DEV_MAILROUTER_URL`) | TBD | TBD | TBD | Dev connection string. |
| `postgres-prd-tse.age` (`DB_PRD_TSE_URL`) | TBD | TBD | TBD | Production connection string. Rotate immediately on suspicion. |
| `postgres-prd-email.age` (`DB_PRD_EMAIL_URL`) | TBD | TBD | TBD | Production connection string. |
| `postgres-prd-mailrouter.age` (`DB_PRD_MAILROUTER_URL`) | TBD | TBD | TBD | Production connection string. |
| `wallet-studio-api-key.age` (`WALLET_STUDIO_API_KEY`) | TBD | TBD | TBD | Multi-secret MCP — also TOKEN and MCP_AUTH_TOKEN. Gated on T-new-C. |
| `wallet-studio-token.age` (`WALLET_STUDIO_TOKEN`) | TBD | TBD | TBD | Bundled with wallet-studio MCP. |
| `wallet-studio-mcp-auth-token.age` (`MCP_AUTH_TOKEN`) | TBD | TBD | TBD | Bundled with wallet-studio MCP. |
| `atlassian-api-token.age` (`CONFLUENCE_TOKEN` / `JIRA_TOKEN`) | Duong (Atlassian account) | TBD | TBD | Multi-secret MCP — Confluence + Jira tokens. Duong-in-the-loop for generation (T10). Revoke at id.atlassian.com → API tokens. |
| `atlassian-site-config.age` (URL + email — non-secret, bundled for lock-step rotation) | Duong | TBD | TBD | Contains Atlassian site URL + username; bundled with token for atomic rotation. |
| `linear-api-key.age` | Duong (Linear account) | TBD | TBD | Conditional on OQ-1 (Phase 3). Revoke at Linear settings → API → Revoke key. |
| `asana-pat.age` | Duong (Asana account) | TBD | TBD | Conditional on OQ-1 (Phase 3). Revoke at Asana settings → Apps → Revoke. |
| `github-pat-work.age` | Duong (GitHub `duongntd99`) | TBD | TBD | Sona's path — separate from `gh` CLI keychain. Phase 3 (conditional). Revoke at github.com/settings/tokens. |

## Rotation cadence

| tier | cadence |
|---|---|
| Long-lived API tokens (Fathom, Atlassian, Linear, Asana, GitHub PAT) | Annually, or immediately on suspicion |
| OAuth refresh tokens (Google services) | On re-auth event (typically triggered by token expiry or revocation at provider) |
| DB connection strings | On credential rotation event at MMP infra level |
| Slack tokens / webhooks | Annually, or immediately on suspicion |

## Runtime residency

`secrets/work/runtime/` holds ephemeral plaintext files written by `tools/decrypt.sh --target`
during MCP start. These files are gitignored and should be cleaned up by each `start.sh`'s
`trap` handler on exit. They are never committed.
