#!/bin/bash
# =============================================================
# setup_ubuntu_controller.sh
# Run this script on the Ubuntu VM to configure it as:
#   - Ansible controller
#   - GitHub Actions self-hosted runner host
#   - Terraform execution environment
# =============================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

log "=== Ubuntu Controller Setup ==="

# ── 1. System update ──────────────────────────────────────────
log "[1/7] Updating system packages..."
sudo apt-get update -qq && sudo apt-get upgrade -y -qq
ok "System updated"

# ── 2. Install Python & pip ───────────────────────────────────
log "[2/7] Installing Python3 and pip..."
sudo apt-get install -y python3 python3-pip python3-venv sshpass curl wget git unzip -qq
ok "Python3 installed: $(python3 --version)"

# ── 3. Install Ansible ────────────────────────────────────────
log "[3/7] Installing Ansible..."
sudo apt-get install -y software-properties-common -qq
sudo add-apt-repository --yes --update ppa:ansible/ansible 2>/dev/null || true
sudo apt-get install -y ansible -qq

# Install pywinrm for Windows management
pip3 install pywinrm requests-credssp --quiet

# Install required Ansible collections
ansible-galaxy collection install ansible.windows community.windows community.general --force
ok "Ansible installed: $(ansible --version | head -1)"

# ── 4. Install Terraform ──────────────────────────────────────
log "[4/7] Installing Terraform..."
TERRAFORM_VERSION="1.7.0"
wget -q "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -O /tmp/terraform.zip
unzip -q /tmp/terraform.zip -d /tmp/
sudo mv /tmp/terraform /usr/local/bin/terraform
sudo chmod +x /usr/local/bin/terraform
rm /tmp/terraform.zip
ok "Terraform installed: $(terraform --version | head -1)"

# ── 5. Generate SSH key for managed nodes ─────────────────────
log "[5/7] Generating SSH key pair for Ansible..."
if [ ! -f "$HOME/.ssh/ansible_key" ]; then
    ssh-keygen -t ed25519 -C "ansible-controller" -f "$HOME/.ssh/ansible_key" -N ""
    ok "SSH key generated: ~/.ssh/ansible_key"
    echo ""
    warn "Copy this public key to the Ubuntu managed node:"
    echo "─────────────────────────────────────────────────"
    cat "$HOME/.ssh/ansible_key.pub"
    echo "─────────────────────────────────────────────────"
    echo ""
    warn "Run on managed node: ssh-copy-id -i ~/.ssh/ansible_key.pub ansible@192.168.56.101"
else
    ok "SSH key already exists: ~/.ssh/ansible_key"
fi

# ── 6. Create ansible system user ────────────────────────────
log "[6/7] Creating 'ansible' user with sudo rights..."
if ! id "ansible" &>/dev/null; then
    sudo useradd -m -s /bin/bash ansible
    echo "ansible ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/ansible > /dev/null
    sudo chmod 0440 /etc/sudoers.d/ansible
    ok "User 'ansible' created"
else
    ok "User 'ansible' already exists"
fi

# ── 7. Install GitHub Actions Runner (instructions) ───────────
log "[7/7] GitHub Actions Runner setup instructions:"
echo ""
echo "  Go to your GitHub repository:"
echo "  Settings → Actions → Runners → New self-hosted runner"
echo ""
echo "  Select: Linux / x64"
echo "  Follow the download and configure steps shown on GitHub"
echo "  When prompted for labels, add: self-hosted,linux,ansible"
echo ""
echo "  To run as a service:"
echo "    sudo ./svc.sh install"
echo "    sudo ./svc.sh start"

echo ""
ok "=== Setup complete! ==="
echo ""
echo "Next steps:"
echo "  1. Copy SSH public key to Ubuntu managed node"
echo "  2. Configure WinRM on Windows 11 VM (run docs/setup_winrm.ps1)"
echo "  3. Register GitHub Actions self-hosted runner"
echo "  4. Update terraform/terraform.tfvars with your VMs' IPs"
echo "  5. Push to main branch to trigger the pipeline"
