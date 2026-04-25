# SuperAdmin → SuperAdmin promotion: existing-flow investigation

**Date:** 2026-04-25
**Author:** Swain (subagent invoked by Sona, work concern)
**Brief:** Read-only audit of `wallet-studio/core/tse` + `mmp/workspace/company-os` to determine whether an authenticated SuperAdmin can promote another user to the SuperAdmin role *today*, with no new tse code.

---

## Bottom line

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

## Files cited (anchors for follow-up)

- `core/tse/api/v3/api.go:29-36, 268, 271, 329`
- `core/tse/api/v3/invites.go:17-44, 26-66`
- `core/tse/api/v3/orgs.go:273-348` (UpdateUserRoleInOrg + UpdateUserRoleRequest)
- `core/tse/api/v3/api_permission_test.go:172-205` (existing test that exercises this exact flow with SuperAdmin role caller — for ReadAllOrgs*, but proves the mechanism)
- `core/tse/model/roles.go:11-45` (role enum + allowlists)
- `core/tse/pkg/middlewares/auth.go:221-241, 270-295` (CheckPermissionSuperAdmin vs CheckPermissionForOrg)
- `core/tse/authz/rego/main.rego:21-40, 49-94` (allow path)
- `core/tse/authz/rego/deny.rego:1-5` (only project deny modules)
- `core/tse/authz/data.json:805-830, 1220-1234` (manage:org route list + SuperAdmin/OrgOwner role-permission map)
- `core/tse/store/sqlstore/users.go:508-520, 833-848` (JoinOrgWithRole + UpdateUserOrgRoleByEmail SQL)
- `core/tse/app/user_invite.go:30+` (InviteUsers email-token plumbing)
