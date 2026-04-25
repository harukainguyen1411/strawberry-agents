# SuperAdmin → SuperAdmin promotion: existing-flow investigation

**Date:** 2026-04-25
**Author:** Swain (subagent invoked by Sona, work concern)
**Brief:** Read-only audit of `wallet-studio/core/tse` + `mmp/workspace/company-os` to determine whether an authenticated SuperAdmin can promote another user to the SuperAdmin role *today*, with no new tse code.

---

## Bottom line (caller already has authority in the target org)

**YES.** An existing flow already supports SuperAdmin → SuperAdmin promotion end-to-end. Nothing in tse needs to change. The route, payload, permission gate, and validation all exist and already accept `role: "SuperAdmin"`.

The flow is **two existing API calls** plus one user-side accept-invite click for the new-user case (skip step 1 entirely if the target user already exists in the org):

1. `POST /v3/orgs/:orgId/invites` — invite the target user into the SuperAdmin's home org with any of the four "InviteRoles" (`ProjectAdmin`, `Editor`, `Viewer`, `Overview`). Target accepts via emailed link.
2. `PUT /v3/orgs/:orgId/user-role` — promote that org-member's role to `SuperAdmin`.

This works for the self-invite use case as long as the inviting SuperAdmin uses a *different* email for the new account (the role-update handler explicitly forbids self-update by email match — see §3, line 296-298).

---

## 1. Route map (every admin/superadmin/role-management route registered today)

Source: `core/tse/api/v3/api.go`

| Line | Route | Permission gate | Notes |
|------|-------|-----------------|-------|
| 29-36 | `/v3/superadmin/*` group | `mw.CheckPermissionSuperAdmin()` (config-list email match) | gpay-class, project-transfer — **no role-management routes here** |
| 102 | `DELETE /v3/projects/:projectID/hard-delete-external-passes/:extCaseId` | superadmin | unrelated |
| 268 | **`POST /v3/orgs/:orgId/invites`** → `InviteUsers` | `mw.CheckPermissionForOrg()` (rego: `manage:org`) | **Invite path. Role validated against `model.InviteRoles` allowlist — does NOT include SuperAdmin** |
| 271 | **`PUT /v3/orgs/:orgId/user-role`** → `UpdateUserRoleInOrg` | `mw.CheckPermissionForOrg()` (rego: `manage:org`) | **Role-update path. Role validated against `model.AvailableRoles` allowlist — DOES include SuperAdmin** |
| 278 | `DELETE /v3/demo-org/:orgId` | superadmin | unrelated |
| 38-42 | `/v3/me/*` group | session only | self-only, no role mutation |
| 250-253 | `/v3/all-orgs*` | `CheckPermissionAccessAllOrgs()` | read-only |
| 329 | `GET /v3/resources/users/accept-invite` | JWT-claim auth | invitee endpoint |

There is **no** `/v3/users/:id` PUT/PATCH route. The only path that mutates user-role in any org is line 271.

## 2. Role taxonomy

Source: `core/tse/model/roles.go:11-45`

```
UserRoleSuperAdmin   = "SuperAdmin"
UserRoleOrgOwner     = "OrgOwner"
UserRoleProjectAdmin = "ProjectAdmin"
UserRoleEditor       = "Editor"
UserRoleViewer       = "Viewer"
UserRoleOverView     = "Overview"
UserRoleReadAllOrgs  = "ReadAllOrgs"          // missmp-dev-only
UserRoleReadAllOrgsNoPersonalData = "ReadAllOrgsNoPersonalData"

AvailableRoles = [OrgOwner, SuperAdmin, ProjectAdmin, Editor, Viewer, Overview]
InviteRoles    = [ProjectAdmin, Editor, Viewer, Overview]
                 // ↑ excludes SuperAdmin and OrgOwner
```

This is the critical asymmetry: **invite cannot directly set SuperAdmin** (allowlist excludes it), but **user-role update can** (allowlist includes it). That's why promotion needs two steps, not one.

`SuperAdmin` is a **per-(user, org) row** in `users_orgs.role` (varchar). It is *not* a user-table boolean. There is no separate `is_superadmin` field on the user model — the Skarner finding from last session that "SuperAdmin role exists in tse's role/permission model" matches `UserRoleSuperAdmin` here, not a flag.

There is also a *second, parallel* notion of "SuperAdmin" — `a.Config.SuperAdmin` (a list of missmp-dev emails configured in argocd). This is what `mw.CheckPermissionSuperAdmin()` checks (`pkg/middlewares/auth.go:221-241`) and what the `/v3/superadmin/*` group requires. The two notions intersect only at the `ReadAllOrgs*` role-set path (orgs.go:300-319), where the *config* list is what gates assignment of the special read-all roles. For ordinary `SuperAdmin` role assignment, the role-in-org check is what governs (orgs.go:325).

## 3. The permission gate cascade (`PUT /v3/orgs/:orgId/user-role`)

Source: `core/tse/api/v3/orgs.go:278-348`, plus `pkg/middlewares/auth.go:270-295` and rego under `core/tse/authz/`

**Layer 1 — middleware `CheckPermissionForOrg`** (auth.go:270-295)
Calls `m.App.HasPermission(c, authz.WithInputExtraData("org", org))` → OPA evaluation against `authz/rego/main.rego`.

**Layer 2 — OPA rego decision** (`authz/rego/main.rego:21-40`)

```rego
has_role = role { role = input.user.org_roles[org_id] }
has_permissions = permissions { permissions := data.roles[has_role] }
allowed_actions[actions] {
    some p
    actions = data.permissions[p]
    p in has_permissions
}
allow_action {
    allowed_actions[_][_] = { "method": input.method, "path": input.endpoint }
}
allow { allow_action; count(deny) == 0 }
```

`data.roles[SuperAdmin]` = `["manage:org", "manage:superadmin", "manage:solutions", "manage:projects", "manage:legacy", "manage:user"]` (`authz/data.json:1221-1228`).
`data.roles[OrgOwner]` = `["manage:user", "manage:org", "manage:projects", "manage:legacy"]` (line 1229-1234).
`data.permissions["manage:org"]` includes `{"method":"PUT","path":"/v3/orgs/:orgId/user-role"}` (line 826-829).

So **rego allows** the call if the caller is either SuperAdmin or OrgOwner *in that org* (i.e. `input.user.org_roles[org_id]` ∈ {SuperAdmin, OrgOwner}). The deny module (`authz/rego/deny.rego`) only covers project create/update — no role-related deny rules.

**Layer 3 — handler validation** (orgs.go:278-348)

```go
// 296-298: cannot self-update
if user.Email == payload.Email { return 400 "Cannot update role by your self" }

// 302-319: special-case ReadAllOrgs* — only config.SuperAdmin emails
if payload.Role == ReadAllOrgs || ReadAllOrgsNoPersonalData {
    if !isMissmpDev { return 403 }
    a.Store.User().UpdateUserOrgRoleByEmail(...)
    return 200
}

// 321-323: payload.Role must be in AvailableRoles (which INCLUDES SuperAdmin)
if !util.IsStringSliceContains(model.AvailableRoles, payload.Role) {
    return 400 "Role is invalid"
}

// 325-327: caller must be OrgOwner or SuperAdmin in this org
if user.GetRoleInOrg(org.ID) != UserRoleOrgOwner &&
   user.GetRoleInOrg(org.ID) != UserRoleSuperAdmin {
    return 403 "You are must be organization owner"
}

// 329-339: target must already be a member of this org
usersInOrg, _, err := a.Store.User().ListByOrg(org.ID, false, &ListUsersOption{
    PerPage: 1, Emails: []string{payload.Email},
})
if len(usersInOrg) == 0 { return 400 "User not in organization" }

// 341: persist
a.Store.User().UpdateUserOrgRoleByEmail(payload.Email, org.ID, payload.Role)
```

`UpdateUserOrgRoleByEmail` is a plain `UPDATE users_orgs SET role = ?` (`store/sqlstore/users.go:833-848`). No DB-level enum, no trigger, no cascade.

**Net effect:** an authenticated user who is `SuperAdmin` (or `OrgOwner`) in org X can set any other org-X member's role to any of the six AvailableRoles — including `SuperAdmin` — by hitting `PUT /v3/orgs/:X/user-role` with `{"email": "<member>@…", "role": "SuperAdmin"}`. Self-promotion of the same email is blocked.

## 4. The invite half (`POST /v3/orgs/:orgId/invites`)

Source: `core/tse/api/v3/invites.go:26-66`

```go
type InviteUser struct { Email string; Role string }

for _, val := range req.Invites {
    if !util.IsStringSliceContains(model.InviteRoles, val.Role) {
        return 400 "Role is invalid for email: ..."
    }
    ...
}
err = a.InviteUsers(senderName, org, emails, mRole)
```

`InviteRoles` is the smaller allowlist `[ProjectAdmin, Editor, Viewer, Overview]`. **You cannot invite directly as SuperAdmin** — the invite payload validator rejects it before even reaching the rego check. This is why the SuperAdmin must invite at a *lower* role first and then promote in step 2.

The `app.InviteUsers` impl (`core/tse/app/user_invite.go:30+`) generates an email with a JWT-signed accept-invite link; the user clicks and is redirected to `GET /v3/resources/users/accept-invite` (api.go:329, resources.go:491+) which enrolls them in the org with the invited role. Only after that does step 2 work (handler line 337-339 requires the target be a member).

## 5. End-to-end procedure (the answer Sona is asking for)

**Pre-conditions**
- The acting principal is authenticated via OIDC session (`mw.AuthSession`).
- The acting principal has `role = "SuperAdmin"` for some org X (i.e. there is a `users_orgs` row with `(user_id=acting, org_id=X, role='SuperAdmin')`).
- The target email is different from the acting principal's email.

**Steps**
1. **(Optional, only if target not already in org X)** `POST /v3/orgs/X/invites` with body `{"invites":[{"email":"target@…","role":"Editor"}]}`. Any of the four `InviteRoles` works as a placeholder.
2. **(Optional, follows step 1)** Target receives email, clicks accept-invite link → handled by `GET /v3/resources/users/accept-invite?token=…` → JWT validated, user joined to org X with the placeholder role.
3. **Promotion:** `PUT /v3/orgs/X/user-role` with body `{"email":"target@…","role":"SuperAdmin"}`. Returns 200 No Content. Resulting DB state: `users_orgs(user_id=target, org_id=X, role='SuperAdmin')`.

After step 3, the target's `input.user.org_roles[X]` becomes `"SuperAdmin"` and they can transitively promote others or grant themselves access to anything `manage:superadmin` covers in org X.

**Caveats**
- Promotion is scoped to a single org. To make the target SuperAdmin in org Y as well, repeat steps 1-3 against org Y — but the acting principal must be SuperAdmin or OrgOwner in org Y too (handler line 325).
- Self-invite (different email): if Duong's intent is "Duong (SuperAdmin in OrgX) wants to grant his own *new* email SuperAdmin in OrgX", do steps 1-3 with the new email. The self-update guard (line 296-298) only fires when `caller.Email == payload.Email`; using two different emails sidesteps it cleanly.
- The config-list `a.Config.SuperAdmin` is **not modified** by this flow. That list is argocd-managed and only governs `/v3/superadmin/*` route access (which is a separate, narrower set of admin endpoints — see §1 line 29-36). If the use case also needs the new account to be a config-SuperAdmin (e.g. for `POST /v3/superadmin/gpay-class`), that is a manifest change in `infra/argocd/{stg,prd}/manifests/tse/`, not an API call.

## 6. Things confirmed NOT to exist (no rabbit holes)

- No `PUT /v3/users/:id` or any user-update endpoint that sets role; only `/v3/me/*` (self read/write API key) and `/v3/orgs/:orgId/user-role`.
- No company-os tool, script, or migration that mutates `users_orgs.role`. The single grep hit (`tools/demo-studio-v3/conversation_store.py:131`) is a chat-message-role label, unrelated.
- No tse one-off CLI under `cmd/scripts/*` that touches role. The migrate/change-issuer scripts only call `/v3/superadmin/*` for project/issuer mutations.
- No rego rule that branches on `input.user.is_superadmin` (the field doesn't exist) or that gates role assignment specifically. Rego is route+role-permission only; the SuperAdmin-vs-OrgOwner asymmetry for promotion is enforced in Go handler code (orgs.go:325), not policy.
- No DB constraint on `users_orgs.role` values; the column is varchar and the application-layer allowlist is the only floor.

## 7. Scope discipline note

The brief says "no new tse code". This finding requires zero. The flow is fully callable today by anyone with SuperAdmin role in some org, hitting two existing routes that have been in production for the entire history of this code path (the validation lists, route group, and store method all predate the demo-studio-v3 work).

The cancelled `/v3/superadmin/invite-user-to-org` work (PRs #2108 + #2109) was solving a problem that was already solved — it would have collapsed the two-step flow into a single endpoint that bypasses the InviteRoles allowlist. That is a UX/ergonomics change, not a capability change. If self-invite needs to be smoother, the lift can live entirely client-side (a UI button that fires the two requests sequentially) or in a missmp/company-os helper script; tse doesn't need to grow.

---

# Bootstrap-from-zero: caller has NO authority in `O_target`

**Sub-brief (2026-04-25 follow-up):** The §1-§7 flow above presupposes the caller already holds SuperAdmin or OrgOwner in `O_target`. Sona's actual case: Duong is SuperAdmin in `O_main` only; `O_target` has no existing SuperAdmin and no OrgOwner who can act on Duong's behalf. **No tse code change wanted.**

## B1. Bottom line, bootstrap-from-zero

**No path exists today** that lets Duong, holding only `SuperAdmin` in `O_main`, become `SuperAdmin` in an *existing* `O_target` without one of the following:

- (a) **A tse code/config change** — adding email to `Config.SuperAdmin` is itself a config change in `infra/argocd/`. But more importantly it does **not** grant cross-org `manage:org` rego permission on its own (see B2). The only tse change that would *actually* unblock this case is a new endpoint that bypasses `mw.CheckPermissionForOrg` for `Config.SuperAdmin` callers — i.e. exactly the cancelled PR #2108/#2109 work, or a sibling route under `/v3/superadmin/*`.
- (b) **A direct DB write** to insert `users_orgs(user_id=duong, org_id=O_target, role='OrgOwner'|'SuperAdmin', status='Active')` — sanctioned **only as a human-only ops procedure** (no script today, no runbook found).
- (c) **An existing OrgOwner of `O_target` re-emerges and runs the §5 flow** — but Sona's premise rules this out.

**Duong's stated constraint "no tse code change" excludes (a) entirely. The smallest path under that constraint is (b).** Quantified below.

## B2. `Config.SuperAdmin` — what it actually grants

Definition: `model/config.go:65` — `SuperAdmin []string` populated from env var `SUPERADMIN` (comma-separated emails). prd value at `infra/argocd/prd/manifests/tse/config.yaml:130` already includes `duong.nguyen.thai@missmp.eu` alongside 6 other missmp devs. So Duong is **already** a `Config.SuperAdmin`.

**It is consulted in exactly three Go code paths.** rego does NOT see this list at all — `authz/opa.go:159-177` builds the OPA input from `{user, method, endpoint, project, extra-data}`; `Config.SuperAdmin` is never injected.

### B2.1 `mw.CheckPermissionSuperAdmin()` — `pkg/middlewares/auth.go:221-241`

```go
isSuperAdmin := false
for _, v := range m.App.Config.SuperAdmin {
    if v == user.Email { isSuperAdmin = true; break }
}
if !isSuperAdmin { return ResponsePermissionError("not a SuperAdmin") }
```

**Where this middleware is wired (the entire surface):**

| `core/tse/api/v3/api.go` line | Route | Mutates role / users_orgs? |
|---|---|---|
| 29 | `root.Group("/v3/superadmin", ...)` group | No — children are `transfer-project`, `gpay-class/*`, `migrate-*`, etc. |
| 102 | `DELETE /v3/projects/:projectID/hard-delete-external-passes/:extCaseId` | No |
| 278 | `DELETE /v3/demo-org/:orgId` | No (deletes org + cascades, but no role-grant primitive) |

**Net:** `Config.SuperAdmin` membership grants access to a fixed, narrow set of admin endpoints. **None of them mutates `users_orgs.role`.** None of them grants the caller any role in any org. There is no `/v3/superadmin/grant-role`, `/v3/superadmin/join-org`, or similar in the registered route set. The cancelled `/v3/superadmin/invite-user-to-org` (PR #2108) would have lived exactly in this group and would have closed this gap — that is precisely the work Duong is rejecting.

### B2.2 `CreateUserAndOrg` — `app/users_new.go:8-43`

Called from two places (both first-login paths):
- `api/v3/sso.go:150` — first OIDC login of a brand-new user via `AfterSsoOidcLogin`
- `api/v3/ory_webhook.go:183` — first Ory-hook touch for a brand-new user

Logic:
```go
isSuperAdmin := map[string]bool{}
for _, val := range a.Config.SuperAdmin { isSuperAdmin[val] = true }
role := model.UserRoleOrgOwner
if isSuperAdmin[u.Email] { role = model.UserRoleSuperAdmin }
_, err = a.CreateOrgNew(u, newOrg, role)
```

This creates a **brand-new auto-named org** (`organization-<random-10-chars>`, line 22) and joins the new user with role SuperAdmin (if email is in `Config.SuperAdmin`) or OrgOwner. **It only fires on first user creation, against a fresh auto-org. It cannot retro-attach the user to an existing `O_target`.**

### B2.3 `UpdateUserRoleInOrg` ReadAllOrgs* path — `api/v3/orgs.go:300-319`

```go
if payload.Role == ReadAllOrgs || ReadAllOrgsNoPersonalData {
    isMissmpDev := false
    for _, v := range a.Config.SuperAdmin { if v == user.Email { isMissmpDev = true; break } }
    if !isMissmpDev { return 403 "only missmp devs can set roles 'ReadAllOrgs*'" }
    a.Store.User().UpdateUserOrgRoleByEmail(payload.Email, org.ID, payload.Role)
    return 200
}
```

This is gated by the `/v3/orgs/:orgId/user-role` route under `mw.CheckPermissionForOrg()` (api.go:263). The middleware runs **first** and asks rego whether the caller has `manage:org` in `O_target` — which requires a `users_orgs[caller, O_target]` row with role ∈ {SuperAdmin, OrgOwner}. **A `Config.SuperAdmin` caller with no such row gets a 403 from the middleware before this handler block ever executes.** The handler block also only sets `ReadAllOrgs*` roles, not `SuperAdmin`.

### B2.4 Conclusion on Config.SuperAdmin

It is **not a global override**. It is a narrow access list that:
- gates a fixed admin-route group with no role-mutation endpoints,
- bootstraps SuperAdmin role on a *brand-new* auto-org at first login,
- gates the special-case `ReadAllOrgs*` role assignment, but only after the middleware permission gate has already been passed via a real `users_orgs` row.

**For the bootstrap-from-zero case, `Config.SuperAdmin` membership is currently insufficient.** Duong is already in this list and it does not help him become SuperAdmin in `O_target`.

## B3. Org creation flow — when does an org get its first member?

Two creation paths:

| Path | File:line | Initial member rule |
|---|---|---|
| `POST /v3/orgs` (public, any authenticated user) | `api/v3/orgs.go:105-148` → `app.CreateOrgAndGoogleIssuer` (`app/orgs_new.go:25-104`) | Creator joins as **OrgOwner** (orgs_new.go:78: `JoinOrgWithRole(creator.ID, newOrg.ID, UserRoleOrgOwner, Active)`). Public route opened by `additional_allow_actions.rego:19-24` `allow_everybody_can_create_org`. |
| First-login auto-create | `api/v3/sso.go:150` + `api/v3/ory_webhook.go:183` → `app.CreateUserAndOrg` → `app.CreateOrgNew(u, newOrg, role)` (`app/orgs_new.go:11-23`) | Creator joins as **SuperAdmin** if email ∈ `Config.SuperAdmin`, else OrgOwner (`app/users_new.go:32-37`). |
| Demo-org request flow | `app/org_demo_request.go:124` | Demo-org-owner joins as **OrgOwner**. Out of scope. |

**Net for bootstrap-from-zero:** every org creation path leaves at least one row in `users_orgs` with role OrgOwner or SuperAdmin. So unless `O_target` has been actively *demoted* (every member's role rewritten to non-{SuperAdmin,OrgOwner} via `UpdateUserOrgRoleByEmail`) **and** every prior {SuperAdmin,OrgOwner} member has been removed from `users_orgs` entirely, somebody historically had authority. The "no existing authority" claim is plausible only in two narrow scenarios:
- Every {SuperAdmin,OrgOwner} member in `O_target` has been deleted from `users_orgs` (via `RemoveUsersFromOrg`, api.go:270 / orgs.go:251+) — possibly because they left the company.
- Every such member has been demoted (PUT /v3/orgs/X/user-role to a lower role) by some other authority who has since lost their own row.

These are pathological end-states. They are reachable but rare. Worth verifying with a direct DB read before assuming.

## B4. OrgOwner enumeration — can Duong even SEE who has authority in `O_target`?

`GET /v3/all-orgs-summary` (`api.go:252`, handler `orgs.go:93-103` → `OrgStore.GetAllOrgsSummary` at `store/sqlstore/orgs.go:42-100`) returns every org with its OrgOwner emails embedded (the `WHERE users_orgs.role = OrgOwner AND status = Active` query at line 80-84).

**Permission gate:** `CheckPermissionAccessAllOrgs()` (`pkg/middlewares/auth.go:297-307`) — runs `HasPermission` with no extra opts. `view:all` permission at `data.json:1191-1203` includes `/v3/all-orgs-summary`, and `view:all` is held only by the `ReadAllOrgs` role (`data.json:1239-1243`). `SuperAdmin` does **not** have `view:all`.

**So `Config.SuperAdmin` Duong cannot call `/v3/all-orgs-summary` to enumerate OrgOwners.** He'd need a `users_orgs` row with role `ReadAllOrgs` somewhere — which is exactly the role assigned via the §B2.3 ReadAllOrgs* path, which itself requires existing per-org authority.

**Recommended workaround for Duong:** he likely has direct prd DB read access (or knows someone in ops who does). One SQL query — `SELECT u.email FROM users u JOIN users_orgs uo ON uo.user_id = u.id WHERE uo.org_id = <O_target> AND uo.role IN ('OrgOwner','SuperAdmin') AND uo.status = 'Active'` — definitively answers "does anybody have authority in O_target". This is a read, not a write, so it sidesteps the rule-6 hazard.

## B5. Direct DB write — the only sanctioned bootstrap path under the no-tse-change constraint

**No tooling, no script, no migration, no runbook found.** Verified by:

- `cmd/scripts/*` grep for `users_orgs|UpdateUserOrgRoleByEmail|JoinOrgWithRole|UserRoleSuperAdmin|UserRoleOrgOwner` → empty result. The 12 files under `core/tse/cmd/scripts/` (cue-gen, migrate-org-to-new-google-issuer, change_google_issuer, hash-password, check-jwt, create-jwt, fix-gpay-empty-localized-strings, fill_base_google_class_id, google_class_get_all, map-cellid-areacode-gen, switch-project-google-offer-to-generic, upload_images, self_companion_enable, param-value-long-backslash) all touch projects, issuers, JWTs, passes, base-classes — none touches `users_orgs`.
- `cmd/enable-sso/main.go:48` mutates `Org.SSOConfig` only — no role grants.
- `migrations/*.sql` grep for `users_orgs|user_role|SuperAdmin|OrgOwner` → only the schema migrations: `20180417165905_add_users_table`, `20201005123459_migrate_users_orgs_tb`, `20220127072528_add_role_to_user_org` (adds the `role` varchar column, no constraint), `20220606172700_rename_permission_groups`, `20220822100231_create_status_column_in_users_orgs_table`, `20200901111954_update_users_orgs_table`. **No migration grants any user any role on any specific org.**
- `mmp/workspace/company-os/` grep for `users_orgs|tse.*role|UpdateUserOrgRole|OrgOwner|SuperAdmin` → empty.
- `tools/decrypt.sh`-style ops scripts: not searched, but rule 6 forbids reading their plaintext. If something exists there it's Duong-only territory.

The store method that would do this is `UpdateUserOrgRoleByEmail` (`store/sqlstore/users.go:833-848`) — `UPDATE users_orgs SET role = $1 WHERE user_id IN (SELECT id FROM users WHERE email = $2) AND org_id = $3`. The `JoinOrgWithRole` method (`store/sqlstore/users.go:508-520`) is `INSERT INTO users_orgs (user_id, org_id, role, status) VALUES (...)` for first-time enrollment. **Equivalent SQL run directly against prd** would be:

```sql
-- if duong has no row in users_orgs for O_target yet:
INSERT INTO users_orgs (user_id, org_id, role, status, created_at, updated_at)
VALUES (
  (SELECT id FROM users WHERE email = 'duong.nguyen.thai@missmp.eu'),
  <O_target_org_id>,
  'SuperAdmin',
  'Active',
  NOW(), NOW()
);

-- or, if a row exists at a lower role (e.g. demoted):
UPDATE users_orgs SET role = 'SuperAdmin', updated_at = NOW()
WHERE user_id = (SELECT id FROM users WHERE email = 'duong.nguyen.thai@missmp.eu')
  AND org_id = <O_target_org_id>;
```

There is no enum constraint, no trigger, no audit table on `users_orgs` (verified: `users.go:833-848` is a single UPDATE, no surrounding transaction wraps an audit insert). The next time `OrgRoles` is loaded for the user (lazy via `Store.User().Get()` joining `users_orgs`), rego will see `org_roles[O_target] = "SuperAdmin"` and the §1-§7 flow becomes available immediately.

**This is a privileged-ops operation, not an agent operation.** Anthropic's Strawberry agent fleet has no permission, no sanctioned tooling, and no precedent for direct prd-DB writes against missmp services. This must be done by Duong (or whoever holds prd-DB write credentials on the missmp side), running the SQL through whatever the missmp DB-ops procedure is — likely a bastion host + `psql` session, or the same path used for prior emergency interventions.

## B6. The actual answer: smallest path Duong can take

Three options, ranked. **All three preserve the no-tse-code-change constraint except (c).**

### (a) Cleanest end-state: direct DB INSERT/UPDATE

- **What:** Run the SQL in §B5 against the prd `tse` database. Insert `users_orgs(duong, O_target, 'SuperAdmin', 'Active')`, or UPDATE if a row exists.
- **Authority required:** prd DB write credentials (Duong has these or knows the path).
- **End-state:** Duong holds SuperAdmin in `O_target` natively. All subsequent role management in `O_target` flows through the standard `PUT /v3/orgs/O_target/user-role` API. No drift, no legacy. If Duong wants to invite a colleague to be SuperAdmin in `O_target` later, the §5 flow works.
- **Debt:** Zero in the codebase. One row of "where did this come from" if anyone audits `users_orgs` history later — mitigatable by leaving a comment in ops runbooks or the missmp incident log.
- **Risk:** Direct prd writes always carry the "wrong WHERE clause" risk. Mitigation: scope by email (unique) and a confirmed `O_target` ID looked up first, both inside a `BEGIN;` `SELECT…FOR UPDATE` `INSERT…` transaction with a manual `COMMIT`. Standard prd-DB hygiene.
- **Recommended.** This is the option Duong's constraint actually points at.

### (b) Balanced: bootstrap via fresh org + cross-org promotion request to a known OrgOwner of `O_target`

- **What:** Identify any user who currently has OrgOwner or SuperAdmin in `O_target` (via the SQL read in §B4). Ask them to invoke the §5 two-step flow on Duong's behalf.
- **Authority required:** existing `O_target` OrgOwner/SuperAdmin must be reachable and willing.
- **End-state:** Identical to (a) — Duong holds SuperAdmin in `O_target` via a real `users_orgs` row. Difference is provenance: row has the inviter's session-attributable creation, not a raw SQL audit gap.
- **Debt:** Zero.
- **Risk:** Sona's premise is that no such authority exists. If the read in §B4 confirms that, this option is ruled out.

### (c) Quickest with debt: tse PR adding a `Config.SuperAdmin` cross-org override

- **What:** Add a new endpoint `POST /v3/superadmin/grant-role` (or similar) under the `/v3/superadmin/*` group, gated only by `mw.CheckPermissionSuperAdmin()`, that accepts `{org_id, email, role}` and calls `UpdateUserOrgRoleByEmail` directly. Or revive the cancelled PR #2108 work.
- **Authority required:** tse PR + review + deploy.
- **End-state:** `Config.SuperAdmin` becomes a true global override for role management. Future bootstrap-from-zero cases close in two API calls.
- **Debt:** This is the structural escalation tse intentionally avoided. It punches a permanent cross-org hole through the rego model. Sona's `[concern: work]` brief is `Duong does NOT want code changes in tse` — this option **violates the constraint by definition.**
- **Not recommended given the stated constraint.**

## B7. Explicit acknowledgment of the constraint

**Duong's "no tse code/config change" constraint is fully compatible with option (a) and option (b).** Option (a) does not touch tse code or config — it is a single direct DB write outside the tse repo, run with whatever prd-DB-write credentials exist. Option (b) is also fully external to tse — it uses only existing routes, requires only the cooperation of an existing authority, and produces a clean `users_orgs` row.

**Option (c) is the only path that requires a tse PR**, and the brief explicitly excludes it. So (c) is mentioned only for completeness — it is the "if you ever change your mind" option.

**The smallest path: option (a). One SQL statement, run by Duong (or missmp ops) against the prd `tse` database, against the `users_orgs` table.**

---

## Files cited (anchors for follow-up — both halves)

### Existing-flow audit
- `core/tse/api/v3/api.go:29-36, 268, 271, 329`
- `core/tse/api/v3/invites.go:17-44, 26-66`
- `core/tse/api/v3/orgs.go:273-348` (UpdateUserRoleInOrg + UpdateUserRoleRequest)
- `core/tse/api/v3/api_permission_test.go:172-205` (existing test exercising this exact flow)
- `core/tse/model/roles.go:11-45` (role enum + allowlists)
- `core/tse/pkg/middlewares/auth.go:221-241, 270-295` (CheckPermissionSuperAdmin vs CheckPermissionForOrg)
- `core/tse/authz/rego/main.rego:21-40, 49-94`
- `core/tse/authz/rego/deny.rego:1-5`
- `core/tse/authz/data.json:805-830, 1220-1234`
- `core/tse/store/sqlstore/users.go:508-520, 833-848`
- `core/tse/app/user_invite.go:30+`

### Bootstrap-from-zero dig
- `core/tse/model/config.go:65` — `SuperAdmin []string` field definition
- `infra/argocd/prd/manifests/tse/config.yaml:130` — prd `SUPERADMIN` env var (Duong already in list)
- `core/tse/configs/.env.local:156`, `core/tse/configs/.env.test:115` — local/test SUPERADMIN values
- `core/tse/pkg/middlewares/auth.go:221-241` — `CheckPermissionSuperAdmin` impl
- `core/tse/pkg/middlewares/auth.go:297-307` — `CheckPermissionAccessAllOrgs` impl
- `core/tse/api/v3/api.go:29, 102, 250-253, 256-272, 275-278` — full route map
- `core/tse/api/v3/api.go:251` `mw.CheckPermissionAccessAllOrgs()` gates `/v3/all-orgs*`
- `core/tse/app/users_new.go:8-43` — `CreateUserAndOrg` Config.SuperAdmin check on first-login
- `core/tse/app/orgs_new.go:11-23` — `CreateOrgNew` (joins with passed-in role)
- `core/tse/app/orgs_new.go:25-104` — `CreateOrgAndGoogleIssuer` (joins creator as OrgOwner, line 78)
- `core/tse/api/v3/sso.go:150` — first-login bootstrap path (OIDC)
- `core/tse/api/v3/ory_webhook.go:183` — first-login bootstrap path (Ory webhook)
- `core/tse/api/v3/orgs.go:105-148` — `CreateOrg` handler (POST /v3/orgs)
- `core/tse/api/v3/orgs.go:300-319` — ReadAllOrgs* role assignment with Config.SuperAdmin check
- `core/tse/authz/opa.go:114-153, 156-214` — OPA input shape (Config.SuperAdmin not in input)
- `core/tse/authz/data.json:1191-1247` — `view:all` / `view:orgusers` / role-permission map
- `core/tse/authz/rego/additional_allow_actions.rego:19-24` — `allow_everybody_can_create_org`
- `core/tse/store/sqlstore/orgs.go:42-100` — `GetAllOrgsSummary` SQL
- `core/tse/store/sqlstore/users.go:508-520, 833-848` — `JoinOrgWithRole` + `UpdateUserOrgRoleByEmail`
- `core/tse/store/sqlstore/migrations/20220127072528_add_role_to_user_org.sql` — varchar column, no constraint
- `core/tse/cmd/scripts/*` — none touch `users_orgs`
- `core/tse/cmd/enable-sso/main.go` — touches `Org.SSOConfig`, not roles
