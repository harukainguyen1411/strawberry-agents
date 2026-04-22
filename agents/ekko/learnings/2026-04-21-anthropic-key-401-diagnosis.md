# 2026-04-21 — Anthropic API Key 401 Diagnosis (demo-studio-00016-5rw)

## Finding

Secret: `DS_SHARED_ANTHROPIC_API_KEY` (project mmpt-233505)  
Revision binding: `key: latest` (not a pinned version)  
Secret versions: 2 (enabled, 2026-04-17), 1 (enabled, 2026-04-17)

Both versions are ENABLED. "latest" resolves to version 2 at deploy time — but Cloud Run
pins the resolved version at revision creation, so the revision holds whatever version
"latest" pointed to when it was deployed.

Root cause: the Anthropic API key value inside version 2 is itself invalid/revoked upstream
(Anthropic side), not a Secret Manager state problem. Secret Manager is healthy; the key
material is bad.

## Resolution

Duong must:
1. Mint a new Anthropic API key at console.anthropic.com.
2. Add it as a new secret version:
   ```
   echo -n "sk-ant-NEWKEY" | gcloud secrets versions add DS_SHARED_ANTHROPIC_API_KEY \
     --project=mmpt-233505 --data-file=-
   ```
3. Redeploy S1 (new revision picks up the new "latest"):
   ```
   gcloud run services update demo-studio --project=mmpt-233505 --region=europe-west1 \
     --update-secrets=ANTHROPIC_API_KEY=DS_SHARED_ANTHROPIC_API_KEY:latest
   ```
   Or simply re-run the deploy script — the new revision will resolve "latest" to the new version.

## Self-fix status

Cannot self-fix — key material must come from Duong (Anthropic console access).
Secret Manager write requires the new key value, which Rule 6 prohibits reading into context.
