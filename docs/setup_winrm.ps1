# =============================================================
# setup_winrm.ps1 — Configure WinRM on Windows 11 VM
# Run this script ONCE as Administrator on the Windows VM
# =============================================================

Write-Host "=== Setting up WinRM for Ansible ==="  -ForegroundColor Cyan

# 1. Enable WinRM service
Write-Host "[1/7] Enabling WinRM service..." -ForegroundColor Yellow
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# 2. Set WinRM service to auto-start
Write-Host "[2/7] Setting WinRM to auto-start..." -ForegroundColor Yellow
Set-Service -Name WinRM -StartupType Automatic
Start-Service WinRM

# 3. Configure WinRM listener on HTTP (port 5985)
Write-Host "[3/7] Configuring WinRM HTTP listener (port 5985)..." -ForegroundColor Yellow
$listenerExists = Get-WSManInstance -ResourceURI winrm/config/listener `
  -SelectorSet @{Address="*"; Transport="HTTP"} -ErrorAction SilentlyContinue

if (-not $listenerExists) {
    winrm create winrm/config/listener?Address=*+Transport=HTTP
}

# 4. Allow Basic and NTLM authentication
Write-Host "[4/7] Enabling authentication methods..." -ForegroundColor Yellow
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item -Path WSMan:\localhost\Service\Auth\Ntlm  -Value $true
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true

# 5. Set max memory per shell (Ansible needs this)
Write-Host "[5/7] Setting WinRM memory limits..." -ForegroundColor Yellow
Set-Item -Path WSMan:\localhost\Shell\MaxMemoryPerShellMB -Value 1024

# 6. Configure Windows Firewall rule for WinRM
Write-Host "[6/7] Adding firewall rule for WinRM (port 5985)..." -ForegroundColor Yellow
$fwRule = Get-NetFirewallRule -DisplayName "WinRM HTTP" -ErrorAction SilentlyContinue
if (-not $fwRule) {
    New-NetFirewallRule `
        -DisplayName "WinRM HTTP" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 5985 `
        -Action Allow `
        -Profile Any
    Write-Host "  Firewall rule created." -ForegroundColor Green
} else {
    Write-Host "  Firewall rule already exists." -ForegroundColor Green
}

# 7. Create Ansible local user if it doesn't exist
Write-Host "[7/7] Creating 'ansible' local user..." -ForegroundColor Yellow
$username = "ansible"
$password  = ConvertTo-SecureString "AnsiblePass123!" -AsPlainText -Force

$userExists = Get-LocalUser -Name $username -ErrorAction SilentlyContinue
if (-not $userExists) {
    New-LocalUser -Name $username -Password $password `
        -FullName "Ansible Automation User" `
        -Description "Account used by Ansible for remote management" `
        -PasswordNeverExpires $true
    Add-LocalGroupMember -Group "Administrators" -Member $username
    Write-Host "  User '$username' created and added to Administrators." -ForegroundColor Green
} else {
    Write-Host "  User '$username' already exists." -ForegroundColor Green
    # Update password anyway
    Set-LocalUser -Name $username -Password $password
}

# ── Verification ──────────────────────────────────────────────
Write-Host ""
Write-Host "=== WinRM Configuration Summary ===" -ForegroundColor Cyan
winrm enumerate winrm/config/listener
Write-Host ""
Write-Host "Service status:" -ForegroundColor Yellow
Get-Service WinRM | Select-Object Name, Status, StartType
Write-Host ""
Write-Host "Firewall rule:" -ForegroundColor Yellow
Get-NetFirewallRule -DisplayName "WinRM HTTP" | Select-Object DisplayName, Enabled, Direction

Write-Host ""
Write-Host "=== WinRM setup complete! ===" -ForegroundColor Green
Write-Host "Test from Ansible controller with:"
Write-Host "  ansible windows_hosts -m ansible.windows.win_ping -i inventory/hosts.ini"
