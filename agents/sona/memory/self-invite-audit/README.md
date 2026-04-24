# Sona Self-Invite Audit Memory

This directory holds structured audit entries written by the
`walletstudio_superadmin_invite_user_to_org` MCP tool after every successful
upstream call. Each entry pairs with the corresponding `superadmin_invite` row
in WalletStudio's own audit log — two independent logs, same event, both
queryable.

## Entry filename convention

```
YYYY-MM-DD-HHMMSS-<orgId>.md
```

Example: `2026-04-24-143022-ORG-ABC.md`

## YAML frontmatter schema

Every entry MUST contain the following frontmatter block (from plan
`2026-04-24-self-invite-to-walletstudio-org.md §5.3`):

```yaml
---
timestamp:           <iso8601>
tool:                walletstudio_superadmin_invite_user_to_org
caller_agent:        sona
target_org_id:       <orgId>
target_email:        duongntd99@...
target_role:         <role>
# reason is free-text; suggested format: "<category>: <detail>"
# e.g. "customer-support: debug issuer X" or "demo: onboarding walkthrough"
reason:              <free text from call>
upstream_request_id: <uuid from endpoint response>
upstream_action:     created_user_and_invited | added_to_org | updated_role | already_member
---
```

The body below the frontmatter fence may contain free-form notes (optional).

## Upstream action values

| `upstream_action` | Meaning |
|---|---|
| `created_user_and_invited` | User did not exist in WalletStudio; row created and invite email sent |
| `added_to_org` | User existed but was not a member of the org; membership added |
| `updated_role` | User was already a member with a different role; role updated (`previousRole` in response) |
| `already_member` | User was already a member with the requested role; no-op |

## Grep patterns

Find all self-invites in the last week:

```sh
grep -r "target_org_id:" agents/sona/memory/self-invite-audit/ | sort
```

Find all invites to a specific org:

```sh
grep -l "target_org_id: ORG-ABC" agents/sona/memory/self-invite-audit/
```

## Related

- Plan: `plans/approved/work/2026-04-24-self-invite-to-walletstudio-org.md`
- Runbook (T14, pending): `architecture/runbooks/sona-self-invite.md`
- MCP tool source (T7–T10, pending): `mcps/wallet-studio/src/`
