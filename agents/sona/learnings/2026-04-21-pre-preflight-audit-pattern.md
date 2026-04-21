# Pre-preflight audit catches deploy blockers before preflight burns time

**Date:** 2026-04-21
**Session:** Ship-day seventh leg (shard 2026-04-21-c83020ad)

## What happened

Ekko ran preflight against Heimerdinger's deploy checklist and immediately surfaced three blockers:
- B1: `deploy.sh` referenced lowercase-hyphen secret names (`ds-factory-token`) that do not exist in Secret Manager; the live services use uppercase with underscores (`DS_FACTORY_TOKEN`).
- B2: `google-cloud-firestore` was missing from demo-factory's `requirements.txt`; PR #61 had added Firestore usage without updating the dep manifest.
- B3: MCP handshake smoke required secret decryption that agents cannot perform (Rule 6).

B1 and B2 were fixable (PR #63), B3 escalated to Duong. But all three were discoverable without executing preflight — a targeted code scan would have caught them earlier in the session, before the ship-day clock was running.

## The generalizable pattern

Deploy blockers of the **static analysis** class (wrong secret names, missing pip deps, missing env vars in deploy scripts) can be found without deployment. Before dispatching Ekko or Heimerdinger for actual preflight:

1. Dispatch **Camille** (git/security) or **Heimerdinger** (DevOps advice) for a **pre-preflight audit** — read all deploy scripts, requirements files, and environment variable references against the actual Secret Manager / Cloud Run config.
2. Fix any static blockers in a single PR before running preflight.
3. Only then dispatch Ekko for the actual preflight sequence.

This pattern splits the day into: (a) static correctness pass → (b) runtime preflight → (c) deploy. It prevents preflight from discovering fixable problems that then require another full preflight cycle.

## What this saves

- Preflight time (Ekko context is expensive)
- Round trips (blocker → fix PR → re-preflight → re-check)
- Ship-day pressure (blockers found early are less stressful than blockers found mid-sequence)

## When this applies

Any time the deploy target (Cloud Run, GKE, bare VM) uses deploy scripts, requirements files, or secret names that may have drifted since last verified. Especially relevant when multiple engineers/agents have touched the service configs in parallel.
