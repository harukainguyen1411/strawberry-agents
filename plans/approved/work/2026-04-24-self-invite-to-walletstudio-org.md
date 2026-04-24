---
status: approved
complexity: normal
concern: work
owner: Azir
created: 2026-04-24
tags:
  - walletstudio
  - sona
  - urgent-path
  - superadmin
  - tooling
  - work
tests_required: false
---

# ADR: Sona-driven self-invite to any WalletStudio org

**Date:** 2026-04-24
**Author:** Azir (architecture)
**Requester:** Duong (via Sona)
**Scope:** Founder-privilege tooling for Duong's identity only. Not a generally
deployable capability.

## TL;DR — Recommendation

**Use the SuperAdmin path (Option A). API-key-harvest (Option B) is a hack
and only viable if SuperAdmin can't be stood up.**

The WalletStudio codebase at `~/Documents/Work/mmp/workspace/wallet-studio/`
already has a first-class `SuperAdmin` role with a dedicated
`/api/v3/superadmin/*` route namespace. The role is granted via a config-file
string list (`Config.SuperAdmin []string`) keyed by email, and the
`AuthSession` middleware accepts API-key auth — meaning once Duong's email is
in the SuperAdmin list, his existing API key already unlocks the superadmin
surface. What's missing is a single endpoint:
`POST /api/v3/superadmin/invite-user-to-org`. Option A is "add that endpoint,
ensure Duong is in the SuperAdmin config, and let Sona call it via an MCP
tool." Structurally clean. No impersonation. No DB scrape. Normal audit trail.

Option B (impersonate an OrgOwner's API key harvested from the production
DB or Metabase) is feasible — API keys are plaintext `uuid` strings stored in
the `users.api_key` column — but it's the wrong architecture. Dirty audit
trail, broader blast radius, fragile to any future key-hashing migration,
and indistinguishable in logs from account compromise.

## 1. Context

### 1.1 Problem

Duong is MissMP's founder and routinely needs access to customer or internal
WalletStudio orgs for support, debugging, and demos. Today the path is:

1. Identify the org's human OrgOwner.
2. Ask them (Slack, email) to issue an invite.
3. Wait for the invite, accept.

Friction: minutes to hours, blocks urgent work, requires a human on the far
side. When a customer is mid-incident, step 2 is a deal-breaker.

### 1.2 Desired end state

Sona (the work-concern coordinator agent) runs one command:

```
self-invite me to org <orgId> as OrgOwner
```

and Duong's inbox has an invitation within seconds, or — ideally — Duong is
already a member with the requested role, no inbox step required.

### 1.3 Non-goals

- Productionising this flow for any identity other than Duong.
- Any broader impersonation capability beyond the org-invite / org-membership
  case.
- Replacing the customer-OrgOwner's normal invite UX.
- Automating invite acceptance (Duong accepts manually; that's fine).

## 2. Surveyed surface — what exists today

Findings from reading
`~/Documents/Work/mmp/workspace/wallet-studio/core/tse/` on 2026-04-24.

### 2.1 Role model (`core/tse/model/roles.go`)

```go
UserRoleSuperAdmin   UserRole = "SuperAdmin"
UserRoleOrgOwner     UserRole = "OrgOwner"
UserRoleProjectAdmin UserRole = "ProjectAdmin"
UserRoleEditor       UserRole = "Editor"
UserRoleViewer       UserRole = "Viewer"
UserRoleOverView     UserRole = "Overview"

UserRoleReadAllOrgs               UserRole = "ReadAllOrgs"
UserRoleReadAllOrgsNoPersonalData UserRole = "ReadAllOrgsNoPersonalData"

InviteRoles = []string{ProjectAdmin, Editor, Viewer, Overview}
```

Key consequences:

- SuperAdmin **is** a real role tier above OrgOwner, and there is dedicated
  routing and middleware for it.
- The regular org-scoped invite endpoint (`POST /v3/orgs/:orgId/invites`,
  handled by `InviteUsers` in `api/v3/invites.go`) rejects
  `role ∉ {ProjectAdmin, Editor, Viewer, Overview}` — so it **cannot** be
  used to create a new OrgOwner, and it cannot be used at all by a
  non-org-member.
- `ReadAllOrgs` / `ReadAllOrgsNoPersonalData` are listed but not what we want
  — they're for internal-service read access, not org-membership bootstrap.

### 2.2 SuperAdmin route namespace (`core/tse/api/v3/api.go:29-36`)

```go
admin := root.Group("/v3/superadmin",
    mw.AuthSession(a.OIDCRegistry),
    mw.CheckPermissionSuperAdmin())
admin.POST("/gpay-class",                           CreateGPayClassWithoutProject(a))
admin.PATCH("/gpay-class/:googleStyle/:googleClassID", PatchGPayClassWithoutProject(a))
admin.PUT("/gpay-link-new-class",                   LinkProjectGPayClass(a))
admin.POST("/new-google-issuer-for-existing-org",   CreateGoogleIssuerForExistingOrg(a))
admin.PUT("/transfer-project-to-new-org",           TransferProjectToNewOrgHandler(a))
```

There is **no** `admin.POST("/invite-user-to-org", ...)` today. That's the
prerequisite endpoint this ADR proposes (§4.2).

Elsewhere in api.go:
- `root.DELETE("/v3/demo-org/:orgId", ..., mw.CheckPermissionSuperAdmin())`
  shows SuperAdmin gating being used ad-hoc on non-`/superadmin/*` paths
  as well. Fine; matches intent.

### 2.3 SuperAdmin permission check (`pkg/middlewares/auth.go:221-241`)

```go
func (m *authMiddlewareManager) CheckPermissionSuperAdmin() echo.MiddlewareFunc {
    // ...
    isSuperAdmin := false
    for _, v := range m.App.Config.SuperAdmin {
        if v == user.Email {
            isSuperAdmin = true
            break
        }
    }
    if !isSuperAdmin {
        return pkgErrors.ResponsePermissionError(c,
            fmt.Errorf("%v is not a SuperAdmin", user.Email))
    }
    // ...
}
```

And (`model/config.go:65`):

```go
SuperAdmin []string `yaml:"SuperAdmin"`
```

**SuperAdmin is email-list-based, config-driven.** Not a DB column, not a
per-env feature flag, not a role join. Adding Duong to the list is:

- an edit to the tse service's config YAML (likely in the Kubernetes /
  secret-manager config blob the tse pods load) on each environment where
  he wants access, and
- a redeploy / config-reload.

### 2.4 AuthSession accepts API key (`pkg/middlewares/auth.go:85-123`)

```go
apiKey := util.GetApiKeyFromHeader(c)  // X-API-Key header
// ...
if apiKey != "" { authMethod = "apiKey" }
// ...
case "apiKey":  err = m.authByApiKey(c, apiKey)
```

**Critical:** `AuthSession` — which is the outer middleware on the
`/v3/superadmin` group — will authenticate by API key when the client sends
`X-API-Key`. Combined with §2.3, this means Duong's personal API key
(`GET /v3/me/api-key`) will successfully pass SuperAdmin routes once his
email is in `Config.SuperAdmin`. No OIDC session needed. This is what makes
an MCP-driven self-invite practical — agents hold API keys, not OIDC
sessions.

### 2.5 WalletStudio MCP tool surface (observed, 2026-04-24)

From `agents/sona/transcripts/*` (exhaustive `grep`):

```
walletstudio_clone_project           walletstudio_list_orgs
walletstudio_create_params           walletstudio_list_templates
walletstudio_create_project_wizard   walletstudio_patch_gpay_template
walletstudio_get_token_ui            walletstudio_patch_ios_template
walletstudio_setup_claims            walletstudio_patch_token_ui
walletstudio_update_params           walletstudio_update_project
walletstudio_update_token_ui         walletstudio_archive_asset
```

None of these create org members or issue invitations. There is **no**
`walletstudio_invite_user` tool today, nor any `walletstudio_superadmin_*`
tool. Both are ADR prerequisites.

### 2.6 Existing MCP infrastructure

WalletStudio MCP lives at `~/Documents/Work/mmp/workspace/mcps/wallet-studio/`
with the usual three-file surface pattern per Camille's learning
`2026-04-09-mcps-wallet-studio-tool-branch.md`:

- `src/walletstudio-api.ts` — static operations
- `src/tool-contracts.ts` — tool schemas + descriptions
- `src/server.ts` — preInterceptor logic

Adding a tool is a three-file change in one repo. Low cost.

### 2.7 API key storage (`model/users.go:86`)

```go
APIKey sql.NullString `json:"-" db:"api_key"`
// ...
u.APIKey = sql.NullString{util.NewUUIDWithoutDashes(), true}
```

**API keys are stored plaintext** (UUIDs without dashes). This is the only
reason Option B would work; it's also the reason Option B is one schema
migration away from dying silently.

## 3. Decision

**Option A (SuperAdmin) is the primary path. Option B (API-key-harvest) is
documented as a dead-letter fallback and should not be built first.**

### 3.1 Option A — "Add a SuperAdmin invite endpoint; give Duong SuperAdmin"

Three prerequisite pieces of work, then one MCP-tool wiring.

**A.1 — Backend: new SuperAdmin invite endpoint** (`wallet-studio` repo)

Add to `core/tse/api/v3/api.go` under the existing `admin` group:

```go
admin.POST("/invite-user-to-org", SuperAdminInviteUserToOrg(a))
```

Handler lives in a new `core/tse/api/v3/superadmin_invites.go`. Body:

```json
{
  "orgId":   "ORG-ABC",
  "email":   "duongntd99@...",
  "role":    "OrgOwner" | "ProjectAdmin" | "Editor" | "Viewer" | "Overview"
}
```

Semantics:
- If user with that email doesn't exist in WalletStudio: create the user row
  (reuse the code path from `InviteUsers` / `a.InviteUsers`) and send a
  normal SSO invite email.
- If user exists and is not a member of the org: add membership with the
  requested role, send notification email.
- If user exists and IS a member with the requested role: no-op, return 200.
- If user exists and IS a member with a different role: update role, return
  200 with the previous role in the response body for audit.

**A new role `SuperAdminInvite` is NOT allowed.** The role written to the
org-membership row is the role the caller requested; this endpoint expands
the set of allowable invite roles beyond `InviteRoles` (specifically, allows
`OrgOwner`) because only a SuperAdmin can hit it.

Authorization: the existing `mw.CheckPermissionSuperAdmin()` on the group
is sufficient. No per-handler logic needed.

Audit: log one structured line to whatever log sink the tse service
currently uses for admin actions. Minimum fields:
`{actor_email, actor_role=SuperAdmin, action=superadmin_invite,
target_email, target_org_id, target_role, previous_role_or_null, request_id,
timestamp}`. These should be queryable later.

**A.2 — Config: add Duong to `Config.SuperAdmin` on all envs**

One-time config edit per environment (prod, stg, local). Owner: Heimerdinger
(devops). The list is in the tse service YAML config; the exact location in
secret-manager / k8s is out of scope for this ADR but belongs on the
task-breakdown.

Gate: this step requires a human (Heimerdinger or Duong himself via an
admin console). **That human-gate happens once per environment, not per
self-invite.** After it lands, the flow is zero-human for all future
invites.

**A.3 — MCP tool: `walletstudio_superadmin_invite_user_to_org`**

Added to the `mcps/wallet-studio` package via the standard three-file
pattern (§2.6):

- `walletstudio-api.ts` — new function calling the endpoint in A.1, using
  the MCP server's configured API key.
- `tool-contracts.ts` — tool schema with args
  `{orgId, email, role, reason}` and a description that explicitly names
  SuperAdmin as the required caller role.
- `server.ts` — preInterceptor that **refuses to fire unless the MCP
  server's configured API key belongs to a user whose email is in the
  configured Duong allowlist** (see §5.2).

The `reason` argument is required and free-text. It goes into the MCP
server's audit log and into the `X-Client-Reason` header on the upstream
HTTP call. Strawberry agents also write the reason into
`agents/sona/memory/self-invite-audit/<timestamp>-<orgId>.md` (see §5.3).

**A.4 — Sona-side orchestration**

No new MCP server. Sona calls `walletstudio_superadmin_invite_user_to_org`
directly as a tool. One-shot. No DB lookup, no key harvest, no Metabase.

### 3.2 Option B — API-key-harvest (documented fallback, NOT recommended)

Pipeline if Option A is ever blocked:

1. Fetch target org's OrgOwner's API key:
   - **Primary data source:** `mcp__mcp-postgres__*` against the tse
     production DB (if that DB is one of the configured `list_connections()`
     connections; see §4.3 for the open question). Query shape:
     ```sql
     SELECT u.email, u.api_key
     FROM users u
     JOIN user_roles ur ON ur.user_id = u.id
     JOIN orgs o        ON o.id = ur.org_id
     WHERE o.id = :target_org_id
       AND ur.role = 'OrgOwner'
       AND u.api_key IS NOT NULL
     LIMIT 1;
     ```
     Works only because `users.api_key` is plaintext (§2.7). If a future
     WalletStudio migration hashes this column, this pipeline dies silently
     — `u.api_key` becomes a bcrypt/argon2 hash, not a usable token.
   - **Fallback data source:** Metabase at
     [analytics.missmp.tech](https://analytics.missmp.tech) via the Metabase
     REST API (`POST /api/dataset` or `POST /api/card/:id/query`). Auth
     via Duong's Metabase session cookie or a Metabase API token
     (`/api/user/me`). This requires either (a) a saved Card that exposes
     the query above — dangerous, anyone with Metabase access could pull
     keys — or (b) a native-query permission on the tse DB connection in
     Metabase for Duong's account. Option (b) is narrower.
   - **Metabase-as-MCP:** no first-party Metabase MCP exists as of
     2026-04-24 to my knowledge; the community has `mcp-metabase` attempts
     but nothing blessed. **Not worth depending on.** Wrap the Metabase
     REST API directly from Sona if used.
2. Call the existing `InviteUsers` endpoint (`POST /v3/orgs/:orgId/invites`)
   with the harvested API key as `X-API-Key` — but note you can only invite
   yourself as `ProjectAdmin/Editor/Viewer/Overview`, **not OrgOwner**. For
   urgent-support access that's usually enough; for anything needing
   OrgOwner you'd still need Option A.
3. Invitation lands in Duong's inbox; he accepts.

Why this is the wrong architecture:

- **Audit lies.** WalletStudio's audit log will read "OrgOwner X invited
  duongntd99@missmp..." when X did no such thing. If X ever churns, or
  if there's a customer-trust conversation, this is a landmine.
- **Blast radius.** To harvest the key, the pipeline needs read access to
  `users.api_key` for *any* org. That's a far broader capability than
  "invite Duong to one org."
- **Fragility.** One schema migration (hash the column; rotate to
  short-lived tokens; move to OIDC-only for OrgOwners) and the whole
  pipeline dies with no clean error surface.
- **Role ceiling.** Can't grant OrgOwner — only the roles in `InviteRoles`.
- **Customer data exposure.** Even a read-only postgres MCP lets the agent
  see every OrgOwner's email and key. That's PII-adjacent secrets exposure
  an auditor will care about.

Option B exists as Plan Z only. Build it only if Option A is blocked.

### 3.3 Not considered

- **Direct DB write to `org_user` membership table.** Faster than any API
  call, but bypasses the invite email, bypasses the SSO invite link
  (`/v3/sso/invite/:invitation`), and bypasses any org-side notifications.
  The point of this tool is "Duong gets access the same way a real invitee
  does, just without the human-in-the-loop gate." Direct DB write loses
  the normal acceptance flow and leaves the account in a weird
  provisioned-but-never-accepted state. Rejected.

- **Temporary "break-glass" JWT minted by a founder-only endpoint.** Would
  skip invite entirely and hand Duong a session token. Cleaner than
  key-harvest but strictly more dangerous than SuperAdmin (session tokens
  don't show up in the same audit table as membership changes). Rejected
  in favor of membership-invite which leaves a durable org-member row.

## 4. Delivery shape

### 4.1 Not a new MCP server

Option A is a **tool added to the existing `wallet-studio` MCP** plus a
**new backend endpoint in the `wallet-studio` tse service**. Reuse cost
is low. No new deployment target, no new service account, no new secret
binding.

Coordination work for Sona stays in Sona-side skills that call existing
MCP tools — no Sona-side orchestration code needed beyond the natural
"Sona calls a tool" pattern.

### 4.2 Endpoint spec (A.1 detail)

```
POST /api/v3/superadmin/invite-user-to-org
Auth: X-API-Key of a user whose email is in Config.SuperAdmin
      (AuthSession → authByApiKey → CheckPermissionSuperAdmin)

Body:
{
  "orgId":  "<orgId>",
  "email":  "<invitee-email>",
  "role":   "OrgOwner" | "ProjectAdmin" | "Editor" | "Viewer" | "Overview",
  "reason": "<required, free-text, stored in audit log>"
}

200 OK:
{
  "ok":           true,
  "action":       "created_user_and_invited" | "added_to_org" | "updated_role" | "already_member",
  "previousRole": null | "<role>",
  "userId":       "<walletstudio user id>",
  "orgId":        "<orgId>"
}

400: malformed body, unknown role, unknown org
403: caller not a SuperAdmin
500: anything else
```

Idempotency: same `{orgId, email, role}` called twice is safe —
second call returns `"already_member"`.

### 4.3 Tool spec (A.3 detail)

```
walletstudio_superadmin_invite_user_to_org({
  orgId:  string,
  email:  string,
  role:   "OrgOwner" | "ProjectAdmin" | "Editor" | "Viewer" | "Overview",
  reason: string,
})
```

Pre-interceptor logic (server.ts):

```
1. Resolve caller's identity from the MCP server's configured API key by
   calling GET /v3/me. Call this email `configured_email`.
2. If configured_email NOT IN DuongAllowlist (env var
   WALLET_STUDIO_MCP_SELF_INVITE_ALLOWLIST, comma-separated): reject with
   "self-invite tool is gated to Duong's founder identity only".
3. Else: forward to the upstream endpoint with X-API-Key, X-Client-Reason,
   X-Client-Agent: "sona-self-invite".
```

Guards:

- `role = "SuperAdmin"` is not accepted via this tool (the SuperAdmin list
  is a config file, not a per-org role) — tool schema enum excludes it.
- The tool refuses to run if `WALLET_STUDIO_MCP_SELF_INVITE_ALLOWLIST` is
  unset or empty (fail-closed).
- If the target email in the tool args doesn't match a configured Duong
  allowlist email: reject. (Prevents Sona from inviting anyone other than
  Duong.)

This closes "what guards prevent an agent from using this tool for
non-Duong purposes" — the guards are baked into the MCP tool's
pre-interceptor, not negotiated at call time.

## 5. Security and audit design

### 5.1 WalletStudio-side audit entries (Option A)

Expected audit entries on Option A, for a self-invite of Duong to org X as
OrgOwner:

1. `superadmin_invite` row (new, per A.1): actor = Duong's email,
   target = Duong's email, org = X, role = OrgOwner, reason = "<reason>",
   request_id, timestamp. Note actor==target is the clean signal.
2. `user_role_created` / `org_member_added` row (existing tse
   behavior, whatever the current schema calls it): Duong now a member
   of org X with role OrgOwner.
3. (If invite email is sent) `email_sent` row pointing at Duong's inbox.

Contrast with Option B — audit entry on the `InviteUsers` path would show
actor = the harvested OrgOwner's email, target = Duong. Structurally lies
about who did the action.

### 5.2 Least privilege and scoping

- **Who can call this MCP tool?** Only clients configured with an API key
  belonging to an allowlisted Duong-founder email. Allowlist is an env var
  on the MCP server process, not baked into the code.
- **Can Sona use it to invite arbitrary users?** No — target email must
  also be in the Duong allowlist. The tool is named `self_invite_*` for a
  reason; it is not a general invite tool.
- **Can other agents (Evelynn, Kayn, etc.) use it?** If they're on a
  session that has the WalletStudio MCP configured, yes, at the tool
  level. But the pre-interceptor only cares about the caller's MCP-config
  email, not the agent identity — so the practical answer is "only
  sessions running with Duong's founder API key configured."
- **Is there an obvious place to tighten further?** Yes — gate the MCP
  tool on `STRAWBERRY_AGENT=sona` via env, if we want a belt-and-braces
  agent-identity check. Propose as an open question (§6.3); not required
  for v1.

### 5.3 Strawberry-side audit logging

Every invocation of `walletstudio_superadmin_invite_user_to_org` emits a
structured memory entry at:

```
agents/sona/memory/self-invite-audit/YYYY-MM-DD-HHMMSS-<orgId>.md
```

Schema:
```yaml
---
timestamp:        <iso8601>
tool:             walletstudio_superadmin_invite_user_to_org
caller_agent:     sona
target_org_id:    <orgId>
target_email:     duongntd99@...
target_role:      <role>
reason:           <free text from call>
upstream_request_id: <uuid from endpoint response>
upstream_action:  created_user_and_invited | added_to_org | updated_role | already_member
---
(free-form notes)
```

These are grep-able later ("show me every time Sona self-invited in the
last week") and pair with WalletStudio's own audit trail. The pairing is
the whole point — two independent logs, same event, both queryable.

### 5.4 Threat model — what Option A does NOT protect against

- **Duong's own API key leaking.** If his key leaks, an attacker can call
  superadmin routes. This is not a new risk introduced by this ADR; it
  already exists for every SuperAdmin route. Mitigation is the same
  (rotate via `PUT /v3/me/api-key/generate`).
- **Config.SuperAdmin leaking to someone else's email.** Same story — not
  a new risk. Mitigation is the same (review of tse config changes).
- **Sona session being hijacked.** An attacker with shell on Duong's Mac
  can do far worse things than invite themselves to a WalletStudio org.
  Out of scope.

### 5.5 Threat model — what Option B introduces that A does not

- Plaintext harvest of any OrgOwner's API key from the production DB.
  Even if the pipeline is "only invoked to invite Duong," the capability
  exists for any org. This is the core reason A wins.
- Any audit entry showing an action by "OrgOwner X" is now ambiguous:
  was it actually X, or was it Sona-as-X? A's audit trail is unambiguous.

## 6. Consequences

### 6.1 Positive

- Zero human-in-loop for all future self-invites after the one-time
  `Config.SuperAdmin` seed.
- Clean audit trail — both in WalletStudio's DB and in Strawberry memory.
- Structurally scoped via `CheckPermissionSuperAdmin` + MCP-side allowlist.
- Same mechanism works for every WalletStudio environment (prod, stg) as
  long as Duong is in that env's `SuperAdmin` list.
- Reusable foundation: if we ever want other SuperAdmin-level MCP tools
  (force-unlock an org, force-cleanup demo data, etc.), the pattern is
  established.

### 6.2 Negative

- One-time human gate (§A.2) to land Duong in `Config.SuperAdmin` on each
  env. Heimerdinger's task.
- Expands the SuperAdmin membership to Duong's personal user (was
  previously empty or minimal). Means Duong's key now has cross-org
  capability on any SuperAdmin route — intended, but worth naming.
- Adds a tse backend endpoint (A.1) that must be maintained. Small
  surface.

### 6.3 Open questions

1. **Config.SuperAdmin delivery.** Where exactly is the tse service's
   config YAML sourced today — Kubernetes ConfigMap, GCP Secret Manager,
   committed YAML file? Heimerdinger owns the answer; feeds into task
   breakdown.
2. **Email vs user-id for SuperAdmin allowlist.** Config uses email. What
   if Duong's login email changes? Minor but worth noting.
3. **Belt-and-braces `STRAWBERRY_AGENT=sona` gate on the MCP tool?**
   Proposed in §5.2 but not required. Low implementation cost; possibly
   worth doing for a "only one agent should drive this" invariant.
4. **Should the `reason` field be structured** (enum of ["customer
   support", "debugging", "demo", "other"] + free text) rather than
   free-form? Helps grep; slightly more friction.
5. **Postgres MCP connection to tse DB.** Only relevant if Option B is
   ever needed. Unresolved — I didn't call `mcp__mcp-postgres__list_connections()`
   in this session because Option A makes it moot. Flag for whoever
   revives B.
6. **Metabase MCP availability.** No first-party, no blessed community one
   as of knowledge cutoff 2026-01. If Option B is ever needed, use
   Metabase REST directly; don't wait on an MCP.

## 7. Alternatives considered

| Alternative | Verdict |
|---|---|
| **Option A — SuperAdmin invite endpoint + MCP tool** | **Chosen.** Structurally clean, reuses existing role, minimal new surface. |
| Option B — API-key-harvest + existing InviteUsers | Fallback only. Dirty audit, narrower role ceiling, fragile to schema changes. |
| Direct DB write to `org_user` | Rejected. Bypasses invite email flow, leaves account in inconsistent state. |
| Break-glass founder JWT endpoint | Rejected. Session tokens don't leave the same audit footprint as membership changes. |
| Widen `InviteRoles` to include `OrgOwner`, then harvest a member's key | Strictly worse than B. Rejected. |
| New standalone MCP server wrapping the pipeline | Rejected. Adds a server for one tool. Put the tool in the existing `wallet-studio` MCP. |

## 8. Out of scope

- Productionising this flow for any identity other than Duong's founder
  account.
- Any broader impersonation or account-takeover primitive.
- Invite-acceptance automation (Duong accepts in his inbox manually).
- Role changes *other than* invite/add-to-org (demotions, removals,
  ownership transfers across orgs, etc.).
- Metabase MCP / postgres MCP wiring work, unless Option B is revived.

## 9. Task-breakdown handoff

**Recommended next step:** hand this plan to **Aphelios** (work-side task
breakdown agent) when Duong approves. Aphelios should produce a task list
covering:

- WalletStudio backend (`~/Documents/Work/mmp/workspace/wallet-studio/`):
  new handler `SuperAdminInviteUserToOrg`, route registration, tests
  (unit for handler, xfail-first per TDD rule 12). One PR.
- WalletStudio MCP (`~/Documents/Work/mmp/workspace/mcps/wallet-studio/`):
  API wrapper, tool contract, server pre-interceptor with allowlist gate.
  One PR.
- Devops config (Heimerdinger's surface): add Duong's email to
  `Config.SuperAdmin` on stg and prod. Manual step, not an agent PR.
- Strawberry memory schema: directory
  `agents/sona/memory/self-invite-audit/` + README.md template.
  One direct-to-main commit.

Kayn (personal-side breakdown) is **not** the right agent here — this is
work-concern throughout.

Reasoning for Aphelios over Kayn: concern is `work`, all implementation
PRs land on the work-side repos, Aphelios has the conventions.

## Tasks

_Added 2026-04-24 by Aphelios (D1A inline breakdown). Owner: Sona (work-concern
coordinator). Executor-tier convention: **normal-track** = Jayce (TS) / Vi
(Go); **complex-track** = Viktor (deep-reasoning impl) / Rakan (devops)._

### Decisions embedded at breakdown time

- **OQ-1 (Config.SuperAdmin delivery)** — **Routed to Heimerdinger.** Blocks
  PR 4 only. Tracked as T15; see dependency chain. Does not block PRs 1–3.
- **OQ-2 (`STRAWBERRY_AGENT=sona` belt-and-braces gate)** — **Accepted as
  default ON for v1.** Cheap defense-in-depth for a founder-only tool. Wired
  in T9 alongside the Duong-allowlist check.
- **OQ-3 (`reason` field structured vs free-text)** — **Free-text for v1**,
  with a suggested-format doc comment in the tool schema
  (`"<category>: <detail>"`, e.g. `"customer-support: debug issuer X"`).
  Ship simple; revisit if audit-grep friction emerges.
- **OQ-4/5/6 (email-vs-userid, postgres-MCP, Metabase-MCP)** — **Deferred.**
  Option B scaffolding (T13) is dormant-by-design per Duong's approval-time
  amendment, so the three Option-B-adjacent questions stay unresolved until
  B is revived.

### Scope reinforcement — Option B dormancy (binding)

Per Duong's approval amendment: **Option B is configured but not filled in
— no env, no secrets, structural + documentation only.** T13 is a stub-and-
doc task. **No task under this breakdown may** (a) add env vars, (b) add
secret placeholders, (c) wire a postgres/Metabase connection, or (d)
exercise an Option-B code path at runtime. Violations are a breakdown
failure; escalate to Sona.

### Executor tiers

- **Vi** (normal, Go) — T2, T4, T5, T8
- **Viktor** (complex, Go deep-reasoning) — T3
- **Jayce** (normal, TS/MCP) — T7, T9, T10, T12, T13
- **Seraphine** (normal, tests/docs) — T1, T6, T11, T14
- **Heimerdinger** (devops, human-gated) — T15, T16
- **Aphelios** (breakdown, cleanup only) — T17

### PR grouping

- **PR-1 (wallet-studio repo, Go backend)** — T1–T6. Ships the
  `SuperAdminInviteUserToOrg` handler + route.
- **PR-2 (mcps/wallet-studio repo, TS)** — T7–T12. Ships the
  `walletstudio_superadmin_invite_user_to_org` tool + audit-memory schema
  in the Strawberry repo (same PR for the MCP code; the memory schema is
  a separate direct-to-main commit on strawberry-agents since plans/docs
  do not go through PR — see T11).
- **PR-3 (mcps/wallet-studio repo, TS, optional parallel to PR-2)** —
  T13. Option B dormant scaffold + doc.
- **Ops-4 (one-time human config edit, no PR)** — T15–T16. Heimerdinger
  lands Duong in `Config.SuperAdmin` on stg then prod.
- **Direct-to-main (strawberry-agents)** — T11 (audit-memory schema),
  T14 (runbook).

### Tasks — PR-1: tse backend endpoint

- [ ] **T1** — Draft handler contract + audit-log structured field list in
  an ADR-stub comment at the top of the new handler file. estimate_minutes:
  20. Files:
  `~/Documents/Work/mmp/workspace/wallet-studio/core/tse/api/v3/superadmin_invites.go`.
  DoD: file exists with package decl + a top-of-file block comment naming
  request body schema (§4.2), response schema, and the audit log field set
  from §A.1; no handler body yet. Owner: Seraphine. depends-on: none.
  blocks: T2, T3.

- [ ] **T2** — xfail unit test for `SuperAdminInviteUserToOrg` happy path
  (new user, invite to org as OrgOwner). estimate_minutes: 40. Files:
  `core/tse/api/v3/superadmin_invites_test.go`. DoD: test compiles, runs
  via `go test ./core/tse/api/v3/... -run TestSuperAdminInviteUserToOrg_NewUserOrgOwner`,
  and fails with a clear "not implemented" error. Test references this plan
  (`// plan: 2026-04-24-self-invite-to-walletstudio-org`) per Rule 12.
  Owner: Vi. depends-on: T1. blocks: T3.

- [ ] **T3** — Implement `SuperAdminInviteUserToOrg` handler — the four
  semantic branches from §A.1 (create-user-and-invite, add-to-org,
  update-role, already-member), response shape from §4.2, structured audit
  log line. estimate_minutes: 60. Files: `core/tse/api/v3/superadmin_invites.go`.
  DoD: T2 passes; all four branches covered by separate sub-tests added in
  T5; handler calls the same user-creation + invite-email code path as
  `a.InviteUsers` (reuse, do not fork); audit log line emitted via the
  existing admin-action log sink (whichever sink `TransferProjectToNewOrgHandler`
  uses today — reuse for consistency). Owner: Viktor (complex-track due to
  branching logic + reuse of invite code path). depends-on: T2. blocks: T4, T5.

- [ ] **T4** — Wire the route: add
  `admin.POST("/invite-user-to-org", SuperAdminInviteUserToOrg(a))` under
  the existing `admin` group. estimate_minutes: 20. Files:
  `core/tse/api/v3/api.go`. DoD: route compiles, shows up under
  `/v3/superadmin/invite-user-to-org`, gated by existing
  `CheckPermissionSuperAdmin()` middleware. Owner: Vi. depends-on: T3.
  blocks: T6.

- [ ] **T5** — Expand T2 into full branch coverage: add unit tests for
  (a) existing user, not a member → added, (b) existing user, member with
  different role → role updated with `previousRole` populated, (c) existing
  user, member with same role → `already_member` no-op, (d) unknown org →
  400, (e) malformed body → 400, (f) caller not SuperAdmin → 403 via
  middleware. estimate_minutes: 60. Files:
  `core/tse/api/v3/superadmin_invites_test.go`. DoD: all six branch tests
  pass; coverage ≥ 90% for `superadmin_invites.go`; no test uses
  `--no-verify`. Owner: Vi. depends-on: T3. blocks: T6.

- [ ] **T6** — Open PR-1 against `wallet-studio` main; PR body includes link
  to this plan, the four semantic branches table, and `QA-Waiver: backend
  endpoint, no UI or user-flow surface`. estimate_minutes: 20. Files: PR
  metadata only. DoD: PR green on required checks (unit, tdd-gate); one
  approving review from a non-author identity (Rule 18); ready to merge.
  Owner: Seraphine. depends-on: T4, T5. blocks: T15.

### Tasks — PR-2: mcps/wallet-studio tool + strawberry audit schema

- [ ] **T7** — Add API wrapper
  `superAdminInviteUserToOrg({orgId, email, role, reason})` in the static
  operations file; includes request construction, `X-API-Key` / `X-Client-Reason`
  / `X-Client-Agent: "sona-self-invite"` headers, response typing.
  estimate_minutes: 40. Files:
  `~/Documents/Work/mmp/workspace/mcps/wallet-studio/src/walletstudio-api.ts`.
  DoD: function exported, typed against the response shape from §4.2,
  passes `tsc --noEmit`; no runtime call yet. Owner: Jayce. depends-on:
  T6 (contract must be stable before TS client is built — or uses mock
  response shape if PR-1 is still in review). blocks: T9, T10.

- [ ] **T8** — (Placeholder — no task. Slot reserved to keep numbering
  aligned with the ADR's conceptual sections. Skip in execution.)
  estimate_minutes: 0.

- [ ] **T9** — Add tool contract + schema for
  `walletstudio_superadmin_invite_user_to_org` (args `{orgId, email, role,
  reason}`, `role` enum excludes `SuperAdmin` per §4.3). Includes description
  string explicitly naming SuperAdmin as the required caller role and noting
  Duong-founder-only allowlist. estimate_minutes: 40. Files:
  `mcps/wallet-studio/src/tool-contracts.ts`. DoD: contract compiles; zod/JSON
  schema rejects `role="SuperAdmin"`; `reason` marked required with a doc
  comment suggesting `"<category>: <detail>"` format (OQ-3 decision). Owner:
  Jayce. depends-on: T7. blocks: T10, T11.

- [ ] **T10** — Implement preInterceptor gate in `server.ts`:
  (a) call `GET /v3/me` with configured API key → `configured_email`,
  (b) check `configured_email ∈ DuongAllowlist` (env
  `WALLET_STUDIO_MCP_SELF_INVITE_ALLOWLIST`, fail-closed if unset),
  (c) check target `email` arg ∈ same allowlist (prevents inviting
  non-Duong identities),
  (d) **OQ-2 gate:** check `process.env.STRAWBERRY_AGENT === "sona"`;
  reject otherwise with "self-invite tool is gated to the Sona agent",
  (e) forward upstream on success. estimate_minutes: 60. Files:
  `mcps/wallet-studio/src/server.ts`. DoD: xfail-first test in T12 covers
  all four reject paths + happy path; `tsc --noEmit` clean; no allowlist
  values hardcoded. Owner: Jayce. depends-on: T9. blocks: T12.

- [ ] **T11** — Create audit-memory schema directory + README template in
  strawberry-agents. **Direct-to-main commit** (Rule 4 — this is a plan/memory
  artifact, not code). estimate_minutes: 30. Files:
  `agents/sona/memory/self-invite-audit/README.md`,
  `agents/sona/memory/self-invite-audit/.gitkeep`. DoD: README documents the
  YAML frontmatter schema from §5.3 verbatim, plus a one-line example entry
  filename (`2026-04-24-143022-ORG-ABC.md`); commit message `chore: seed
  sona self-invite audit memory schema` per Rule 5 (non-apps path). Owner:
  Seraphine. depends-on: none (can run parallel to PR-1/PR-2). blocks: T12.

- [ ] **T12** — Wire MCP tool to write an audit-memory entry after a
  successful upstream call: Node-side helper that `fs.writeFile`s to
  `agents/sona/memory/self-invite-audit/<ts>-<orgId>.md` with the §5.3 YAML
  frontmatter populated from the upstream response (`upstream_action`,
  `upstream_request_id`) + the call args. xfail-first test exists. Plus:
  xfail tests for T10's four reject paths. estimate_minutes: 60. Files:
  `mcps/wallet-studio/src/audit-memory.ts` (new),
  `mcps/wallet-studio/src/server.test.ts` (or analogue). DoD: unit tests
  for T10 reject paths + T12 audit-write pass; tool end-to-end happy path
  writes a file at the expected path; `tsc --noEmit` clean. Owner: Jayce.
  depends-on: T10, T11. blocks: T14.

### Tasks — PR-3 (optional, parallel): Option B dormant scaffold

- [ ] **T13** — Option B dormant scaffold. Per Duong's approval amendment:
  **structural + documentation only.** Create an empty module
  `mcps/wallet-studio/src/option-b-fallback.ts` with (i) a top-of-file
  JSDoc block citing §3.2 of this ADR, (ii) unimplemented function
  signatures for `harvestOrgOwnerApiKeyViaPostgres(orgId)` and
  `harvestOrgOwnerApiKeyViaMetabase(orgId)` that `throw new Error("Option
  B is dormant-by-design; see plan 2026-04-24-self-invite-to-walletstudio-org.md
  §3.2. Do not wire without a fresh Azir ADR.")`, (iii) a `README-OPTION-B.md`
  sibling in the same directory explaining the when/why/how-to-revive.
  **Forbidden in this task:** adding env vars, adding secret placeholders,
  wiring any data source, importing a postgres client, importing a Metabase
  client. estimate_minutes: 45. Files:
  `mcps/wallet-studio/src/option-b-fallback.ts`,
  `mcps/wallet-studio/src/README-OPTION-B.md`. DoD: both files exist; `tsc
  --noEmit` clean (signatures compile); functions throw on call; no env
  vars added to `.env.example` or equivalent; grep for `process.env` in
  the new file returns zero matches. Owner: Jayce. depends-on: none (can
  ship before or after PR-2). blocks: none.

### Tasks — Direct-to-main: runbook

- [ ] **T14** — Write a short runbook at
  `architecture/runbooks/sona-self-invite.md` covering:
  (1) how to call the tool from a Sona session,
  (2) where audit entries land (both WalletStudio audit log table and the
  Strawberry memory dir from T11),
  (3) how to revoke Duong's SuperAdmin (remove from `Config.SuperAdmin`,
  redeploy tse),
  (4) how to revive Option B if ever needed (pointer to T13's README).
  estimate_minutes: 40. Files:
  `architecture/runbooks/sona-self-invite.md`. DoD: runbook committed
  direct-to-main (Rule 4, `chore:` prefix); cross-linked from this plan
  via an "Implementation artifacts" section appended in a follow-up
  (not required for T14 itself). Owner: Seraphine. depends-on: T12.
  blocks: none.

### Tasks — Ops-4: one-time config edit (human-gated)

- [ ] **T15** — **Heimerdinger task, blocked on OQ-1 resolution.** Determine
  where tse loads `Config.SuperAdmin` from on stg and prod (k8s ConfigMap /
  GCP Secret Manager / committed YAML) and document the answer in
  `architecture/runbooks/sona-self-invite.md` §5 (appended to T14 or as a
  follow-up edit). Then add Duong's founder email to the stg `Config.SuperAdmin`
  list and redeploy/reload tse on stg. estimate_minutes: 45 (assuming OQ-1
  is ConfigMap or Secret Manager; longer if it turns out to be a
  committed-YAML redeploy). Files: tse stg config source (path TBD by
  Heimerdinger). DoD: Duong's email appears in the stg SuperAdmin list;
  a curl to `GET /v3/me` with his API key against stg returns his user
  row; a curl to `POST /v3/superadmin/invite-user-to-org` against stg
  (after PR-1 deploys) returns 200. Owner: Heimerdinger. depends-on:
  T6 (PR-1 merged + deployed to stg). blocks: T16.

- [ ] **T16** — **Heimerdinger task, prod rollout.** Mirror T15 on prod
  only after (a) T15 passes on stg, (b) T12 merged, (c) one end-to-end
  self-invite executed successfully on stg by Sona. estimate_minutes: 30.
  Files: tse prod config source. DoD: same as T15 but for prod; prod
  post-deploy smoke (Rule 17) green; rollback path tested. Owner:
  Heimerdinger. depends-on: T15, T12. blocks: none.

### Tasks — cleanup

- [ ] **T17** — After T16 lands, request Orianna to promote this plan
  `approved → in-progress` (on first PR merge) and then `in-progress →
  implemented` (after T16 green). estimate_minutes: 10. Files: this plan's
  location only. DoD: plan moved under `plans/implemented/work/`;
  `Promoted-By: Orianna` trailer present. Owner: Aphelios (request-only;
  Orianna executes the move). depends-on: T16. blocks: none.

### Dependency graph (critical path)

```
T1 (20) → T2 (40) → T3 (60) → T4 (20) → T6 (20) → T15 (45) → T16 (30) → T17 (10)
                           ↘ T5 (60) ↗
```

Parallel branches:
- PR-2 chain: T7 (40) → T9 (40) → T10 (60) → T12 (60) → T14 (40)
- PR-2 schema: T11 (30) joins at T12
- PR-3: T13 (45) — fully parallel to everything else
- T8 is a reserved no-op (0 min)

**Critical path** = T1 → T2 → T3 → T5 (longest branch, 60 vs T4's 20) → T6
→ T15 → T16 → T17 = **20 + 40 + 60 + 60 + 20 + 45 + 30 + 10 = 285 minutes**
of serial work (≈ 4h 45min), not counting Heimerdinger's human-gated
scheduling latency on T15/T16.

Secondary path (PR-2 chain, gated on T6 for contract stability):
T6 → T7 → T9 → T10 → T12 → T14 = 20 + 40 + 40 + 60 + 60 + 40 = **260 min**
from T6 forward, running in parallel with T15.

### Recommended first dispatch

**T1** (Seraphine, 20 min) — draft the handler contract comment. This
unblocks both T2 (xfail test, Vi) and T3 (impl, Viktor) and is the only
task with no dependencies that lives on the critical path. Dispatching T1
first also establishes the audit-log field shape which T12's audit-memory
writer needs to align with downstream.

Parallel-first dispatches (same batch as T1): **T11** (Seraphine, schema
dir — direct-to-main, zero code risk) and **T13** (Jayce, Option B dormant
scaffold — zero coupling to PR-1 or PR-2). Both can start immediately.

### Open questions — status

- **OQ-1** (Config.SuperAdmin source) — routed to Heimerdinger via T15;
  not a blocker for PRs 1–3.
- **OQ-2** (STRAWBERRY_AGENT=sona gate) — resolved: **yes, wired in T10**.
- **OQ-3** (reason field shape) — resolved: **free-text with format-hint
  comment, wired in T9**.
- **OQ-4** (email-vs-userid for allowlist) — deferred; not v1.
- **OQ-5** (postgres MCP to tse DB) — deferred; Option B dormant.
- **OQ-6** (Metabase MCP availability) — deferred; Option B dormant.

## Orianna approval

- **Date:** 2026-04-24
- **Agent:** Orianna
- **Transition:** proposed → approved
- **Rationale:** ADR has a clear owner (Azir), a decisive recommendation (Option A — SuperAdmin), concrete prerequisite work (A.1 backend endpoint, A.2 config, A.3 MCP tool), a documented fallback (Option B), and a well-specified audit + allowlist design. The three open questions in §6.3 are breakdown-time decisions, not gating blockers. Duong gave verbal approval to Sona after reviewing Azir's ADR at commit 9d8bd5ee.
- **Amendment (per Duong):** Option B (API-key-harvest) is to be treated as "scaffolded, dry, documented for emergency use, never wired live." Structural scaffolding and documentation only — no env vars, no secrets, no live connections. This tightens §3.2 beyond the ADR's "fallback only" framing. Aphelios must respect this during task breakdown: Option B surface is documentation/stubs at most; do not create any task that wires it to real data sources.
