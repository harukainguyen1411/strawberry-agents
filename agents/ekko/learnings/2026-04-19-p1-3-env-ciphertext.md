# P1.3 — Encrypted Dotenv Bootstrap

**Date:** 2026-04-19
**Task:** Bootstrap `secrets/env/myapps-b31ea.env.age` in strawberry-app

## What Was Done

- Decrypted `bee-sister-uids.age` via `tools/decrypt.sh` (writes to temp secrets/ file)
- Assembled plaintext env in `secrets/.tmp-myapps-env.env` (gitignored), deleted immediately after encryption
- Encrypted with `age -e -r <recipient>` into worktree `secrets/env/`
- Created `.example` template with four key names, empty values
- Had to update `.gitignore` to add `!secrets/env/` and `!secrets/env/*.age` / `!secrets/env/*.example`
- Had to update `scripts/hooks/pre-commit-secrets-guard.sh` Guard 1 allowlist to include `secrets/env/` and Guard 4 skip list for `secrets/env/*`

## Key Lesson: pre-commit-secrets-guard Guard 1

Guard 1 blocks any file with `BEGIN AGE ENCRYPTED FILE` outside `secrets/encrypted/`. The allowlist is a single regex in the script. When storing age files in a new subdirectory (e.g., `secrets/env/`), the guard must be updated alongside the `.gitignore`.

## decrypt.sh Behavior

`tools/decrypt.sh` writes `VARNAME=<entire-plaintext>` to the target file. When the plaintext itself contains `KEY=value` lines, the output is a single variable wrapping the entire multi-line content. Use Python or awk to parse the inner keys for verification.

## Re-encrypt github-triage-pat.age

Straightforward: `age -e -r <recipient> -a -o output.age input.txt`. The old ciphertext was 5 lines shorter (likely a different PAT length).
