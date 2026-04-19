---
date: 2026-04-19
topic: portfolio-v0-handlers-review
prs: [34, 36, 40, 41, 42]
repo: harukainguyen1411/strawberry-app
---

# Portfolio v0 Handlers Review (V0.4–V0.8)

## Patterns discovered

### Flat-vs-structured FX rate input discriminator
`'rates' in obj` is fragile when a flat rate map could have a key named `'rates'`.
Pattern: use a branded type or a dedicated constructor instead of union discriminators on plain Record types.

### `set({ ...obj, id: undefined })` Firestore pattern
Firestore Admin SDK silently drops `undefined` fields on `set()`. This is the correct way to strip the `id` field before writing. However it creates an implicit contract that consumers must reconstruct `id` from `doc.id`. Always document this in a comment.

### In-memory mock vs emulator for B.2 integration tests
The V0.8 implementer used an in-memory mock instead of the Firebase emulator. The mock correctly validates path-level isolation (userA paths vs userB paths) but cannot exercise Security Rules. This is a known gap — the rules are tested separately in B.1. At review time: accept the gap if B.1 is thorough; flag it for the exit sign-off.

### Cash currency hardcode
Writing `currency: 'USD'` as a placeholder in cash docs is a per-user isolation violation at the data layer — IB and T212 accounts may hold non-USD. A placeholder should either omit the field or write `null`, never a misleading valid value.

### IB date timezone
IB Activity Statement times are in the **account's timezone**, not UTC. Appending `Z` silently produces wrong UTC timestamps. Must be verified against a real IB export. Flag as DV0-4 dependency.

### IB Open Positions discriminator assumption
Synthetic fixtures assume `'Summary'` discriminator for position rows. Real IB statements may differ. Must be verified at V0.20 sign-off.

### IB bad-headers partial-section success
Current implementation allows Open Positions to parse even when Trades has bad headers. Test plan A.5.2 says both sections should be rejected. This is a spec deviation — either the test or the code needs to be updated.

### `portfolio_get_snapshot` id-mapping bug
`{ id: d.data(), ...d.data() }` assigns the data object as the id field. Should be `{ id: d.id, ...d.data() }`. Present across all PRs since it is in the shared `index.ts`.

### xfail commit prefixes
The test-plan owner (Vi) used `feat:` on test-only commits in some PRs. Test-only commits in `apps/**` should use `chore:` per rule 5. Not a violation but a style inconsistency.
