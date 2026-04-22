# 2026-04-22 — Firebase Auth Infra Setup for demo-studio

## Context

Ran GCP infra for `2026-04-22-firebase-auth-for-demo-studio.md` plan promotion.

## Findings

### demo-studio SA is NOT demo-runner-sa

`demo-studio` Cloud Run service runs as:
`266692422014-compute@developer.gserviceaccount.com` (default compute SA)

Only `demo-runner` service uses `demo-runner-sa@mmpt-233505.iam.gserviceaccount.com`.
The ADR references `demo-runner-sa` but the actual service needs the role on the compute SA.

### IAM binding blocked

`duong.nguyen.thai@missmp.eu` does not have `setIamPolicy` on `mmpt-233505`.
`harukainguyen1411@gmail.com` also blocked (not a member of the project).
This is a manual Duong step — needs a project Owner or Security Admin identity.

### Identity Toolkit REST API requires quota project header

`gcloud auth print-access-token` returns user credentials that need
`-H "x-goog-user-project: mmpt-233505"` for identitytoolkit.googleapis.com calls.
Without it, the request routes to the ADC default project and gets 403.

### Authorized domains call

The actual Cloud Run URL is `demo-studio-4nvufhmjiq-ew.a.run.app`
(not the `266692422014.europe-west1.run.app` format from the task prompt).
Set via PATCH 200 OK. Domains written: `["demo-studio-4nvufhmjiq-ew.a.run.app", "localhost"]`.

### Google sign-in provider

Already existed (`clientId` present). PATCH `enabled: true` returned 200.
`clientId: 266692422014-qlkuss4tmc10r7no9mtjitt7ni16t8sm.apps.googleusercontent.com`
`clientSecret` returned in plaintext in response — do NOT log/store.
