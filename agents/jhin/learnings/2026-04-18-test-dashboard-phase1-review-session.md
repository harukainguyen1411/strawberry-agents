---
name: Test Dashboard Phase 1 Review Session
description: Key patterns and gotchas from reviewing 15+ PRs across the test-dashboard Phase 1 workstream
type: project
---

Long review session covering the full test-dashboard Phase 1 workstream. Key findings and patterns to remember:

**Batch writes:** Firestore batch cap is 500 writes. Guard must count ALL write types: 1 run + N cases + M artifact docs + M' case-backfill updates. Correct formula: `1 + cases + 2 * artifacts > 500`. Cases-only guard is insufficient when artifact_uploads is non-empty.

**Partial-write hazard pattern:** `batch.commit()` before `createUploadUrl()` — GCS failure orphans Firestore docs. Always generate signed URLs (fallible external calls) before committing the batch.

**deploy script pnpm:** Scripts calling `pnpm` in CI fail on stock runners. Use `npm run build --workspace <pkg>` for npm workspaces. Verify package manager via `package-lock.json` presence and root `package.json` `"packageManager"` field.

**Stale-view incidents:** Reading local working tree instead of fetching from origin caused 5 phantom findings. Protocol: `git fetch origin` + `git show origin/<branch>:path` before every review, no exceptions. Never rely on context carried between review rounds.

**Rule 18 violation caught:** PR #159 merged by Duongntd with zero reviews (`reviewCount: 0`, admin bypass). Bad content (gcr.io instead of AR host) landed on main. PR #180 created as remediation. Escalated to Evelynn.

**`it.fails` vs `it.failing`:** Vitest 4.x uses `it.fails`; `it.failing` is Playwright API — silently registers 0 tests in Vitest. Always grep for `it.failing` on Vitest xfail files.

**Artifact Registry host:** `<region>-docker.pkg.dev/<project>/<repo>/<image>` — `gcr.io` is deprecated Container Registry, rejected at docker push.

**`--service-account` on gcloud run deploy:** Must be explicit — default compute SA has wrong IAM permissions for dashboards SA role.

**POSIX portability (rule 10):** Scripts outside `scripts/mac/` must use `#!/bin/sh` + `set -eu` (no `pipefail`, no bash-isms).

**Why:** Real deployment failures and silent test registration gaps. These are load-bearing correctness properties, not style.
