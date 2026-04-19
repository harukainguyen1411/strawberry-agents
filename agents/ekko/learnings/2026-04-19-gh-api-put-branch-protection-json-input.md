# gh api PUT branch protection — use --input not --field

## Context
Applying branch protection via `gh api --method PUT` with nested JSON objects (required_status_checks, required_pull_request_reviews).

## Problem
`gh api --field key='{"nested":"json"}'` passes the value as a string, not a parsed object. GitHub API returns 422 "is not an object" for nested fields passed this way.

## Solution
Pipe a JSON body via `--input -`:
```bash
echo '{"required_status_checks":{"strict":true,"contexts":[...]},...}' \
  | gh api repos/OWNER/REPO/branches/BRANCH/protection --method PUT --input -
```

## Applied
2026-04-19 s34 — successfully applied 2-approval gate to harukainguyen1411/strawberry-app.

## Note
Public repos on free plan support classic branch protection. Private repos on free plan get 403 (requires Pro).
