# Local service stub divergence from deployed contract causes silent failures

**Date:** 2026-04-24
**Session:** 84b7ba50-c664-40d8-9865-eb497b704fb3
**Trigger:** Local W3 testing — `set_config` silently failed because `tools/demo-config-mgmt/main.py` (local S2 stub) implements the pre-W3 contract: reads `initialConfig` (not `config`), create-only (no update path), while deployed S2 on Cloud Run implements the W3 contract.

## Learning

When a wave ships a new API contract (W3 changed `initialConfig` → `config` and added update/force-bypass semantics), the local dev stub in the `tools/` directory does not automatically update. PR #103 updated the main service but left the local stub at the old shape. This creates a silent failure mode: `set_config` calls succeed with HTTP 200 (create on first call) but ignore the payload shape silently, so the config never actually updates.

## Detection

The signal is: service returns 2xx but the expected side-effect does not occur. In this case: `set_config` returned no error but Duong saw no config change reflected in the session. This is a "silent failure" pattern — the worst kind.

## Fix

Duong's scope decision: do not update the local stub (S2 is not a dev priority); instead, remove the local S2 override from `.env.local`. The local server falls back to the deployed prod URL in `.env`. This is the correct mitigation when the stub cannot be updated immediately.

## Standing rule

When dispatching a builder to implement a new contract wave:
1. Check whether there is a local stub in `tools/` for the service being updated.
2. If yes, the builder task must include updating the local stub OR explicitly note the divergence as a residual in the plan.
3. In the interim, local dev should point at deployed service (comment out `*_URL=http://localhost:*` in `.env.local`).

## Corollary

When local testing produces unexpected `set_config` / update failures with 2xx responses, probe the deployed service endpoint directly to compare contract shapes before debugging S1 code.
