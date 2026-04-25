---
date: 2026-04-25
author: Sona
concern: work
---

# Runbook: SuperAdmin → SuperAdmin promotion via existing two-call flow

**Use case:** Duong (or any SuperAdmin/OrgOwner) needs to give themselves or another user
a SuperAdmin account in any org. No tse code changes required — the flow is fully live today.

---

## Prerequisites

- Caller holds `role = "SuperAdmin"` or `"OrgOwner"` in the target org.
- Target email must differ from the caller's email (self-update is blocked at `orgs.go:296-298`).
- If the target user is already an org member, skip Step 1.

---

## Step 1 — Invite target into the org (skip if already a member)

```
POST /v3/orgs/:orgId/invites
Auth: caller's OIDC session or X-API-Key
Body: {"invites":[{"email":"<target>","role":"Editor"}]}
```

Any of the four `InviteRoles` (`ProjectAdmin`, `Editor`, `Viewer`, `Overview`) works as a
placeholder. `SuperAdmin` and `OrgOwner` are excluded from this allowlist by design
(`model/roles.go:39-44`). Target receives a JWT-signed accept-invite email and clicks through
`GET /v3/resources/users/accept-invite` to join the org.

Reference: handler `core/tse/api/v3/invites.go:26-66`.

---

## Step 2 — Promote target to SuperAdmin

```
POST /v3/orgs/:orgId/user-role   (note: PUT method)
PUT  /v3/orgs/:orgId/user-role
Auth: caller's OIDC session or X-API-Key
Body: {"email":"<target>","role":"SuperAdmin"}
```

`AvailableRoles` includes `SuperAdmin` (`model/roles.go:31-38`), so the role is accepted.
Returns 200. DB effect: `UPDATE users_orgs SET role='SuperAdmin' WHERE user_id=<target> AND org_id=<org>`.

Reference: handler `core/tse/api/v3/orgs.go:278-348`.

---

## Why this works — the allowlist asymmetry

| Allowlist | Contents |
|-----------|----------|
| `InviteRoles` (invite endpoint) | ProjectAdmin, Editor, Viewer, Overview — **excludes SuperAdmin** |
| `AvailableRoles` (role-update endpoint) | OrgOwner, SuperAdmin, ProjectAdmin, Editor, Viewer, Overview — **includes SuperAdmin** |

Invite cannot directly set SuperAdmin; role-update can. Two calls, not one.

---

## Permission gate cascade

`mw.CheckPermissionForOrg` → OPA evaluation at `authz/rego/main.rego:21-40` → requires
`manage:org` permission → held by `SuperAdmin` and `OrgOwner` per `authz/data.json:1221-1234`.

---

## Caveats

- Promotion is scoped per (user, org). To make the target SuperAdmin in a second org,
  repeat both steps against that org (caller must be SuperAdmin/OrgOwner there too).
- `Config.SuperAdmin` (the argocd-managed email list at
  `infra/argocd/{stg,prd}/manifests/tse/`) is **not touched** by this flow.
  That list gates the separate `/v3/superadmin/*` route group (gpay-class, project-transfer,
  etc.). If access to those routes is also needed, it requires a manifest edit — not an API call.
- `SuperAdmin` is a per-(user, org) row only; there is no global `is_superadmin` flag on the
  user table.

---

## Background

Investigation by Swain (2026-04-25, commit a39691bb) confirmed this flow was already live
and complete. PRs #2108 + #2109 in `missmp/tse` (which would have added a
`/v3/superadmin/invite-user-to-org` shortcut) were closed as unnecessary.

Full investigation: `agents/swain/memory/last-sessions/2026-04-25-superadmin-promotion-investigation.md`
Superseded ADR (archived): `plans/archived/work/2026-04-24-self-invite-to-walletstudio-org.md`
