###############################################################
# variables.tf — Input variables for dynamic inventory generation
###############################################################

variable "ubuntu_host_ip" {
  description = "IP address of the Ubuntu managed node"
  type        = string
  default     = "192.168.56.101"

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.ubuntu_host_ip))
    error_message = "Must be a valid IPv4 address."
  }
}

variable "windows_host_ip" {
  description = "IP address of the Windows 11 managed node"
  type        = string
  default     = "192.168.56.102"

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", var.windows_host_ip))
    error_message = "Must be a valid IPv4 address."
  }
}

variable "ansible_user_linux" {
  description = "SSH user for Linux managed nodes"
  type        = string
  default     = "ansible"
}

variable "ansible_user_windows" {
  description = "WinRM user for Windows managed nodes"
  type        = string
  default     = "ansible"
}

variable "ssh_private_key_path" {
  description = "Absolute path to the SSH private key for Linux nodes"
  type        = string
  default     = "~/.ssh/ansible_key"
}

variable "winrm_password" {
  description = "Password for WinRM connection to Windows node"
  type        = string
  sensitive   = true
  default     = "AnsiblePass123!"
}

variable "timezone_first" {
  description = "First timezone to apply (IANA format)"
  type        = string
  default     = "Europe/Paris"
}

variable "timezone_second" {
  description = "Second timezone to apply (IANA format)"
  type        = string
  default     = "Africa/Abidjan"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name (used in generated file headers)"
  type        = string
  default     = "devops-m1-dev1-2026"
}
