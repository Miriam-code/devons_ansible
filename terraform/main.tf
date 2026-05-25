###############################################################
# main.tf — Terraform Infrastructure as Code
# Generates Ansible inventory dynamically via Jinja2 template
###############################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2"
    }
  }
}

###############################################################
# LOCAL VALUES — Centralised host definitions
###############################################################
locals {
  # Ubuntu (Linux) host configuration
  ubuntu_host = {
    name                 = "ubuntu-node"
    ip                   = var.ubuntu_host_ip
    ansible_user         = var.ansible_user_linux
    ansible_port         = 22
    ansible_connection   = "ssh"
    ssh_private_key_file = var.ssh_private_key_path
    python_interpreter   = "/usr/bin/python3"
    group                = "linux_hosts"
    os_family            = "Debian"
    description          = "Ubuntu 22.04 LTS managed node"
  }

  # Windows 11 host configuration
  windows_host = {
    name                = "windows-node"
    ip                  = var.windows_host_ip
    ansible_user        = var.ansible_user_windows
    ansible_port        = 5985
    ansible_connection  = "winrm"
    winrm_scheme        = "http"
    winrm_transport     = "ntlm"
    winrm_password      = var.winrm_password
    group               = "windows_hosts"
    os_family           = "Windows"
    description         = "Windows 11 managed node via WinRM"
  }

  # Timezone mapping: IANA → Windows TimeZone IDs
  timezone_map = {
    "Europe/Paris"    = "Romance Standard Time"
    "Africa/Abidjan"  = "Greenwich Standard Time"
    "UTC"             = "UTC"
    "America/New_York" = "Eastern Standard Time"
    "Asia/Tokyo"      = "Tokyo Standard Time"
  }

  # Resolve Windows timezone IDs
  tz_first_windows  = lookup(local.timezone_map, var.timezone_first, "Romance Standard Time")
  tz_second_windows = lookup(local.timezone_map, var.timezone_second, "Greenwich Standard Time")
}

###############################################################
# RESOURCE — Generate hosts.ini inventory from Jinja2 template
###############################################################
data "template_file" "ansible_inventory" {
  template = file("${path.module}/templates/inventory.ini.tpl")

  vars = {
    # Linux host vars
    ubuntu_name              = local.ubuntu_host.name
    ubuntu_ip                = local.ubuntu_host.ip
    ubuntu_user              = local.ubuntu_host.ansible_user
    ubuntu_port              = local.ubuntu_host.ansible_port
    ubuntu_ssh_key           = local.ubuntu_host.ssh_private_key_file
    ubuntu_python            = local.ubuntu_host.python_interpreter

    # Windows host vars
    windows_name             = local.windows_host.name
    windows_ip               = local.windows_host.ip
    windows_user             = local.windows_host.ansible_user
    windows_port             = local.windows_host.ansible_port
    windows_winrm_scheme     = local.windows_host.winrm_scheme
    windows_winrm_transport  = local.windows_host.winrm_transport
    windows_password         = local.windows_host.winrm_password
  }
}

resource "local_file" "ansible_inventory" {
  content         = data.template_file.ansible_inventory.rendered
  filename        = "${path.module}/../inventory/hosts.ini"
  file_permission = "0644"
}

###############################################################
# RESOURCE — Generate group_vars/all.yml dynamically
###############################################################
data "template_file" "group_vars_all" {
  template = file("${path.module}/templates/group_vars_all.yml.tpl")

  vars = {
    timezone_first          = var.timezone_first
    timezone_second         = var.timezone_second
    tz_first_windows        = local.tz_first_windows
    tz_second_windows       = local.tz_second_windows
    ansible_user_linux      = var.ansible_user_linux
    ansible_user_windows    = var.ansible_user_windows
    environment             = var.environment
    project_name            = var.project_name
  }
}

resource "local_file" "group_vars_all" {
  content         = data.template_file.group_vars_all.rendered
  filename        = "${path.module}/../ansible/group_vars/all.yml"
  file_permission = "0644"
}

###############################################################
# RESOURCE — Generate group_vars/windows_hosts.yml
###############################################################
data "template_file" "group_vars_windows" {
  template = file("${path.module}/templates/group_vars_windows.yml.tpl")

  vars = {
    winrm_password      = var.winrm_password
    windows_user        = var.ansible_user_windows
    winrm_transport     = local.windows_host.winrm_transport
    winrm_scheme        = local.windows_host.winrm_scheme
  }
}

resource "local_file" "group_vars_windows" {
  content         = data.template_file.group_vars_windows.rendered
  filename        = "${path.module}/../ansible/group_vars/windows_hosts.yml"
  file_permission = "0600"
}

###############################################################
# OUTPUTS
###############################################################
output "inventory_path" {
  description = "Path to the generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}

output "ubuntu_ip" {
  description = "Ubuntu host IP address"
  value       = var.ubuntu_host_ip
}

output "windows_ip" {
  description = "Windows host IP address"
  value       = var.windows_host_ip
}

output "infrastructure_summary" {
  description = "Summary of managed infrastructure"
  value = {
    ubuntu_node = {
      ip         = local.ubuntu_host.ip
      user       = local.ubuntu_host.ansible_user
      connection = local.ubuntu_host.ansible_connection
      os         = local.ubuntu_host.os_family
    }
    windows_node = {
      ip         = local.windows_host.ip
      user       = local.windows_host.ansible_user
      connection = local.windows_host.ansible_connection
      os         = local.windows_host.os_family
    }
    timezones = {
      first  = var.timezone_first
      second = var.timezone_second
    }
  }
}
