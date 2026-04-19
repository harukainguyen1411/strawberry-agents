# 2026-04-19 — T212 API Fixtures and Key Encryption

## What I learned

### T212 API auth
- T212 uses HTTP Basic auth, NOT a single Bearer token
- The `.env` file contains two vars: `API_KEY_ID` (username) and `SECRET_KEY` (password)
- Combine as `printf '%s:%s' "$API_KEY_ID" "$SECRET_KEY" | base64` and send as `Authorization: Basic <b64>`
- Live base URL: `https://live.trading212.com`

### T212 API response shapes
- `/api/v0/equity/account/cash` → single object with `free`, `total`, `ppl`, `result`, `invested`, `pieCash`, `blocked` (all numbers)
- `/api/v0/equity/portfolio` → array of positions, keys: `ticker`, `quantity`, `averagePrice`, `currentPrice`, `ppl`, `fxPpl`, `initialFillDate`, `frontend`, `maxBuy`, `maxSell`, `pieQuantity`
- `/api/v0/equity/history/orders?limit=50` → `{ items: [...], nextPagePath: "..." }`; each item has `order` and `fill` sub-objects. CANCELLED limit orders have no `fill` key.

### Fields to anonymize
- `order.id` — numeric, account-linked
- `fill.id` — numeric, account-linked
- `nextPagePath` cursor — contains account-linked pagination state
- Cash and portfolio responses have no account IDs

### Encryption workflow for strawberry-app
- Use `age -r <PUBKEY> -o secrets/env/X.env.age secrets/env/X.env` directly (not decrypt.sh, which is tied to strawberry-agents repo)
- Public key extracted via `age-keygen -y secrets/age-key.txt` from strawberry-agents
- Round-trip verify via sha256 in child process — never read plaintext into context
- `secrets/env/*.age` files are explicitly unignored in strawberry-app .gitignore (committed)

### Branch protection reminder
- strawberry-app main has 2-approval gate + 5 required CI checks
- Direct push to main is blocked — always use a PR branch via `git worktree`
