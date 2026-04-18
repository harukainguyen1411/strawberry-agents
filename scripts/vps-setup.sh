#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Strawberry VPS Setup — Self-Hosted GitHub Actions Runner
# Run as root on a fresh Ubuntu 24.04 server (Hetzner CX22)
# ============================================================

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: Run this script as root."
  exit 1
fi

echo "============================================"
echo "  Strawberry VPS Setup"
echo "============================================"
echo ""

# --- Collect inputs upfront ---
read -rp "GitHub repo (e.g. Duongntd/strawberry): " GITHUB_REPO
read -rp "Runner registration token (from GitHub Settings → Actions → Runners → New): " RUNNER_TOKEN
read -rp "Runner name [strawberry-runner]: " RUNNER_NAME
RUNNER_NAME="${RUNNER_NAME:-strawberry-runner}"
read -rp "Runner labels [self-hosted,linux,x64]: " RUNNER_LABELS
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,linux,x64}"

echo ""
echo "Starting unattended setup..."
echo ""

# --- 1. System update ---
echo ">>> Updating system packages..."
apt update && apt upgrade -y

# --- 2. Create runner user (no password, limited sudo) ---
echo ">>> Creating runner user..."
if ! id runner &>/dev/null; then
  adduser runner --disabled-password --gecos ""
fi

# Scoped sudo: only systemctl for the runner service
cat > /etc/sudoers.d/runner <<'SUDOERS'
runner ALL=(root) NOPASSWD: /usr/bin/systemctl start actions.runner.*, /usr/bin/systemctl stop actions.runner.*, /usr/bin/systemctl restart actions.runner.*, /usr/bin/systemctl status actions.runner.*
SUDOERS
chmod 440 /etc/sudoers.d/runner

# Copy root's SSH keys to runner user
mkdir -p /home/runner/.ssh
cp /root/.ssh/authorized_keys /home/runner/.ssh/
chown -R runner:runner /home/runner/.ssh
chmod 700 /home/runner/.ssh
chmod 600 /home/runner/.ssh/authorized_keys

# --- 3. SSH hardening ---
echo ">>> Hardening SSH..."
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh

# --- 4. Firewall ---
echo ">>> Configuring UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

# --- 5. Fail2ban ---
echo ">>> Installing fail2ban..."
apt install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban

# --- 6. Automatic security updates ---
echo ">>> Enabling unattended upgrades..."
apt install -y unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot "false";' > /etc/apt/apt.conf.d/51auto-reboot
dpkg-reconfigure -f noninteractive unattended-upgrades

# --- 7. Install Node.js 20 ---
echo ">>> Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# --- 8. Install Git ---
echo ">>> Installing git..."
apt install -y git

# --- 9. Install GitHub CLI ---
echo ">>> Installing GitHub CLI..."
(type -p wget >/dev/null || apt install -y wget)
mkdir -p -m 755 /etc/apt/keyrings
wget -nv -O /tmp/githubcli-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg
cp /tmp/githubcli-keyring.gpg /etc/apt/keyrings/githubcli-archive-keyring.gpg
chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
apt update
apt install -y gh

# --- 10. Install Firebase CLI ---
echo ">>> Installing Firebase CLI..."
npm install -g firebase-tools

# --- 11. Install Claude Code CLI ---
echo ">>> Installing Claude Code CLI..."
npm install -g @anthropic-ai/claude-code

# --- 12. Install GitHub Actions Runner ---
echo ">>> Installing GitHub Actions runner..."
RUNNER_DIR="/home/runner/actions-runner"
mkdir -p "$RUNNER_DIR"

RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep -oP '"tag_name": "v\K[^"]+')
curl -o "$RUNNER_DIR/actions-runner.tar.gz" -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
tar xzf "$RUNNER_DIR/actions-runner.tar.gz" -C "$RUNNER_DIR"
rm "$RUNNER_DIR/actions-runner.tar.gz"
chown -R runner:runner "$RUNNER_DIR"

# Install runner dependencies
"$RUNNER_DIR/bin/installdependencies.sh"

# Configure runner as the runner user
echo ">>> Registering runner with GitHub..."
su - runner -c "cd $RUNNER_DIR && ./config.sh --url https://github.com/${GITHUB_REPO} --token ${RUNNER_TOKEN} --name ${RUNNER_NAME} --labels ${RUNNER_LABELS} --work _work --unattended"

# --- 13. Systemd service ---
echo ">>> Setting up systemd service..."
cd "$RUNNER_DIR"
./svc.sh install runner
./svc.sh start

# --- 14. Configure git for runner user ---
echo ">>> Configuring git for runner user..."
su - runner -c 'git config --global user.name "strawberry-runner"'
su - runner -c 'git config --global user.email "runner@strawberry.local"'

# --- 15. Verification ---
echo ""
echo "============================================"
echo "  Verification"
echo "============================================"
echo ""
echo "Node.js:       $(node --version)"
echo "npm:           $(npm --version)"
echo "Firebase CLI:  $(firebase --version 2>/dev/null || echo 'installed')"
echo "Claude Code:   $(claude --version 2>/dev/null || echo 'installed')"
echo "gh CLI:        $(gh --version | head -1)"
echo "Git:           $(git --version)"
echo "UFW:           $(ufw status | head -1)"
echo "Fail2ban:      $(systemctl is-active fail2ban)"
echo "Runner:        $(./svc.sh status 2>&1 | grep -o 'active (running)' || echo 'check manually')"
echo ""
echo "============================================"
echo "  MANUAL STEPS REQUIRED"
echo "============================================"
echo ""
echo "SSH into the server as the runner user and complete these two steps:"
echo ""
echo "  ssh -i ~/.ssh/strawberry runner@<SERVER_IP>"
echo ""
echo "  1. Authenticate Claude Code:"
echo "     claude login"
echo ""
echo "  2. Authenticate Firebase:"
echo "     firebase login --no-localhost"
echo ""
echo "  3. Authenticate GitHub CLI:"
echo "     gh auth login"
echo ""
echo "These require interactive browser flows and cannot be automated."
echo ""
echo "Setup complete."
