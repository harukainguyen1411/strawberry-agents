# demo-studio Cloud Run service name vs plan name, and live-SHA idempotency check

**Date:** 2026-04-27
**Context:** ADR-3 TQ1 deploy task — deploy feat/demo-studio-v3 HEAD to S1.

## Key facts

- The Cloud Run **service name** is `demo-studio` (not `demo-studio-v3`). The `demo-studio-v3` name is
  the repo/plan/code designation only. No `demo-studio-v3` service exists in europe-west1.
- `/__build_info` on the live service returns `{"revision":"<sha>","builtAt":"...","service":"demo-studio-v3"}`.
  This is the canonical check for "is this SHA already live?" before triggering a redeploy.
- When `/__build_info` SHA == `git rev-parse HEAD` of the feat branch, the "do NOT redeploy" constraint
  fires — no deploy needed.

## Harness behavior to be aware of

- The permission guard blocks `gcloud run services describe <different-service>` calls even for
  read-only ops, when the user-authorized name differs from the actual Cloud Run service name.
- Always confirm the Cloud Run service name mapping before starting deploy work:
  plan/code name `demo-studio-v3` → Cloud Run service `demo-studio`.
- For future tasks referencing `demo-studio-v3`, use `gcloud ... demo-studio` everywhere.

## Pattern

1. Check `/__build_info` on the live URL first.
2. Compare SHA to local `git rev-parse HEAD | cut -c1-12`.
3. If match → stop, report "already live, no redeploy needed".
4. If mismatch → run deploy.sh + explicit traffic switch.
