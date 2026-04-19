# Learning: Agent PAT rotation for auto-rebase workflow

Date: 2026-04-19

## What happened

`Auto-rebase PR` workflow was failing with `fatal: could not read Username` on
every push. Root cause: `AGENT_GITHUB_TOKEN` repo secret held a revoked token
(S49 leftover from wrong account or prior rotation).

## Steps that worked

1. Validate token BEFORE encrypting: `GH_TOKEN="$(cat <file>)" gh api user --jq .login`
   Must print `Duongntd`. If it prints anything else or 401s — stop immediately.
2. Encrypt: `age -r "$(grep -v '^#' secrets/recipients.txt | head -1)" -o secrets/encrypted/github-triage-pat.age <plaintext-file>`
3. Round-trip: pipe ciphertext through `tools/decrypt.sh --target secrets/.tmp --var V`,
   compare `${#value}` to original length. Never print the value.
4. Set secret: `gh secret set AGENT_GITHUB_TOKEN --body "$(cat <file>)" --repo harukainguyen1411/strawberry-agents`
5. Shred: `shred -u <file>` (or `rm` if shred unavailable)
6. Commit blob + push as Duongntd. The push itself triggers the workflow — no manual rerun needed.

## Pitfalls

- `secrets/github-triage-pat.txt` was the S49 stale file. The fresh PAT was at
  `secrets/github_pat.txt` (different name, no hyphen before "pat"). Always confirm
  mtime and validate via API before trusting a file in `secrets/`.
- `age -o` is non-deterministic — each encryption of the same plaintext produces
  different ciphertext. The blob in git will always show as modified after re-encryption,
  even if the underlying token is the same.
- `tools/decrypt.sh` reads ciphertext from STDIN, not as a positional arg.
  Correct usage: `cat file.age | tools/decrypt.sh --target secrets/out --var VARNAME`
- Duongntd's OAuth token (keyring, `gho_...`) already has `workflow` scope —
  plain `git push origin main` works without switching to harukainguyen1411.

## Secret inventory

- Local encrypted blob: `secrets/encrypted/github-triage-pat.age`
- Repo secret name: `AGENT_GITHUB_TOKEN` on `harukainguyen1411/strawberry-agents`
- Age recipient: `secrets/recipients.txt` (single line, no hardcoded strings)
