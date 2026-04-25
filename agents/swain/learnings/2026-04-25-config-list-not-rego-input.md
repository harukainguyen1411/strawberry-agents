# Email-allowlist not in OPA input ⇒ not a global authority

**Date:** 2026-04-25
**Triggered by:** tse SuperAdmin bootstrap-from-zero investigation. Sona asked whether `Config.SuperAdmin` argocd email list could let Duong promote himself in an org where he has no existing role row.

## Lesson

When auditing whether an email-allowlist is a global authority across a rego-gated system, the **first** question is not "what does the Go code do with this list?" but "is this list visible to OPA?" If the list is not in `rego.EvalInput(...)`, it cannot inform allow/deny decisions made at the middleware layer — by definition. Any handler-side check that consults the list runs **after** the middleware has already decided, which means handler-side use can only further restrict, never expand.

In the tse case: `core/tse/authz/opa.go:159-177` builds the OPA input as `{user, method, endpoint, project, extra-data}`. `Config.SuperAdmin` is absent. So the three Go uses of the list (CheckPermissionSuperAdmin middleware on a fixed route group; CreateUserAndOrg first-login auto-org; ReadAllOrgs* handler exception) collectively grant zero cross-org `manage:org` authority. A "SuperAdmin" config-listed user with no `users_orgs` row in `O_target` gets a 403 from `CheckPermissionForOrg` rego eval before any handler runs.

## Pattern (reusable)

When investigating "can config-list X bypass per-resource permission Y?":

1. Find the OPA/rego input builder. Grep for the list name in the input map. If absent → the list cannot bypass rego, full stop.
2. Find every Go consumer of the list. For each, identify the route + middleware chain it lives behind. Anything gated by the per-resource permission middleware first is a no-op for cross-resource bootstrap.
3. The valid uses of such a list are: (a) gating its own dedicated route group with its own middleware, (b) bootstrap on resource creation (where there is no pre-existing per-resource permission to check against), (c) further restriction inside an already-permitted handler. **Never** a global override.

## Anti-pattern to avoid

Reading the route table top-to-bottom and assuming a `/v3/superadmin/*` group means the email list is "the admin authority." In tse it is one of three very narrow uses, none of which expands cross-org reach. The correct mental model: "email-list ≠ rego role; email-list bypasses only its own narrow gate, never another middleware's gate."

## Implication for ADRs

If a future ADR proposes a new `/v3/superadmin/*` route to "give SuperAdmins X capability," the question to ask is: "does this route bypass `CheckPermissionForOrg`, and if so, is the bypass justified by an invariant we cannot enforce per-org?" The cancelled tse PRs #2108/#2109 (`/v3/superadmin/invite-user-to-org`) were exactly this shape — they wanted to widen the allowlist to a true global override. That is a structural escalation, not a UX fix, and the constraint "no tse code change" means it stays cancelled.

## Sibling learning

`2026-04-25-allowlist-asymmetry-as-existing-flow-signal.md` (earlier today) was about the InviteRoles vs AvailableRoles asymmetry — a within-rego-gated handler distinction. This learning is about the rego-input-vs-handler-scope distinction. They compose: when both apply to the same system, the existing two-step flow §1-§7 covers the in-org case, and the bootstrap-from-zero case has no API path at all. Direct DB write is the only smallest-path solution.
