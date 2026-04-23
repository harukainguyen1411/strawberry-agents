# Firebase Auth for demo-studio-v3 — Duong-Only IAM Punch List

**Date:** 2026-04-22
**Plan:** `plans/approved/work/2026-04-22-firebase-auth-for-demo-studio.md` (still in `approved/`; Ekko's bad demotion `af0c773c` reportedly invalidated the Orianna signature — NOT fixed here; Evelynn / Orianna handle separately)
**GCP project:** `mmpt-233505`
**Read-only mode:** no writes performed

## Current state (verified via gcloud)

| Item | Status |
|---|---|
| `identitytoolkit.googleapis.com` (Identity Platform) | ENABLED |
| `firebase.googleapis.com` | ENABLED |
| `iamcredentials.googleapis.com` (required for token creation) | ENABLED |
| SA `firebase-adminsdk-sh9pe@mmpt-233505.iam.gserviceaccount.com` | EXISTS |
| SA `demo-runner-sa@mmpt-233505.iam.gserviceaccount.com` | EXISTS |
| SA `266692422014-compute@developer.gserviceaccount.com` (Cloud Run ADC) | EXISTS |
| `firebase-adminsdk` has `roles/firebase.sdkAdminServiceAgent` at **project** level | YES |
| `firebase-adminsdk` has `roles/iam.serviceAccountTokenCreator` **on itself** | **NO** (self-binding empty, etag `ACAB`) |
| Compute default SA has `roles/firebase.sdkAdminServiceAgent` | **NO** (only `roles/editor`, `eventarc.eventReceiver`, `secretmanager.secretAccessor`) |

## Plan-vs-reality divergence (flag for Aphelios / Swain)

The plan W0 block (lines 176–180) binds `roles/firebase.sdkAdminServiceAgent` to the **compute default SA** (`266692422014-compute@developer.gserviceaccount.com`). Your task brief names a different grant: `roles/iam.serviceAccountTokenCreator` on `firebase-adminsdk` self. Both gaps are real; they serve different flows (ADC on Cloud Run vs. the admin SDK minting custom tokens via `signBlob`/`generateIdToken`). Confirm intent before pasting — do not run both blindly.

## Human-only punch list (paste when awake)

All require org-admin / project-owner privileges an agent does not hold.

### 1. (Per your brief) firebase-adminsdk self-binding for token creation

    gcloud iam service-accounts add-iam-policy-binding \
      firebase-adminsdk-sh9pe@mmpt-233505.iam.gserviceaccount.com \
      --member="serviceAccount:firebase-adminsdk-sh9pe@mmpt-233505.iam.gserviceaccount.com" \
      --role="roles/iam.serviceAccountTokenCreator" \
      --project=mmpt-233505

Expected: `Updated IAM policy for serviceAccount [firebase-adminsdk-sh9pe...]`. Verify:

    gcloud iam service-accounts get-iam-policy \
      firebase-adminsdk-sh9pe@mmpt-233505.iam.gserviceaccount.com \
      --project=mmpt-233505

should list `roles/iam.serviceAccountTokenCreator` with the same SA as member.

### 2. (Per plan W0) ADC identity Firebase admin role

The plan's W0 grant is to the compute default SA. Confirm the ADC identity Cloud Run actually runs as (`gcloud run services describe demo-studio-v3 --region=... --format='value(spec.template.spec.serviceAccountName)'`) — if it is `demo-runner-sa` instead of the compute default, swap the member below:

    gcloud projects add-iam-policy-binding mmpt-233505 \
      --member="serviceAccount:266692422014-compute@developer.gserviceaccount.com" \
      --role="roles/firebase.sdkAdminServiceAgent"

Expected: updated policy output containing the binding.

### 3. Firebase Console (browser, no gcloud equivalent) — T.W6.4

- Authentication → Sign-in method → enable **Google**.
- Authentication → Settings → Authorized domains: add Cloud Run service URL + any custom domain.
- OAuth consent screen → restrict to `missmp.tech` Workspace org (Internal).

## Items an agent CAN run with existing creds (leave for Ekko)

- `firebase-admin` requirements pin, spike branch, Cloud Run deploy, secret binding (`secrets-mapping.txt`), smoke tests. All non-IAM W0–W6 work.

## Orianna signature note

Plan currently at `plans/approved/work/2026-04-22-firebase-auth-for-demo-studio.md` with `orianna_signature_approved: sha256:91a431b7...` in frontmatter. Ekko's `af0c773c` bad-demotion history reportedly left the signature stale vs. current file hash. Do not regenerate here — escalate to Orianna via Evelynn before any further lifecycle transition.
