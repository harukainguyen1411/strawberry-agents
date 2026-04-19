# 2026-04-19 — V0.7 IB CSV parser: short/cover + Asset Category fixes

## Context
PR #41 on harukainguyen1411/strawberry-app — Senna REQUEST_CHANGES on the IB CSV parser.

## Bug 1: Short/cover misclassification
IB's Code column contains semicolon-delimited action flags (O=open, C=close), not a trade ID.
The original code used Code as the trade ID and never read the flags.
Fix: split Code on `;`, extract `O`/`C`, store as `rawPayload.openClose`.
Side determination (qty sign) is already correct — the only missing piece was the open/close
indicator for v0.8 position-math to distinguish a buy-to-cover from a long-open.
Trade ID switched to always use `deterministicId` since Code flags are not stable unique IDs.

## Bug 2: Asset Category not in required headers
REQUIRED_TRADE_HEADERS lacked `Asset Category`, so an IB export without it would silently
parse options/futures rows with stocks semantics (wrong qty sign interpretation for multi-leg).
Fix: added `Asset Category` to required headers; non-`Stocks` rows emit
`unsupported_asset_category` warning and are excluded from trades.

## Xfail pattern
Added `ib.xfail.test.ts` with four `it.fails()` tests, then flipped 2+2 in separate fix commits.
Fixture `ib-short-cover.csv` has short-open, cover, options rows for future regression coverage.

## Workflow note
Branch `feature/portfolio-v0-V0.7-csv-ib` was checked out via `bash scripts/safe-checkout.sh`
run from the `strawberry-app` directory. The local branch had diverged from origin — used
`git merge origin/...` (no rebase per Rule 11) before starting work.
