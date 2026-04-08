# secrets/

Holds secrets, tokens, API keys, and any sensitive material the agents need at runtime.

## How to deliver a new secret to the Windows agent box (cafe / remote / phone)

1. On Mac/phone, open `tools/encrypt.html` in a browser (offline, no network).
2. Paste the raw secret. Hit **Encrypt**, then **Copy**.
3. In agent chat: `decrypt this into secrets/<group>.env as <KEY_NAME>:` then paste the ciphertext.
4. Agent feeds the ciphertext on stdin to `tools/decrypt.sh --target secrets/<group>.env --var <KEY_NAME>`.
5. Plaintext lives only in `secrets/<group>.env` (gitignored, mode 600). Never logged, never echoed, never in argv.

## Long-lived encrypted secrets (committed to repo)

Place ASCII-armored age blobs at `secrets/encrypted/<group>.age`. They are gitignore-excepted and SAFE to commit (ciphertext only). The repo is the sync layer; pull on Windows, decrypt at use time via `tools/decrypt.sh`.

## Hard rules

- **Never** `cat`, `type`, `Get-Content`, `head`, `tail`, or pipe `secrets/age-key.txt` through anything visible. Use `age-keygen -y secrets/age-key.txt` if you need the public key.
- **Never** call raw `age -d` outside `tools/decrypt.sh`. The pre-commit hook enforces this.
- **Never** assign decrypted plaintext to a parent-shell variable. `tools/decrypt.sh --exec` uses `exec env KEY=val -- cmd...` so the plaintext lives only in the child process env.
- `secrets/age-key.txt` is the Windows private key. ACL-locked to user `AD`. Lost = burn every secret encrypted to it.

## Rotation

Manual, on-demand. To rotate a secret: regenerate it at the upstream provider (this is the load-bearing step), then re-encrypt the new value with `tools/encrypt.html` and commit. Re-encrypting the same value is theater.
