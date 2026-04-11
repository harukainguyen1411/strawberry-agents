# Handoff

## State
- MyApps CI fixed (7 VITE_FIREBASE_* secrets added to GitHub, deploy-release.yml patched, commit 050359d) — needs a push to apps/myapps/** to trigger and verify the blank page is resolved.
- apps.darkstrawberry.com CNAME live in Cloudflare (DNS-only), Firebase verification still pending — check console.firebase.google.com > myapps-b31ea > Hosting.
- darkstrawberry.com → apps.darkstrawberry.com redirect live via Cloudflare Page Rules.
- Cloudflare + GCP MCPs wired in .mcp.json (commit a811065) — needs session restart to load. Smoke test: list DNS zones (Cloudflare) and GCP projects (gcloud).
- Two plans in proposed awaiting approval: plans/proposed/2026-04-11-bee-github-issue-rearchitect.md, plans/proposed/2026-04-11-bee-worker-gce-deployment.md.

## Next
1. Approve the two Bee plans (rearchitect + GCE deployment).
2. Trigger a deploy to verify MyApps CI fix — push any change to apps/myapps/** or manually run the workflow.
3. Smoke-test Cloudflare + GCP MCPs after session restart.

## Context
- Firebase domain verification can take up to 24h — don't chase it, just check.
- Bee ToS: routing through GitHub issues (like coder-worker) makes it structurally Duong's own automation — that's the whole point of the rearchitect plan.
- Subagent memory files (bard, swain, syndra) are dirty — commit them in the session close sweep.
