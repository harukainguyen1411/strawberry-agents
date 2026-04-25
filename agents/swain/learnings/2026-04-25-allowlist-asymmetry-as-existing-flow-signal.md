# Allowlist asymmetry is often the existing-flow signal

**Date:** 2026-04-25
**Context:** tse SuperAdmin → SuperAdmin promotion investigation (work concern, invoked by Sona)

## The pattern

When a system has *two* allowlists for the "same" capability, asymmetry between them frequently encodes the multi-step path that already accomplishes the apparent gap.

In `core/tse/model/roles.go`:

```
AvailableRoles = [OrgOwner, SuperAdmin, ProjectAdmin, Editor, Viewer, Overview]
InviteRoles    = [ProjectAdmin, Editor, Viewer, Overview]
                 // smaller set — excludes SuperAdmin and OrgOwner
```

`InviteRoles` gates the *direct invite* payload; `AvailableRoles` gates the *role-update* payload. Reading them in isolation, you would conclude "SuperAdmin cannot be granted via the API." Reading them together: SuperAdmin cannot be granted in *one step* — but a two-step path (invite as Editor → update to SuperAdmin) is fully callable today and was never closed.

## Why this kept happening here

Three teams and two cancelled PRs (#2108, #2109) treated the gap as a missing endpoint to add. The asymmetry was the documentation: it said "we deliberately route SuperAdmin grants through the role-update path, not the invite path, because role-update has a stricter handler check (caller must be OrgOwner or SuperAdmin in the org, target must be a member, no self-update)." The invite-then-promote workflow is the *intended* path; it just isn't named anywhere.

## Heuristic

When a brief asks "is there an existing flow that does X?" and the obvious one-step endpoint rejects X:

1. Find the *next* step beyond the rejection — is the rejected role/permission accepted in a downstream mutation handler?
2. Compare the two validators: a smaller allowlist on the entry path + a larger allowlist on the mutation path = intentional two-step gating, not a gap.
3. The mutation handler is where the real gate lives (caller-role check, membership check, self-action check). Rego is usually only doing route-level role-permission mapping; it does not gate role *values*.

## Generalizes to

- Org-creation rejecting a role that user-update later accepts.
- Workflow-definition limits vs. workflow-instance overrides.
- Resource-create payload schemas vs. resource-update PATCH schemas.

The phrase "look for the *second* validator" works as a reflex for any "we need a new endpoint" claim before writing an ADR.

## Anti-pattern this avoids

Adding a "convenience" endpoint that bypasses the smaller allowlist (what PR #2108/#2109 was) collapses the two-step into one and quietly removes the membership-precondition check (handler line 337-339). That is a *capability widening*, not a UX improvement, and reviewers should treat it as a security-surface change. If smoothing is genuinely needed, do it in the client (UI) or in a missmp/company-os helper script — not by replicating the role-update handler with weaker gates.
