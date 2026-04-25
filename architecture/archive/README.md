# architecture/archive — historical record

This subtree holds retired architecture docs and research artifacts. Files here are
**read-only historical record** — never edited except to correct archive-marker metadata.

## §5.1 Retirement-tag convention

A retirement tag is a short noun phrase identifying the retired regime or batch.

- A whole retired regime (multiple related files) gets its own subfolder: `archive/<tag>/`.
  Examples: `v1-orianna-gate/`, `pre-network-v1/`.
- A single retired file with no associated regime gets a date-prefixed top-level name:
  `archive/YYYY-MM-DD-<slug>.md`.

## §5.4 Archive-marker contract

Every archived file must carry a stamp at the top of the file:

```
Archived: superseded by <canonical-path> on <YYYY-MM-DD>
```

Or, for whole-regime archives with no single canonical replacement:

```
Archived: <reason> (<reference-OQ>, <YYYY-MM-DD>); no canonical replacement
```

The canonical doc that replaces an archived one carries a corresponding:

```
Supersedes: archive/<tag>/<file>
```

Both pointers are added in the same commit that performs the archive move.

## Current subdirectories

| Directory | Contents |
|---|---|
| `v1-orianna-gate/` | Pre-existing archive of the v1 Orianna gate regime (plan-lifecycle signing, key-scripts excerpt) |
| `pre-network-v1/` | Retired roster docs and retired protocol descriptions (landing in Wave 3) |
| `billing-research/` | Billing comparison research artifacts (landing in Wave 3) `[placeholder — populated W3]` |
