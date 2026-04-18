---
date: 2026-04-18
topic: decrypt.sh stderr containment
pr: 179
---

# Pattern: tools/decrypt.sh stderr must be explicitly contained by callers

When calling `tools/decrypt.sh`, redirect both stdout and stderr:

```bash
if ! "$decrypt_sh" "$cipher" > /dev/null 2>&1; then
    printf 'ERROR: tools/decrypt.sh failed for %s\n' "$cipher" >&2
    return 1
fi
```

**Why:** `tools/decrypt.sh` is a subprocess that may emit diagnostic output to stderr. If only stdout is discarded (`> /dev/null` without `2>&1`), any key-material diagnostics from the decrypt tool pass through unchecked to the caller's stderr — violating Rule 6's "no plaintext ever logged" principle even though no raw `age -d` is called.

**How to apply:** Any wrapper that calls `tools/decrypt.sh` must suppress its stderr and emit a controlled, safe error message on non-zero exit. The cipher path (filename) in the error message is acceptable; secret content must never appear.
