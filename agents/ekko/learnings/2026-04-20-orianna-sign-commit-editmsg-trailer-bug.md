# orianna-sign.sh: git --trailer flag and COMMIT_EDITMSG timing

## What happened

The sig-guard pre-commit hook (`scripts/hooks/pre-commit-orianna-signature-guard.sh`) reads
`COMMIT_EDITMSG` to verify that Signed-by/Signed-phase/Signed-hash trailers are present.

`orianna-sign.sh` was using `git commit --trailer "Signed-by: Orianna" ...`, which appends
trailers AFTER the pre-commit hook runs. Git does not write the final message (with trailers)
to `COMMIT_EDITMSG` before the pre-commit hook fires — `COMMIT_EDITMSG` at pre-commit time
holds the PREVIOUS commit's message.

**Fix:** explicitly write `COMMIT_EDITMSG` before invoking `git commit`, and embed trailers
directly in the `-m` message body rather than using `--trailer`. This ensures the hook sees
them.

## Root cause of bad signature commit a79fe52

The original script already had `-c user.email=... -c user.name=...` from its initial commit.
The bad signature was made manually by an agent session (not via the script) — evidenced by
the `Co-Authored-By: Claude Sonnet 4.6` trailer which the script does not add.

## Regression test added

`scripts/test-orianna-lifecycle-smoke.sh` now has CASE 1b: after APPROVED_SIGN, verify
`git log -1 --format='%ae' HEAD` equals `orianna@agents.strawberry.local`. Catches any
regression where the script uses ambient identity.

## Global git hooksPath

This repo uses a global hooksPath (`~/.config/git/hooks/pre-commit`) that runs
`$REPO_ROOT/scripts/hooks/pre-commit-*.sh`. Pre-commit hooks ARE active even though
`.git/hooks/` is empty. Always check `git config --global core.hooksPath` when debugging
unexpected hook behavior.
