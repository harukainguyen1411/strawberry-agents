---
decision_id: 2026-04-27-prod-auth-env-fix
date: 2026-04-27
coordinator: sona
concern: work
axes: [scope-vs-debt]
question: Prod demo-studio-v3 returns "Auth not configured" because /auth/config returns empty Firebase env values — how do we fix it?
options:
  a: Find auth env source (deploy.sh / Secret Manager / .env.example), populate prod Cloud Run via gcloud run services update, redeploy, verify /auth/config returns populated values
  b: Pull values from a known-good secret blob if one exists, skip re-derivation
  c: Hand Duong a pre-auth nonce URL and skip sign-in for his manual test (route around the gap)
coordinator_pick: a
coordinator_confidence: medium
duong_pick: a
predict: a
match: true
concurred: false
---

## Context

Post-/compact resume on the RUNWAY ship thread. Duong opened the prod studio URL and hit "Auth not configured" on the Sign-in-with-Google button. I probed `/auth/config` directly: HTTP 200, but `{"projectId":"","apiKey":"","authDomain":"","allowedEmailDomain":""}`. The Cloud Run prod revision `demo-studio-00030-2zg` was deployed without the Firebase auth env vars wired into the container.

Akali's prior RUNWAY GREEN report (CP1–CP6 PASS) entered via the dashboard's nonce-URL session path and never exercised Sign-in-with-Google, so the auth gap was not surfaced in QA. Q2 in the same exchange (re-task Akali to add an auth-flow CP) was rejected by Duong with explicit trust signal: "I'll test it myself. I can't trust any of you" — captured in a separate decision log entry on QA trust.

## Why this matters

Picking (c) leaves the substrate broken before god-merge — the prod demo-studio-v3 surface is unusable for any user entering through Sign-in-with-Google, which is the canonical entry. The F1+F2 fixes are real but the surface around them is broken. (a) fixes the gate at the substrate level: find canonical env source, populate, verify. (b) is a shortcut variant of (a) that depends on a known-good blob existing — Ekko's investigation will collapse to (a) or (b) depending on what he finds.

Followup: I am about to dispatch Ekko (foreground, ad-hoc ops) to investigate deploy.sh and Secret Manager for the auth env source, then update the prod Cloud Run service and verify the endpoint. No QA agent to be re-tasked on this surface — Duong validates manually post-fix.
