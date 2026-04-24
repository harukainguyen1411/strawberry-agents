---
status: proposed
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
