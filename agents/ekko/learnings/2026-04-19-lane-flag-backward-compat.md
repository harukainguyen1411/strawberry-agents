# Lane flag — backward-compatible flag injection before positional args

## Context
Phase 3 of reviewer-identity-split required adding `--lane <name>` to
`scripts/reviewer-auth.sh` without breaking existing callers.

## Pattern
Parse the optional flag at the very top of the script, before any other
positional argument handling. Use a `case` guard around `$# -ge 2 && $1 == "--lane"`:

```bash
LANE="lucian"
if [[ $# -ge 2 && "$1" == "--lane" ]]; then
    LANE="$2"
    shift 2
fi
```

This ensures all downstream logic sees the already-stripped positional args,
and callers that pass no `--lane` get the default silently.

## Key details
- Default the lane to the existing identity so all existing callers are zero-change.
- Use a `case` block to derive per-lane variables (AGE_FILE, ENV_TARGET) after parsing.
- Fail fast with a clear "unknown lane" message (exit 2) for unexpected values.
- Each lane needs its own `--target` file for `tools/decrypt.sh` to avoid cross-lane clobber.

## Applied to
`scripts/reviewer-auth.sh` — commit 306fed2.
