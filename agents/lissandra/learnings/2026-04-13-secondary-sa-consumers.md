# Learning: Secondary SA Consumers Are Not Covered by "Delete Local Copy" PRs

## Date
2026-04-13

## Context
PR #102 deleted local laptop copies of the Firebase prod SA key and wrote a runbook claiming
"no local copy exists." However, the GCE bee-worker at `/opt/bee-worker/secrets/firebase-sa.json`
held the same key — copied there during bee-worker provisioning. The runbook's rotation procedure
would revoke the key in GCP, then upload a new one to GitHub Actions, leaving the bee-worker with
a dead credential.

## Pattern
When reviewing a "delete credentials from laptop" PR:
1. Grep the entire repo for the SA filename and `GOOGLE_APPLICATION_CREDENTIALS` references.
2. Check `scripts/gce/.env.example`, `scripts/windows/`, and any worker provisioning docs — these
   often reveal secondary consumers (GCE VMs, Windows workers) that hold the same key.
3. Verify the runbook's rotation procedure accounts for every consumer, not just CI.

## Consequence of missing this
A SA rotation following an incomplete runbook breaks secondary services silently — no deploy
failure, no alert, just jobs that stop processing because Firebase Storage calls 401.
