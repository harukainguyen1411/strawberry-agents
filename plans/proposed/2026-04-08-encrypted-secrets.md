---
title: Encrypted Secrets in Repo (age-based)
status: proposed
owner: evelynn
created: 2026-04-08
---

# Encrypted Secrets in Repo (age-based)

## Problem

Duong needs a way to deliver secrets (API keys, tokens, bot tokens, OAuth credentials) to agents running on the Windows box without:

1. Pasting plaintext into agent chat (ends up in conversation history, possibly memory files)
2. Letting plaintext enter the agent's working context as a printable variable (risk of summarization / accidental echo)
3. Typing secrets through the Mac→Windows remote-control link
4. Maintaining an out-of-band sync mechanism (Syncthing, rsync, network share) just for `secrets/`

He's primarily on a Mac, sometimes on his phone, and the agent runtime is on Windows. Both Mac and Windows have GitHub access; phone has GitHub via Working Copy.

The current `secrets/*.env` convention (gitignored plaintext files) doesn't solve the cross-device delivery problem — gitignored files don't sync via git, and we have no other sync layer.

## Goals

- **Plaintext never enters chat** (input or output direction).
- **Plaintext never enters the agent's long-lived context** as a printable string variable. Decryption flows directly into the consuming command via process substitution.
- **Git is the sync layer.** Encrypted blobs are committed to the repo. No additional sync infrastructure.
- **Multi-device encryption.** Mac, Windows, and phone can all add new secrets. Windows is the primary consumer. Mac can also decrypt for verification.
- **Native, minimal-dependency tooling.** One small static binary (`age`), no daemons, no PKI, no cloud KMS.
- **Survives session restart and machine reboot.** Secrets are persistent, not re-pasted each session.
- **Auditable.** `ls secrets/encrypted/` shows what exists. Rotation is `re-encrypt the file, commit`.

## Non-Goals

- Replacing the `secrets/` plaintext convention entirely. Plaintext `.env` files in `secrets/` are still allowed for things that are genuinely local to one machine and never need to cross devices. The encrypted-in-repo flow is for cross-device or sensitive material.
- Defending against full compromise of the Windows machine. If Windows is owned, the private key is exposed and so is everything ever encrypted to it. This plan reduces *exposure surface*, not *post-compromise blast radius*.
- Defending against a compromised/jailbroken model. Claude on Windows can decrypt by definition — it has the key. The protection is against chat-history leakage and casual context exposure, not against the model itself going rogue.
- Phone-side decryption. Phone only needs to *encrypt* new secrets. Decryption stays on Mac and Windows.

## Architecture

### Tool: `age`

- Modern asymmetric encryption (X25519 + ChaCha20-Poly1305), single ~2MB static binary, available on macOS (`brew install age`) and Windows (`winget install FiloSottile.age` or direct download from [github.com/FiloSottile/age/releases](https://github.com/FiloSottile/age/releases)).
- Multi-recipient encryption: a single ciphertext can be decryptable by *any* listed recipient. This is how multiple devices share access without sharing private keys.
- JS implementation exists (`age-encryption` npm package) for the phone-side static HTML encryptor.

### Per-device keypairs

- **Mac**: own keypair, generated locally. Private key stored at `~/.config/age/key.txt` (chmod 600). Used for decryption (verification, local use) and encryption.
- **Windows**: own keypair, generated locally. Private key stored at `%USERPROFILE%\.config\age\key.txt`. Used for decryption (this is where the agent consumes secrets) and encryption.
- **Phone**: no keypair. Phone only encrypts. It pulls the recipient list from the repo and encrypts against all listed public keys.

**Private keys never cross machines.** Each machine generates its own. Bootstrap is therefore safe — there is no moment where a sensitive value transits between hosts.

### Recipients file

`secrets/recipients.txt` (committed to repo, public keys only):

```
# Mac (duong)
age1abc...

# Windows (claude runtime)
age1def...
```

Public keys are public by definition. Committing them is correct.

When a new device is added, append its public key, re-encrypt all existing secrets to the new recipient list (one helper script handles this), commit. No private-key transfer ever occurs.

### Encrypted blobs

`secrets/encrypted/<group>.age` — one file per logical group (`telegram.age`, `github.age`, `anthropic.age`). Format inside the encrypted blob is plain `KEY=value` lines so it can be sourced after decryption.

These files **are committed to the repo.** That is the entire point — git becomes the sync layer.

`secrets/` (plaintext convention) remains gitignored. `secrets/encrypted/` and `secrets/recipients.txt` are explicitly *not* gitignored — they need to be tracked. Gitignore needs an exception:

```gitignore
secrets/
!secrets/encrypted/
!secrets/encrypted/**
!secrets/recipients.txt
!secrets/README.md
```

### Decryption flow (the critical bit)

Agents **never** do this:

```bash
# WRONG: plaintext lands in shell variable, may be echoed/logged/summarized
SECRET=$(age -d -i ~/.config/age/key.txt secrets/encrypted/foo.age)
some-command --token "$SECRET"
```

Agents **always** do this:

```bash
# RIGHT: plaintext flows directly into the command, never assigned to a variable
some-command --token "$(age -d -i ~/.config/age/key.txt secrets/encrypted/foo.age | grep ^TOKEN= | cut -d= -f2-)"
```

Or even better, use a helper script that does the extraction internally and pipes via stdin / fd / env-var-for-child-process-only:

```bash
# scripts/secret-with.sh foo TOKEN -- some-command --token-from-env
# the helper sets the env var ONLY in the child process, never in the parent shell
```

This is the core discipline. The plan should provide the helper scripts so agents have an easy right-thing-to-do path and never feel tempted to assign-to-variable.

## Bootstrap

Bootstrap is the moment most likely to leak. It must be done carefully and only once per device.

### Step 1: Install `age` on Mac and Windows

- Mac: `brew install age`
- Windows: `winget install FiloSottile.age` (or manual download + add to PATH)

Verify: `age --version` returns on both.

### Step 2: Generate Windows keypair (Duong does this via remote control session)

```bash
mkdir -p "$USERPROFILE/.config/age"
age-keygen -o "$USERPROFILE/.config/age/key.txt"
# outputs the public key to stderr; Duong copies it
```

The private key file is `chmod 600`-equivalent on Windows (NTFS ACL: only the user account). Verify ACLs.

### Step 3: Generate Mac keypair (Duong does this on Mac directly)

```bash
mkdir -p ~/.config/age
chmod 700 ~/.config/age
age-keygen -o ~/.config/age/key.txt
chmod 600 ~/.config/age/key.txt
```

### Step 4: Build `secrets/recipients.txt` and commit

Duong manually creates `secrets/recipients.txt` with both public keys. Commits to main directly (per CLAUDE.md rule 9, but also: this is not an "implementation" task, it's bootstrap data). Agent does not touch this file with a secret value — public keys are public.

### Step 5: Backup of private keys

Each machine's private key is single-point-of-failure for everything encrypted to it.

- **Mac key**: store a copy in macOS Keychain via `security add-generic-password -s age-private-key -a duong -w` (paste the file contents interactively). Optional second backup: print and store physically.
- **Windows key**: store a copy in Windows Credential Manager via `cmdkey` or PowerShell `Get-Credential` / `CredentialManager` module. Optional second backup: encrypted USB.

If a private key is lost, the corresponding device can no longer decrypt — but as long as at least one other device is in `recipients.txt`, no data is lost. New keypair, new entry in recipients, re-encrypt all blobs.

## Daily Flow

### Adding a secret (from Mac)

```bash
# scripts/secret-add.sh <group> <KEY> [<KEY> ...]
./scripts/secret-add.sh telegram BOT_TOKEN CHAT_ID
```

The script:
1. Prompts for each value with `read -s` (no echo, no shell history).
2. Decrypts `secrets/encrypted/telegram.age` if it exists (so we're appending, not overwriting).
3. Adds/updates the lines.
4. Re-encrypts to all recipients in `secrets/recipients.txt`.
5. Writes `secrets/encrypted/telegram.age`.
6. `git add` + `git commit -m "chore: update encrypted secrets (telegram)"` + `git push`.

Plaintext exists only in script-local variables for the duration of the script, never on disk, never in history.

### Adding a secret (from phone)

1. Open the static encryptor HTML in Safari/Chrome (saved to Home Screen, lives in iCloud Drive, or hosted on a private GitHub Pages — see "Phone Encryptor" below).
2. Paste recipient public keys (or it loads them from a hardcoded list — we'll bake them in at build time).
3. Type the secret. Hit encrypt. Copy ciphertext.
4. In Working Copy, open `secrets/encrypted/<group>.age`, paste, save, commit, push.
5. Agent on Windows pulls and uses.

Limitation: phone flow is "create new file from scratch" only — phone can't append to an existing encrypted blob because it can't decrypt it. Workaround: phone creates a new file like `secrets/encrypted/inbox-<timestamp>.age`, agent on Windows merges it into the canonical group file and deletes the inbox file.

### Using a secret (agent on Windows)

```bash
# Helper script handles process-substitution discipline
./scripts/secret-use.sh telegram BOT_TOKEN -- curl -H "Authorization: Bearer @SECRET@" https://...
```

The helper:
1. Decrypts `secrets/encrypted/telegram.age` to a temp pipe.
2. Extracts `BOT_TOKEN`.
3. Substitutes `@SECRET@` in the trailing command with the value.
4. Execs the command. Plaintext lives only in the child process's argv/env.

Alternative (simpler, rougher): inline `age -d` in the command via process substitution, no helper. Helper is preferred because it standardizes the discipline and gives one place to enforce "never echo."

### Listing what secrets exist

```bash
./scripts/secret-list.sh
# outputs: group + key names, NEVER values
# e.g.:
#   telegram: BOT_TOKEN, CHAT_ID
#   github: PAT
#   anthropic: API_KEY
```

This decrypts each blob, parses keys, prints key names only. Useful for "do I already have X?" without ever showing values.

## Phone Encryptor (static HTML)

A single self-contained `tools/encrypt.html` file:

- Embeds the `age-encryption` JS library (vendored, ~50KB minified).
- Embeds the current public keys from `secrets/recipients.txt` at build time (regenerated whenever recipients change — a small build step in `scripts/build-phone-encryptor.sh`).
- UI: textarea for plaintext, button "Encrypt", textarea for ciphertext output with copy button.
- No network requests. No analytics. Purely local computation.
- Lives in the repo at `tools/encrypt.html`. Phone gets it via Working Copy (which clones the repo) or via iCloud Drive sync.

Trust model: the file is generated and reviewed on the Mac, then synced to phone. Tampering would require compromising the repo or the Mac. No third-party page is involved.

## File Layout

```
secrets/
  README.md                    # convention docs (existing, will be updated)
  recipients.txt               # COMMITTED - public keys
  encrypted/                   # COMMITTED
    telegram.age
    github.age
    anthropic.age
  *.env                        # gitignored - plaintext, machine-local only

scripts/
  secret-add.sh                # add/update a secret (Mac or Windows)
  secret-use.sh                # decrypt-and-exec helper (Windows agent path)
  secret-list.sh               # list keys (no values)
  secret-rotate.sh             # re-encrypt all blobs (e.g. after recipients change)
  build-phone-encryptor.sh     # regenerate tools/encrypt.html with current pubkeys

tools/
  encrypt.html                 # phone-side static encryptor

.gitignore                     # add exceptions for secrets/encrypted/, recipients.txt
```

## Convention & Memory Updates

- `secrets/README.md`: extend with the encrypted-in-repo flow as the **primary** path; demote plaintext `*.env` to "machine-local fallback only."
- `feedback_secrets_handling.md` memory: update to reference the new flow. New rule: "When a secret is needed, check `secrets/encrypted/` first. If the secret exists, use `secret-use.sh`. If not, prompt Duong to add it via `secret-add.sh` (Mac) or the phone encryptor (phone)."
- `CLAUDE.md` Secrets Policy section: update to mention `secrets/encrypted/` as the canonical location for cross-device secrets.

## Open Questions

1. **Helper script language: bash or Python?** Bash is zero-dependency on Mac, slightly awkward on Windows (git-bash has quirks with paths and process substitution). Python is consistent across both but adds an interpreter dependency. **Recommendation: bash, because git-bash is already required for the rest of the agent infra and the scripts are short.**
2. **Where does the phone encryptor live for Safari?** Working Copy can serve files via a local web server, or Duong can save the file to Files/iCloud and open with "Open in Safari." Both work; the Working Copy path is slightly tighter because it auto-syncs from git. **Recommendation: document both, let Duong pick.**
3. **Should `secret-use.sh` enforce a denylist of dangerous patterns?** E.g. block `--token "$(...)" | tee` style commands that would re-leak. Probably overkill — discipline lives in the agent's behavior, not the wrapper. **Recommendation: no, but document the rule clearly in `secrets/README.md`.**
4. **Bootstrap key transfer for backups.** The Mac private key in Keychain and the Windows key in Credential Manager — should the plan also commit a (passphrase-encrypted-with-age-itself) backup of each private key to the repo? This would solve "machine dies" recovery without requiring out-of-band backup. Ergonomically nice; cryptographically equivalent to having a strong passphrase. **Recommendation: yes, as an optional Phase 2.**

## Success Criteria

- `age` installed on Mac and Windows; `age --version` works on both.
- Per-device keypairs generated; private keys at the documented paths with correct permissions.
- `secrets/recipients.txt` committed with both public keys.
- `.gitignore` updated with the necessary exceptions.
- All four helper scripts exist and are executable: `secret-add.sh`, `secret-use.sh`, `secret-list.sh`, `secret-rotate.sh`.
- `tools/encrypt.html` exists and works in Safari (manual test: encrypt a known string on phone, decrypt on Mac, verify match).
- `secrets/README.md` updated to reflect the new primary flow.
- `feedback_secrets_handling.md` memory updated.
- One real test secret round-trips successfully: added on Mac via `secret-add.sh`, pushed, pulled on Windows, consumed via `secret-use.sh`, observable side effect (e.g. successful API call).
- Plaintext never appears in: chat history, agent context, shell history, commit history, log files.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Agent assigns decrypted value to a shell variable and echoes it | Use `secret-use.sh` exclusively; document the rule; the helper script is the only sanctioned path |
| Private key on Windows leaks via tool call output | Key file is `~/.config/age/key.txt`, not in the repo, not in any tool argument; agent never `cat`s it |
| Recipient public key list drifts (one machine added without re-encrypting old blobs) | `secret-rotate.sh` re-encrypts every blob to current recipients; run after every recipients change |
| Phone encryptor HTML gets tampered | File is generated on Mac, reviewed, committed to git. Tampering requires repo compromise. Optional: commit a SHA256 of the file alongside it and verify before opening on phone |
| Loss of a private key | Backup to OS keychain on each machine (Mac Keychain / Windows Credential Manager); optional Phase 2 passphrase-encrypted backup committed to repo |
| Bootstrap mistake (key generated in wrong location / wrong perms) | Bootstrap is documented as a manual checklist Duong runs once; agent does not perform bootstrap |

## Out-of-Scope (Future Work)

- Hardware-backed keys (YubiKey via age-plugin-yubikey)
- Per-secret access control (some secrets only decryptable by some devices)
- Audit log of secret access
- Automatic rotation reminders
- Integration with cloud KMS (sops-style)

## Pyke Review

*Reviewer: Pyke (security specialist). Date: 2026-04-08. Review of Evelynn's draft above.*

### Overall verdict

**Approve with changes.** The skeleton is sound — `age`, per-device keypairs, multi-recipient encryption, git-as-sync, helper-mediated decryption — that's the right shape. But several pieces are underspecified or wrong in ways that matter, and the threat model has at least three blind spots that need to be named explicitly before this goes live. List the changes, fix them, then it's good. Don't ship as-is.

### Strengths to keep (don't touch)

- Tool choice (`age`) and the X25519 multi-recipient model. Correct for this use case.
- Per-device keypair generation with no private-key transit. The bootstrap-safety claim is *almost* true (see Required Change 1).
- The "process substitution, never assign to a variable" discipline as the central rule.
- Splitting `secrets/encrypted/` from gitignored `secrets/*.env`. The gitignore exception block is correct.
- Phase 2 deferral of passphrase-encrypted private-key backups — that's the right call, don't pull it forward.
- Phone is encrypt-only. Resist the urge to add decryption later.

### Required changes (numbered, with rationale)

1. **Sharpen the bootstrap-safety claim — it's not unconditionally true.** The plan states "private keys never cross machines, so bootstrap is safe." Two leaks the draft misses:
   - The Windows keypair is generated **inside the remote-control session from the Mac**. If that session is RDP / VNC / VS Code Remote, the keystrokes and the terminal output of `age-keygen` (which prints the *public* key but the file is written locally — fine) and any subsequent `cat key.txt` (which would print the *private* key) traverse the remote-control transport. Public key transit is fine. Private key transit is not. **Required edit:** add a Bootstrap Discipline note: "Never `cat` the Windows private key file inside a remote-control session. Read the public key only — it is printed by `age-keygen` to stderr at generation time and can be re-derived later via `age-keygen -y key.txt`. The private key is written to disk by `age-keygen` and stays there." Also: clarify in Step 2 that the public key shown in the remote-control terminal is the *public* key, and that's what gets copied into `recipients.txt`.
   - Mac and Windows clipboards: if Duong copies a public key on Mac and pastes it into a Windows-side editor through a clipboard-sharing remote-control tool, that's still public-only and fine. Document it explicitly so nobody gets clever with private keys later.

2. **Add the "compromised key burns every secret ever encrypted to it" rule, loudly.** The plan covers re-encryption after recipient *list* change (`secret-rotate.sh`) but does not address the case where a private key is *exfiltrated*. Git history is forever. Every `.age` blob ever committed and decryptable by the compromised key is now plaintext to the attacker, *including blobs that have since been "rotated."* Re-encrypting the file in HEAD does nothing — the old blob is in `git log -p`. **Required edit:** add a new section "Compromise Response":
   - If a private key is suspected leaked: (a) generate new keypair on the affected device, (b) update `recipients.txt`, (c) **rotate every secret value upstream** (regenerate the Telegram bot token, the GitHub PAT, the Anthropic API key, etc. at each provider), (d) re-encrypt with the new values to the new recipient set, (e) commit. Step (c) is the load-bearing one. Just re-encrypting with the same plaintext is theater.
   - Optionally: a `git filter-repo` purge of the old `secrets/encrypted/` blobs from history is *not* required for security (the values are dead) but reduces noise. Document this as nice-to-have, not required.
   - This deserves its own subsection because it inverts the intuition. "Rotation" in this system means *rotating the secret value at the provider*, not re-encrypting the file.

3. **`secret-use.sh` with `@SECRET@` placeholder substitution is dangerous as drafted — replace it.** String-substituting a secret into the trailing argv has three failure modes:
   - **Argv exposure**: any value placed in argv is visible to other processes via Windows Task Manager / `Get-Process` / `wmic process` / on Mac via `ps -E`. Argv is not a secret channel.
   - **Shell-injection / re-quoting risk**: if the secret contains characters that are special in the consuming command's parser (`$`, `` ` ``, `"`, `\`, newline), substituting it as a literal string into a pre-tokenized argv array is fine, but if the helper does the substitution by re-rendering and re-evaluating a command string (which the draft language hints at), the secret can break out of its quoting and execute as code. The draft is ambiguous about which path it takes.
   - **Logging**: any wrapper that logs invocations (and many do — Claude Code itself surfaces command strings in tool-call summaries) will capture the substituted argv.

   **Required edit:** replace the `@SECRET@`-in-argv design with **environment-variable-into-child-process-only**, like this:

   ```bash
   # scripts/secret-use.sh <group> <KEY> [<KEY>...] -- <command> [args...]
   # Decrypts the named keys, exports them ONLY into the child process's env, execs the command.
   # Plaintext never appears in argv, never in the parent shell, never in any string the parent sees.
   ```

   Implementation sketch (do not include in the plan as code; describe the contract):
   - Helper reads ciphertext, decrypts via `age -d -i ...`, parses out only the requested KEYs.
   - Builds an env block (associative array in bash 4 / a here-doc fed to `env -S` / a transient file under `/dev/fd/`).
   - `exec env KEY1=val1 KEY2=val2 -- "$@"` — the secret values are arguments to `env`, which means they appear in `env`'s argv for a microsecond before `exec`. On Linux this is observable; on Windows under git-bash, `env` is provided by msys and the same caveat applies.
   - Better: use `env -S` reading from a file descriptor, or `bash -c '...' bash` with the env pre-set via `declare -x` in a subshell. Best: a tiny Go/Rust helper that does `setenv` then `execve` directly with no intermediate process. **For this plan, document the contract and let the implementer pick the safest bash-only form.**
   - The consuming command then reads `$KEY1` from its own env. Most CLIs already support env-var token forms (`GH_TOKEN`, `TELEGRAM_BOT_TOKEN`, etc.).
   - Forbid the `@SECRET@` placeholder pattern entirely. Document the rejection in the helper's header comment.

4. **Gitleaks will misbehave on `.age` files — pre-empt it.** ASCII-armored age blobs start with `-----BEGIN AGE ENCRYPTED FILE-----` and contain high-entropy base64. Gitleaks default rules include a "generic high-entropy string" detector that *will* flag these. Two failure modes: (a) every commit to `secrets/encrypted/` gets blocked, (b) Duong learns to bypass the hook and stops trusting it for real findings. **Required edit:** add to the plan a `.gitleaks.toml` allowlist entry:
   ```toml
   [allowlist]
   paths = [
       # ... existing entries ...
       '''secrets/encrypted/.*\.age''',
       '''secrets/recipients\.txt''',
       '''tools/encrypt\.html''',
   ]
   ```
   And explicitly state in the plan that the allowlist update is part of the implementation, not a follow-up. Note: `recipients.txt` contains only public keys (`age1...`) which look like bech32 and probably won't trip default rules, but allowlisting it costs nothing and prevents future surprise. `tools/encrypt.html` will embed pubkeys at build time and should also be allowlisted to avoid the embedded-key heuristic firing.

5. **Windows NTFS ACL command is hand-waved — specify it.** "`chmod 600`-equivalent on Windows (NTFS ACL: only the user account)" is not actionable. The actual command in git-bash / PowerShell:

   ```powershell
   # PowerShell, run as the user who owns the key
   $keyPath = "$env:USERPROFILE\.config\age\key.txt"
   icacls $keyPath /inheritance:r
   icacls $keyPath /grant:r "${env:USERNAME}:(R,W)"
   icacls $keyPath /remove "BUILTIN\Users" "Everyone" "Authenticated Users" 2>$null
   ```

   Pitfalls to document:
   - `icacls /inheritance:r` removes inherited ACEs. If you skip this step, the file inherits ACLs from `%USERPROFILE%\.config\` which may include `Users` read access depending on how the directory was created.
   - The directory itself (`%USERPROFILE%\.config\age\`) should also have inheritance disabled and be locked to the user, otherwise the file's ACL is moot — anyone with directory traverse + read can see the contents on next inheritance reset.
   - **git-bash `chmod 600` on Windows is a no-op for ACL purposes.** It only flips the read-only bit. Do not rely on it. The plan must explicitly say so.
   - Verification command: `icacls "$env:USERPROFILE\.config\age\key.txt"` should show only the owning user with `(R,W)` and no other principals.

   **Required edit:** add the icacls commands (or a `scripts/lock-windows-key.ps1` referenced from the bootstrap section) as part of Step 2. Add a verification step.

6. **git-bash process-substitution and line-ending caveats.** The plan assumes `<(...)` and `>(...)` work identically on Mac bash and Windows git-bash. They mostly do, but:
   - git-bash translates `/dev/fd/N` paths in some contexts and not others. If the consuming command receives a path argument that points to `/dev/fd/63`, msys may rewrite it to a Windows path and break it. Test this for any consumer that takes a `--config-file` style flag.
   - `age` itself reads/writes binary by default, but if `secret-add.sh` ever pipes plaintext through `read` or `cat` on Windows, CRLF translation will corrupt values containing `\r` or trailing whitespace. **Required edit:** the helper scripts must explicitly set `LC_ALL=C` and use `printf '%s'` (not `echo`), and the encrypted format inside the blob should be documented as LF-only. Add a one-line warning to the plan.
   - Path quoting: any helper that takes a path argument from `$USERPROFILE` or `$HOME` on Windows must double-quote it. `$USERPROFILE` contains `\Users\AD\` — backslashes are fine in quoted strings but become escape sequences if the script ever interpolates them through `eval` or `printf %s`.

7. **Phone encryptor: commit a SHA256 alongside, and pin the JS library.** The trust model section says "tampering would require compromising the repo or the Mac." True, but a tamper of the in-repo HTML file would be invisible on phone — Working Copy doesn't show diffs the way an editor does, and Duong is unlikely to read the minified JS line by line on a phone screen before opening it. Two cheap mitigations:
   - **Required:** publish `tools/encrypt.html.sha256` next to the file. Duong (or a Mac-side script) verifies the hash before opening on phone the first time, and re-verifies whenever it changes. The verification can be a one-liner Duong runs on Mac before pushing.
   - **Required:** the vendored `age-encryption` JS bundle must be pinned to a specific version + integrity hash, vendored verbatim into the repo (not loaded from a CDN, ever), and the build script must verify the upstream hash before vendoring. State this explicitly — "no `<script src=...cdn...>` tags" needs to be a written rule.
   - **Recommended:** also commit a plaintext `tools/encrypt.html.txt` containing the human-readable parts of the file (everything except the vendored library), so diffs are reviewable in PRs / `git log -p`.

8. **The "never assign to a variable" rule is aspirational without a guard.** The plan acknowledges this and shrugs. That's not enough for a system where the consumer is an LLM that will absolutely, eventually, decide a `cat secrets/encrypted/foo.age` is "just for debugging." **Required edit:** add a tooling-level guard. Two layers:
   - **Guard 1 (cheap, do this now):** a pre-commit hook addition (or a separate hook) that fails if any staged file or any agent memory file under `agents/` contains a literal `BEGIN AGE ENCRYPTED FILE` header outside the `secrets/encrypted/` directory. That catches the case where a decrypted blob gets accidentally pasted into a memory file.
   - **Guard 2 (cheap, do this now):** a pre-commit hook that fails if any staged file contains a known plaintext value from a decrypted secret. Implementation: at commit time, decrypt all blobs to a temp tmpfs location, scan staged files for any of the values, fail loud if found, wipe the temp location. This is the "scrub-and-detect" pattern. The decryption is local-only and the values never leave the hook's process.
   - **Guard 3 (deferred, document only):** an LD_PRELOAD-style stdout/stderr scrubber that replaces any decrypted-secret bytestring with `[REDACTED]` in process output. Real but heavy. Note as future work, do not include in v1.
   - **Required edit also:** add a `CLAUDE.md` rule (rule 11 or 4-bis): "Never read decrypted secret values into the assistant's context. Use `secret-use.sh` exclusively. Never `cat`, `age -d`, or `grep` an `.age` file in a tool call." This makes the rule first-class and gives the agent a hard line to refuse the temptation.

9. **Plan owner/implementer hygiene per CLAUDE.md rules 7 and 8.** The plan frontmatter has `owner: evelynn`, which is correct for authorship. Confirming: no implementer is assigned anywhere in the plan body, and Required Changes 1-8 above also do not assign implementers. After Duong moves this to `approved/`, Evelynn will delegate.

### Recommended changes (nice-to-haves)

1. **Add `secret-show-recipients.sh`** — a one-liner that prints the current recipients with comments, so Duong can verify "is the new Windows machine in here?" without opening a text editor on a remote-control session.
2. **Add a "first decrypt after pull" canary.** When Windows pulls a new commit that touches `secrets/encrypted/`, run a `secret-list.sh` (which only prints key names) automatically as a post-merge hook. If decryption fails for any blob, scream — that means the recipient list drifted and Windows wasn't re-encrypted to. Catches Required Change 2's drift case before it bites in production.
3. **Document the "phone inbox" cleanup discipline.** The plan says "agent on Windows merges the inbox file and deletes it." Without a deadline, inbox files will accumulate, each one being a fresh ciphertext that bloats history. Add: "Inbox files must be merged within 24 hours and the inbox path is `secrets/encrypted/inbox/<timestamp>.age` so it's clearly a staging area."
4. **Use distinct group prefixes for different secret tiers.** E.g. `secrets/encrypted/runtime/*.age` for things the agent reads constantly vs `secrets/encrypted/recovery/*.age` for things only used in incident response. Lets `secret-use.sh` apply different policies later if needed.
5. **Mention `age-keygen -y` in the plan.** It re-derives the public key from a private key file. Useful for "did I lose my recipients.txt entry, what's my pubkey again?" — comes up in practice.
6. **`secret-rotate.sh` should refuse to run if the working tree is dirty** in `secrets/encrypted/`. Otherwise a half-rotation can land mixed-recipient blobs. Cheap safety belt.
7. **Add `git config --local core.autocrlf false`** as a documented requirement for any clone of this repo on Windows, because CRLF mangling of `.age` files (if they're ever opened in a Windows editor that "fixes" line endings) silently corrupts ciphertext. ASCII-armored age is line-sensitive.

### New risks I missed (not in the original Risks table)

| Risk | Mitigation |
|---|---|
| **Compromised private key → all historical blobs decryptable forever via git history** | Treat key compromise as full secret-value rotation at the upstream provider, not just file re-encryption. Documented in new "Compromise Response" section (Required Change 2). |
| **Argv-leaked secrets via `secret-use.sh @SECRET@` placeholder** | Replace with env-var-into-child-process-only design (Required Change 3). |
| **Gitleaks false-positive blocks legitimate `.age` commits, training Duong to bypass the hook** | Allowlist `secrets/encrypted/.*\.age` in `.gitleaks.toml` (Required Change 4). |
| **NTFS ACL inheritance leaves Windows private key world-readable despite `chmod 600`** | Use `icacls /inheritance:r` + explicit grant; verify with `icacls`; document that git-bash `chmod` is a no-op (Required Change 5). |
| **CRLF translation corrupts ASCII-armored age blobs on Windows** | `core.autocrlf false`; helper scripts use `LC_ALL=C` and `printf '%s'`; document the rule (Required Change 6 + Recommended 7). |
| **Decrypted plaintext leaks into agent memory files via "I'll just cat this for debugging"** | Pre-commit guard that blocks `BEGIN AGE ENCRYPTED FILE` headers outside `secrets/encrypted/` and scans staged files for known decrypted values (Required Change 8). |
| **Phone encryptor HTML tampered between Mac generation and phone use** | SHA256 sidecar file + pinned vendored JS library + no CDN scripts (Required Change 7). |
| **Remote-control session keystroke/screen capture during bootstrap** | Bootstrap discipline note: never `cat` private keys over remote-control; use `age-keygen -y` to re-derive pubkeys; only public material crosses the link (Required Change 1). |
| **`secrets/encrypted/inbox/` files accumulate forever, growing repo size and decryption surface** | 24-hour merge SLA + dedicated `inbox/` subdirectory (Recommended 3). |
| **Recipient list drift: Windows added but old blobs only decryptable by Mac, agent fails silently mid-task** | Post-merge canary that runs `secret-list.sh` and screams on decrypt failure (Recommended 2). |

### Open questions for Duong

1. **What is the Mac→Windows remote-control transport actually?** RDP / VNC / VS Code Remote / Parsec / something else? This determines (a) whether bootstrap is keystroke-capturable in transit and (b) whether the clipboard is shared in both directions. The plan should not be approved until this is named, because Required Change 1's wording depends on it.
2. **Are you willing to add a `CLAUDE.md` rule "agents must never `cat` or `age -d` an `.age` file outside `secret-use.sh`"?** This is the cleanest way to make the discipline first-class. Pyke recommends yes.
3. **Phase 2 passphrase-encrypted private-key backups: include the design now or defer entirely?** The plan currently says "yes, as Phase 2." If you want, Pyke can sketch the design as a follow-up plan once v1 is implemented and you have a real feel for the daily flow.
4. **Acceptable rotation cadence?** No matter how careful the discipline, decrypted values eventually leak into *something* — a process tree snapshot, a crash dump, a tool-call log. A scheduled "rotate everything every N days" ritual provides defense-in-depth. Pyke suggests 90 days for non-critical, 30 days for the things that can move money or post in Duong's name. Needs your buy-in.
5. **Windows account hardening.** The Windows private key sits in `%USERPROFILE%\.config\age\key.txt`. Is the Windows user account `AD` a standard user or an admin? Is BitLocker enabled on `C:`? Both materially change the threat model and neither is mentioned. Not blockers for v1, but Pyke wants them on record.
6. **Should `.age` blobs in `secrets/encrypted/` be signed (detached signature) by the committer?** Adds tamper-evidence on top of encryption. Probably overkill for a single-operator system; flagging in case you want it.

### Pyke's note

The discipline this plan demands — never let plaintext touch a printable variable — is the kind of rule that holds for six weeks and then breaks the first time something is "urgent." The guards in Required Change 8 are the only reason this design is safe long-term. Don't ship without them. The cryptography is the easy part. The discipline is the hard part. Build the fence before you need it.

— Pyke
