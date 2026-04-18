# F4 — Age-Encrypt Env Bundles for Test Dashboard

**Date:** 2026-04-18
**Task:** #19 F4 — generate INGEST_TOKEN, write plaintext to /tmp, age-encrypt, commit ciphertext only.

## What Worked

- Writing plaintext to `/tmp` (never inside repo tree) then encrypting with `age -r <recipient> -o <repo-path>` keeps secrets out of the working tree entirely.
- Explicit `git add <file1> <file2>` (not `git add -A`) is the right pattern in shared working tree environments — prevents accidentally staging other agents' untracked files.
- Generating INGEST_TOKEN inline in bash and passing via shell variable (`$INGEST_TOKEN`) means the value never appears in any tool call argument or log.
- Deleting plaintext immediately after encryption before any git operation guarantees no leak window.

## Naming Convention

Existing `.age` files in `secrets/encrypted/` use single-word kebab-case (e.g. `canary.age`, `discord-bot-token.age`). Task F4 used dotted env-style names (`dashboards.prod.env.age`) — this is the first multi-segment name in that directory. Document the precedent for future tasks.

## Commit

SHA: `4a3fdc0`
Message: `ops: add encrypted env bundles for test-dashboard (F4)`
