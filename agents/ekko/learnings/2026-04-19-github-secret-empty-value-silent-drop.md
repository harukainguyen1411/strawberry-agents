# GitHub Actions: empty secret value silently dropped from `with:` echo

**Date:** 2026-04-19
**Context:** Firebase Hosting preview deploy failing with "Input required and not supplied: firebaseServiceAccount" even though `FIREBASE_SERVICE_ACCOUNT` appeared in `gh secret list`.

## Pattern

When a GitHub Actions secret exists by name but its stored value is empty (zero-byte), the runner resolves it to an empty string. GitHub Actions then silently OMITS that input from the `with:` block echo in the step logs — it does not print `firebaseServiceAccount: ` (blank). So the log looks like the input was never passed at all.

Actions that use `core.getInput('inputName', { required: true })` will then throw "Input required and not supplied: inputName" because an empty string is treated as falsy/absent by the Actions toolkit.

## Diagnostic signal

If a `with:` block log is missing an expected input entirely (not masked as `***`, just absent), and the secret name is confirmed present in `gh secret list`, the stored value is almost certainly empty.

## Fix

Delete the secret on the repo and re-add it with the correct non-empty value. No workflow change needed if the secret name reference is correct.

## Applies to

Any required action input sourced from `${{ secrets.X }}` where X was set accidentally as empty during initial secret creation.
