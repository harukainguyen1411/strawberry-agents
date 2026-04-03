# VPS Setup Runbook — Self-Hosted GitHub Actions Runner

Target: Hetzner Cloud CX22, Ubuntu 24.04, Falkenstein or Helsinki DC.

## 1. Create the Server

1. Log in to [Hetzner Cloud Console](https://console.hetzner.cloud)
2. Create project (or use existing) → Add Server
3. Settings:
   - **Location:** Falkenstein (fsn1) or Helsinki (hel1)
   - **Image:** Ubuntu 24.04
   - **Type:** CX22 (2 vCPU shared, 4 GB RAM, 40 GB NVMe)
   - **SSH Key:** Add your public key (do NOT enable password auth)
   - **Name:** `strawberry-runner`
4. Create — note the public IP

## 2. Initial SSH & Security Hardening

```bash
ssh root@<SERVER_IP>

# Update system
apt update && apt upgrade -y

# Create non-root user
adduser runner --disabled-password --gecos ""
usermod -aG sudo runner

# Copy SSH key to new user
mkdir -p /home/runner/.ssh
cp ~/.ssh/authorized_keys /home/runner/.ssh/
chown -R runner:runner /home/runner/.ssh
chmod 700 /home/runner/.ssh
chmod 600 /home/runner/.ssh/authorized_keys

# Disable root login and password auth
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd
```

Open a **new terminal** and verify you can SSH as `runner` before closing the root session.

```bash
ssh runner@<SERVER_IP>
```

### Firewall (UFW)

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw enable
```

### Fail2ban

```bash
sudo apt install fail2ban -y
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

Default config bans IPs after 5 failed SSH attempts for 10 minutes. Sufficient for this use case.

### Automatic Security Updates

```bash
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure -plow unattended-upgrades
```

Select "Yes" to enable automatic updates.

## 3. Install GitHub Actions Runner

```bash
# As runner user
cd /home/runner
mkdir actions-runner && cd actions-runner

# Download latest runner (check https://github.com/actions/runner/releases for current version)
RUNNER_VERSION="2.321.0"
curl -o actions-runner.tar.gz -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
tar xzf actions-runner.tar.gz
rm actions-runner.tar.gz
```

### Register the Runner

Go to GitHub → `Duongntd/strawberry` → Settings → Actions → Runners → New self-hosted runner.

Copy the token, then:

```bash
./config.sh --url https://github.com/Duongntd/strawberry --token <REGISTRATION_TOKEN> --name strawberry-runner --labels self-hosted,linux,x64 --work _work
```

### Systemd Service (auto-start on reboot)

```bash
sudo ./svc.sh install runner
sudo ./svc.sh start
sudo ./svc.sh status
```

This creates a systemd service at `/etc/systemd/system/actions.runner.Duongntd-strawberry.strawberry-runner.service`.

Verify it survives reboot:

```bash
sudo reboot
# After reconnecting:
sudo ./svc.sh status
```

## 4. Install Node.js (for Firebase CLI and builds)

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
node --version
npm --version
```

## 5. Install Firebase CLI

```bash
sudo npm install -g firebase-tools

# Authenticate (interactive — run from SSH with port forwarding or use CI token)
firebase login --no-localhost
```

Follow the URL prompt, paste the authorization code back.

Verify:

```bash
firebase projects:list
```

You should see `myapps-b31ea` in the list.

## 6. Install Claude Code CLI

```bash
# Install via npm
sudo npm install -g @anthropic-ai/claude-code

# Authenticate (interactive — requires browser)
claude login
```

Follow the OAuth flow. This stores the session token locally. Claude Code CLI will use the subscription auth — no API key needed.

Verify:

```bash
claude --version
claude -p "echo hello"
```

## 7. Install Git & Configure

```bash
sudo apt install git -y
git config --global user.name "strawberry-runner"
git config --global user.email "runner@strawberry.local"
```

Set up GitHub authentication for pushing branches and creating PRs:

```bash
# Install GitHub CLI
(type -p wget >/dev/null || sudo apt install wget -y) \
  && sudo mkdir -p -m 755 /etc/apt/keyrings \
  && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && sudo apt update \
  && sudo apt install gh -y

gh auth login
```

## 8. Verification Checklist

```bash
# All of these should succeed:
node --version          # v20.x
firebase --version      # 13.x+
claude --version        # should print version
gh auth status          # logged in
sudo systemctl status actions.runner.Duongntd-strawberry.strawberry-runner.service  # active (running)
sudo ufw status         # active, SSH only
```

## Maintenance

- **Runner updates:** GitHub auto-updates the runner binary. If it fails, re-download from releases.
- **Claude Code re-auth:** If the session expires, SSH in and run `claude login` again.
- **Firebase re-auth:** If token expires, run `firebase login --no-localhost` again.
- **OS updates:** Handled by unattended-upgrades. Reboot monthly if kernel updates accumulate.
