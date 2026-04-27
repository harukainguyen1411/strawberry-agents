# canonical-v1 bypass log

Companion to [`canonical-v1.md`](./canonical-v1.md). Each row records one in-flight `Lock-Bypass:`-trailered commit that touched a path in the lock set without disabling the lock entirely.

For session-scale churn use the manual disable mechanism documented in `canonical-v1.md` §"Manual disable mechanism" — entries here should stay short and surgical.

## Schema

```
| date       | sha       | author          | severity | reason                                          | reconciled-by                        |
```

- `date` — ISO date (YYYY-MM-DD) of the commit author-date.
- `sha` — full commit SHA from the `Lock-Bypass:`-trailered commit.
- `author` — git committer (resolved identity, not raw email).
- `severity` — one of `low` / `medium` / `high`. The Saturday retro ADR uses this to decide whether the bypass triggers a same-week amendment or a v(N+1) advance.
- `reason` — the verbatim text following `Lock-Bypass:` in the commit trailer.
- `reconciled-by` — once the next Saturday retro's output ADR cites this SHA, fill in the ADR's filename (e.g. `2026-05-02-canonical-v2-rationale.md`). Empty string while pending.

## Entries

| date | sha | author | severity | reason | reconciled-by |
|------|-----|--------|----------|--------|---------------|

*(no entries yet — log opens at lock-tag time `canonical-v1`.)*
