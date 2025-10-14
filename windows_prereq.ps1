# windows_prereq.ps1 - Windows setup for rtl8821cu WSL2 driver
# Author: ZNUZHG ONYVXPV
# Version: 2025-10-14

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " RTL8821CU WSL2 WINDOWS PREREQUISITE INSTALLER" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan

# Admin check
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "⚠️  Please run this PowerShell script as Administrator." -ForegroundColor Yellow
    Exit 1
}

# Enable WSL + Virtual Machine Platform
Write-Host "`n[*] Enabling required Windows features..." -ForegroundColor Yellow
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Check if winget/curl present
$tools = @("winget", "curl")
foreach ($tool in $tools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Host "⚠️  Missing tool: $tool. Please install it manually from Microsoft Store or enable App Installer." -ForegroundColor Red
    } else {
        Write-Host "✔ Found $tool" -ForegroundColor Green
    }
}

# Install usbipd-win if missing
if (-not (Get-Command usbipd.exe -ErrorAction SilentlyContinue)) {
    Write-Host "`n[*] Installing usbipd-win..." -ForegroundColor Yellow
    try {
        winget install --id=usbipd-win.usbipd-win -e --source winget
    } catch {
        Write-Host "⚠️  Automatic install failed. You can manually install it from:" -ForegroundColor Red
        Write-Host "👉  https://learn.microsoft.com/en-us/windows/wsl/connect-usb" -ForegroundColor Cyan
    }
} else {
    Write-Host "✔ usbipd-win already installed." -ForegroundColor Green
}

# Check WSL status
Write-Host "`n[*] Checking WSL version..." -ForegroundColor Yellow
wsl --status

Write-Host "`n✅ Windows prerequisites completed successfully!"
Write-Host "Next steps:"
Write-Host "  1️⃣  Attach your Realtek USB Wi-Fi adapter."
Write-Host "  2️⃣  Run:  usbipd list"
Write-Host "  3️⃣  Run:  usbipd attach --busid <BUSID> --wsl"
Write-Host "  4️⃣  Inside WSL, run: sudo ./rtl8821cu_wsl_fix.sh"
