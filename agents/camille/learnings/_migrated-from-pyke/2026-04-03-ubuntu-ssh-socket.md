# Ubuntu 24.04 SSH Socket Activation

Ubuntu 24.04 uses `ssh.service` (not `sshd.service`) and relies on **socket activation** via `ssh.socket`.

- `systemctl restart sshd` → fails with "Unit sshd.service not found"
- Correct: `systemctl restart ssh`
- Must also ensure `ssh.socket` is enabled: `systemctl enable ssh.socket`
- The service may show "disabled" in systemctl status — that's normal with socket activation, the socket triggers the service on demand

## Impact
Scripts targeting Ubuntu that use `sshd` will fail silently if `set -e` isn't catching it, potentially leaving SSH unreachable after config changes.
