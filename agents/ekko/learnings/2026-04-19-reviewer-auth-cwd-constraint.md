# reviewer-auth.sh Must Run from strawberry-agents Dir

Date: 2026-04-19

## Lesson

`scripts/reviewer-auth.sh` internally calls `tools/decrypt.sh` with a target path relative to its
own `scripts/` directory — which resolves to `strawberry-agents/secrets/reviewer-auth.env`.
`decrypt.sh` enforces that the target is under its own repo's `secrets/` directory and refuses
with exit 5 if called from a different cwd (e.g. `strawberry-app`).

## Correct Pattern

```bash
# Run from strawberry-agents working directory:
scripts/reviewer-auth.sh gh pr merge 58 --repo harukainguyen1411/strawberry-app --squash --delete-branch
```

## Wrong Pattern

```bash
cd ~/Documents/Personal/strawberry-app
/path/to/strawberry-agents/scripts/reviewer-auth.sh gh pr merge 58 ...
# Error: decrypt.sh: refusing target outside .../strawberry-agents/secrets: .../strawberry-app/secrets/reviewer-auth.env
```

## Why

`decrypt.sh` uses `realpath` on the `--target` arg and checks it falls under the repo's `secrets/`
prefix. When cwd is `strawberry-app`, the relative `secrets/reviewer-auth.env` resolves to the
wrong tree and is rejected.
