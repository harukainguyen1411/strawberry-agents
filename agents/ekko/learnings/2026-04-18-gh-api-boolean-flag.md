# gh api: Use -F (not -f) for Boolean Fields

**Date:** 2026-04-18
**Task:** P0.0 preflight repo creation

## Learning

`gh api` has two field flags:
- `-f key=value` — sends as string
- `-F key=value` — sends as typed (boolean, integer, etc.)

GitHub API endpoints that expect a boolean (e.g. `enabled` in Actions permissions) will return HTTP 422 "not a boolean" if you use `-f`. Always use `-F` for boolean fields.

## Example

```bash
# Wrong — sends "true" as string:
gh api -X PUT repos/owner/repo/actions/permissions -f enabled=true

# Correct:
gh api -X PUT repos/owner/repo/actions/permissions -F enabled=true -f allowed_actions=all
```

The failed call is safely idempotent (rejected before applying) so a retry with `-F` is safe.
