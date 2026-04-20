# Demo Factory Cloud Run Deploy — Gotchas

## Dockerfile Context for demo-runner

The `demo-runner` Dockerfile imports from `demo-factory/` using relative paths, so the build context must be `tools/` (not `tools/demo-runner/`). The -f flag path is `tools/demo-runner/Dockerfile`.

In cloudbuild.yaml:
```
- -f
- tools/demo-runner/Dockerfile
- tools
```

## $COMMIT_SHA is empty on manual gcloud builds submit

When triggering Cloud Build manually (not via a repo trigger), `$COMMIT_SHA` is empty and causes invalid image tag errors (`image:` with no tag). Use `$BUILD_ID` instead for the commit-specific tag, and always add a `:latest` tag alongside it.

## Playwright base image already has chromium

`mcr.microsoft.com/playwright/python:v1.49.0-noble` already has chromium installed. The `playwright install chromium` line in the Dockerfile is redundant and will fail because:
- The base image's `playwright` CLI is not on PATH
- `python3` symlink points to system Python, not the one where pip installs
- Solution: remove the `playwright install chromium` step entirely

## Cloud Build SA needs run.admin for deployments

`266692422014@cloudbuild.gserviceaccount.com` only has `roles/cloudbuild.builds.builder` by default. It needs `roles/run.admin` and `roles/iam.serviceAccountUser` to deploy Cloud Run services. This requires project-level IAM binding (needs Owner/Security Admin to grant).

## New service accounts need Secret Manager access

New service accounts start with no secret access. Each SA needs `roles/secretmanager.secretAccessor` granted on each secret (or at project level). This also requires project-level IAM (needs Owner/Editor with secretmanager admin rights). In this project, `duong.nguyen.thai@missmp.eu` only has `roles/storage.objectAdmin` and cannot set secret IAM policies.

## Workaround: Deploy services manually as user, not via Cloud Build

If Cloud Build SA lacks run.admin, deploy with `gcloud run services replace` directly as the user. However, the SA still needs secret access for revisions to start.
