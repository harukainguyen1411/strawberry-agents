---
date: 2026-04-24
created: 2026-04-24
concern: work
status: proposed
author: karma
owner: karma
complexity: quick
orianna_gate_version: 2
tests_required: false
---

# S2 demo-config-mgmt — strip orphan PATCH handler + harden its deploy.sh

## Context

`tools/demo-config-mgmt/main.py` (in `~/Documents/Work/mmp/workspace/company-os/`) locally defines a `PATCH /v1/config/{session_id}` handler (starts ~line 238), but the deployed Cloud Run revision `demo-config-mgmt-00014-2bn` does not have it. Root cause: the tool's `deploy.sh` runs `gcloud run deploy --source .`, which uploads the operator's working directory at deploy time — not git HEAD. There is no CI deploy pipeline. PR #87 already shipped a caller-side POST+RMW workaround, so the local PATCH handler is orphan code; the drift is inert but corrosive and would mask a future real divergence. <!-- orianna: ok -- work-workspace paths under company-os/tools/demo-config-mgmt/ -->

Scope is deliberately narrow: fix the observed divergence and harden only the deploy.sh that produced it. The six peer tool deploy.sh scripts, negative-regression tests, and SSE schema contract tests are *knowingly carried* risk — tracked in `assessments/work/2026-04-24-deploy-hygiene-residuals.md` for later.

## Decision

**Handler strip.** Delete the `@app.patch("/v1/config/{session_id}")` function and its body from `tools/demo-config-mgmt/main.py`. Leave GET/POST and shared helpers (`_session_configs`, `require_auth`, `_now`) untouched. <!-- orianna: ok -- work-workspace path; @app.patch is a Python decorator -->

**Deploy.sh hardening — `tools/demo-config-mgmt/deploy.sh` only:** <!-- orianna: ok -- work-workspace path -->

1. *Dirty-tree guard* — near the top, after `set -euo pipefail`, before any `gcloud` invocation:
   ```bash
   if [ -n "$(git status --porcelain)" ] && [ "${FORCE_DIRTY:-0}" != "1" ]; then
       echo "deploy.sh: refuse to deploy from dirty working tree. Offending files:" >&2
       git status --porcelain >&2
       echo "Commit, stash, or re-run with FORCE_DIRTY=1 for explicit local-only debugging." >&2
       exit 1
   fi
   GIT_SHA=$(git rev-parse --short=12 HEAD)
   [ "${FORCE_DIRTY:-0}" = "1" ] && GIT_SHA="${GIT_SHA}-dirty"
   ```

2. *Git-SHA stamping* — append to the existing `gcloud run deploy` flags:
   ```bash
   --labels=git-sha=${GIT_SHA}
   ```

Label (not env var) so it doesn't churn container revisions and is queryable via `gcloud run revisions list --format='value(metadata.labels.git-sha)'`.

## Tasks

- **T1** [impl, 15 min] Strip the PATCH handler from `main.py`. Files: `tools/demo-config-mgmt/main.py`. Detail: delete the `@app.patch("/v1/config/{session_id}")` decorator and the full `async def patch_config(...)` body starting ~line 238 through the next top-level `@app.` decorator. Do not touch `_session_configs`, `_get_session_config`, `require_auth`, or any GET/POST handler. DoD: `pytest tools/demo-config-mgmt/tests/` green locally; `ruff` / existing linters clean. <!-- orianna: ok -- work-workspace paths; Python identifiers -->
- **T2** [impl, 10 min] Harden `tools/demo-config-mgmt/deploy.sh` with the dirty-tree guard + git-sha label per the block above. DoD: `bash -n deploy.sh` passes; `shellcheck` clean on changed lines; manual dry-run with dirty tree exits 1 with clear message; clean tree proceeds; `FORCE_DIRTY=1` warns and stamps `-dirty` suffix. <!-- orianna: ok -- work-workspace path; deploy.sh is a relative script -->
- **T3** [chore, 5 min] Open PR. Title `chore(tools): strip S2 orphan PATCH handler + harden demo-config-mgmt deploy.sh`; body links PR #87, this plan, and the residuals assessment. Include `QA-Waiver: backend-only — no UI surface`. DoD: PR green on required checks; one non-author approval before merge.

## Verification

- Manual, in PR body checklist: (a) dirty tree → `./deploy.sh` exits 1; (b) `FORCE_DIRTY=1 ./deploy.sh` → warns, stamps `-dirty`; (c) clean tree → `gcloud run revisions list --filter='metadata.labels.git-sha:*'` shows the new revision with the correct 12-char SHA label. <!-- orianna: ok -- ./deploy.sh is a relative script path -->
- Not in scope: no CI-driven E2E against real Cloud Run; no backfill of existing revisions' labels (impossible without redeploy).

## Open questions

None — remaining scope calls (FORCE_DIRTY env var, `--short=12`, `git-sha` kebab label, demo-config-mgmt only) are pre-committed in the plan body above.

## References

- Base branch: `main` in `~/Documents/Work/mmp/workspace/company-os/`. <!-- orianna: ok -- work-workspace path -->
- PR #87 (caller-side POST+RMW workaround that made the PATCH handler orphan).
- Deployed revision `demo-config-mgmt-00014-2bn` — the divergence anchor.
- Residuals / knowingly-deferred follow-ups: `assessments/work/2026-04-24-deploy-hygiene-residuals.md`.
- Universal invariants: rule 5 (`chore:` prefix — tools/** is outside apps/**), rule 18 (no admin-merge).
