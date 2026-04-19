# 2026-04-19 — tdd-gate merge-base range (PR #55)

## Verdict
CHANGES_REQUESTED on `harukainguyen1411/strawberry-app#55`.

## Finding (critical)
`git fetch origin main --depth=0` is an invalid flag — git errors out with
`fatal: depth 0 is not a positive number`. Only worked in practice because
the script has no `set -e` and `actions/checkout` with `fetch-depth: 0`
already populated `origin/main`. The fetch line is a silently-failing no-op
and misleads future readers.

Recommended fix: drop the fetch (checkout already provides full history),
or use `git fetch origin main --no-tags`.

## Reusable lesson
When reviewing GitHub Actions bash steps, always:
1. Check whether `set -e` is active — if not, command failures are swallowed
   and "it works" may mean "it silently no-ops".
2. Verify every git flag against `git help <cmd>` — `--depth=0` is a
   common mistaken substitute for `--unshallow`.
3. Confirm whether the checkout step's `fetch-depth` already provides the
   refs the script tries to fetch, to spot redundant or broken fetches.

## Security
Branch hardcoded to `main`; inputs come from GitHub context or git output.
No injection surface.
