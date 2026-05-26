###############################################################
# terraform.tfvars — Local variable overrides
# Adapt IPs to your VirtualBox Host-Only network
###############################################################

# ── Network (VirtualBox Host-Only: 192.168.56.0/24) ─────────
ubuntu_host_ip       = "192.168.64.10"
windows_host_ip      = "192.168.56.102"

# ── Ansible connection users ─────────────────────────────────
ansible_user_linux   = "ansible"
ansible_user_windows = "ansible"

# ── SSH key (absolute path on the controller VM) ─────────────
ssh_private_key_path = "~/.ssh/ansible_key"

# ── Timezones ────────────────────────────────────────────────
timezone_first  = "Europe/Paris"
timezone_second = "Africa/Abidjan"

# ── Project metadata ─────────────────────────────────────────
environment  = "dev"
project_name = "devops-m1-dev1-2026"

# NOTE: winrm_password is intentionally omitted here.
# Set it via environment variable:
#   export TF_VAR_winrm_password="YourSecurePassword"
# Or pass it in the CI/CD pipeline as a secret.
