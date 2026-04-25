# SuperAdmin config list is not a rego override — bootstrap-from-zero requires direct DB write

**Session:** c1463e58 (2026-04-25, second post-compact leg)
**Source:** Swain investigation prompted by prior shard's incorrect framing

## What I had wrong

I briefed Duong and the team that `Config.SuperAdmin` (the argocd email list) functioned as a global rego override granting SuperAdmin privileges to listed users. This was wrong.

## Correct understanding

`Config.SuperAdmin` is never injected into OPA's input. The input builder at `core/tse/authz/opa.go:159-177` does not include it. The rego policy at `authz/rego/main.rego:21-23` consults only `input.user.org_roles[org_id]`. The SuperAdmin two-call API flow (`POST /v3/superadmin/...`) requires the caller to already hold SuperAdmin or OrgOwner role in the target org via `mw.CheckPermissionForOrg` — it does not bootstrap the first grant.

## Generalizable lesson

When Duong describes a capability like "an account that can invite users regardless of org membership," verify the mechanism in both the auth middleware AND the rego policy before briefing. The argocd email list may govern deployment access or internal tooling but should not be assumed to propagate into runtime API authorization.

## What this means for Duong's case

Duong's case is bootstrap-from-zero: target org has no existing SuperAdmin or OrgOwner. Under "no tse change" constraint, the only path is a direct write to `users_orgs` in the database, bypassing the API entirely. The self-invite ADR is archived. The runbook at `assessments/work/2026-04-25-superadmin-self-invite-runbook.md` needs a "Bootstrap-from-zero" section gated on Duong confirming prd DB access.

## Tags

auth, opa, superadmin, bootstrap, rego, tse
