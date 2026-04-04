# gitleaks False Positives

The generic-api-key rule in gitleaks triggers on high-entropy strings that look like keys but aren't — including repo names like `Duongntd/strawberry` (the slash + mixed case reads as high entropy).

## Patterns that trigger false positives
- `Duongntd/strawberry` in shell scripts and plan files
- Any `username/repo` reference in scripts or docs

## Fix
Add to `.gitleaks.toml` allowlist:
```toml
[allowlist]
paths = [
    '''plans/.*''',
    '''scripts/setup-.*\.sh''',
]
```

Or add a commit-level fingerprint allowlist for specific findings.

## Note
Don't add all scripts/ to the allowlist — that would defeat the purpose. Only allowlist specific files that are known to contain false positives. When in doubt, investigate before allowlisting.
