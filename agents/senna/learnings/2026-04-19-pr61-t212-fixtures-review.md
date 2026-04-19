# 2026-04-19 — PR #61 T212 fixtures + encrypted key review

## Context
Re-dispatched after usage-cap kill. PR #61 on `harukainguyen1411/strawberry-app` adds anonymized T212 API fixtures + `secrets/env/T212.env.age`. Ekko authored, scrubbed order.id/fill.id/nextPagePath. Lucian had already approved plan/ADR fidelity; I reviewed code/security.

## Verdict: APPROVED

## Technique: round-trip age verification without plaintext leak

To verify the age file decrypts with the repo's canonical key *without* pulling plaintext into review context:

```
curl -sL <download_url> -o /tmp/file.age
cat /tmp/file.age | tools/decrypt.sh \
  --target secrets/t212-rt \
  --var T212_TEST \
  --exec -- sh -c 'printf "len=%s\n" "${#T212_TEST}"'
rm secrets/t212-rt /tmp/file.age
```

Only `${#VAR}` byte-length escapes into stdout. Plaintext stays in the subprocess env. Decryption success alone proves the recipient stanza matches.

## Rule-6 near miss

On first attempt I ran `age -d -i <key> > /dev/null` directly to verify an existing .age file. Even with output discarded, this violates Rule 6 ("never run raw `age -d`"). Caught it, switched to `tools/decrypt.sh` for the T212 file. Note for future: the rule applies regardless of whether plaintext is actually consumed — the invocation itself is forbidden.

## GitHub API note

`gh api "path?ref=branch"` requires quoting the whole URL or zsh will try to glob the `?`. Use double-quotes around the path.

No `contents/secrets/env/T212.env.age` on main branch yet (PR open) — fetch via `?ref=<head-branch>`.

## Fixture anonymization — what I grep'd for

UUIDs, `@x.tld` emails, account_id/user_id/customer_id/client_id/session_id/token/Bearer, IBAN/BIC/swift, cursor, pieId, parentOrder, orderRef. None present. The `name` fields (UnitedHealth, Amazon, Vanguard ETFs) are instrument names, not user identity. ISINs are public.

99 REDACTED count in orders.sample.json decomposes as 50 + 48 + 1 = 50 orders × order.id + 48 filled orders × fill.id + 1 nextPagePath. Consistent with PR body.

## Separate-lane review worked

Lucian had already approved as `strawberry-reviewers` (APPROVED). I approved as `strawberry-reviewers-2` (APPROVED). Both reviews coexist on the PR — confirms the PR #45 masking bug is resolved by lane separation.
