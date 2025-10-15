<#
 RTL8821CU WSL2 Full Setup (Kali-only, AutoSafe v5.0)
 Author: ZNUZHG (Mahmut) + GPT Assistant
 Date: 2025-10-15

 Changes:
   ✅ Works only with Kali Linux (no detection)
   ✅ Always runs as root (no password prompts)
   ✅ Safe Base64 file transfer
   ✅ Auto-detach/attach Realtek USB
   ✅ Opens root Kali terminal automatically
#>

function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Host "⚠️ Please run this script as Administrator." -ForegroundColor Yellow
        exit 1
    }
}

Assert-Admin
chcp 65001 | Out-Null
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " RTL8821CU WSL2 FULL SETUP (Kali-only, AutoSafe v5.0)" -ForegroundColor Green
Write-Host " Directory: $ScriptDir" -ForegroundColor Cyan
Write-Host "============================================================`n"

# Ask confirmation
Write-Host "[*] This setup is for Kali Linux WSL only."
Write-Host "If you have not installed Kali yet, run manually:"
Write-Host "   wsl --install -d kali-linux`n"
$answer = Read-Host "Have you already installed Kali Linux? (Y/N)"
if ($answer.ToLower() -ne "y") {
    Write-Host "❌ Please install Kali first, then rerun this script."
    exit 1
}
Write-Host "[+] Continuing with Kali Linux setup..." -ForegroundColor Green

# --- Step 1: Windows prerequisites ---
$prereqPath = Join-Path $ScriptDir "windows_prereq.ps1"
if (-not (Test-Path $prereqPath)) {
    Write-Host "❌ Missing file: windows_prereq.ps1" -ForegroundColor Red
    exit 1
}
Write-Host "`n[*] Running windows_prereq.ps1 (this may restart WSL)..."
& powershell -ExecutionPolicy Bypass -File $prereqPath

# --- Step 2: Start Kali as root ---
Write-Host "`n[*] Starting Kali Linux as root (no password prompt)..."
try {
    wsl -d kali-linux --user root -- bash -c "echo Kali root OK"
    Write-Host "[+] Kali is reachable as root." -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to start Kali. Check WSL installation." -ForegroundColor Red
    exit 1
}

# --- Step 3: Copy files into Kali safely ---
$targetPath = "/root/rtl8821cu_wsl_fix"
Write-Host "`n[*] Creating target directory inside Kali: $targetPath"
wsl -d kali-linux --user root -- bash -c "mkdir -p '$targetPath'"

$files = @("rtl8821cu_wsl_fix.sh","ai_helper.py")
foreach ($f in $files) {
    $src = Join-Path $ScriptDir $f
    if (-not (Test-Path $src)) {
        Write-Host "❌ Missing file: $f" -ForegroundColor Red
        exit 1
    }
    Write-Host "[*] Encoding & copying $f -> $targetPath/$f"
    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content -Raw -Encoding UTF8 $src)))
    wsl -d kali-linux --user root -- bash -c "echo '$b64' | base64 -d > '$targetPath/$f'"
    if ($f -like "*.sh") {
        wsl -d kali-linux --user root -- bash -c "chmod +x '$targetPath/$f'"
    }
}
Write-Host "[+] Files copied successfully to $targetPath" -ForegroundColor Green

# --- Step 4: Run fix script ---
Write-Host "`n[*] Running rtl8821cu_wsl_fix.sh inside Kali as root..."
wsl -d kali-linux --user root -- bash -lc "cd '$targetPath' && bash ./rtl8821cu_wsl_fix.sh"

# --- Step 5: Auto-manage Realtek USB ---
Write-Host "`n[*] Scanning for Realtek USB device via usbipd..."
$usbList = & usbipd list
$realtek = $usbList | Where-Object { $_ -match "0bda:c811|0bda:c820|Realtek" }

if (-not $realtek) {
    Write-Host "⚠️ No Realtek device detected. Plug it in and rerun attach step." -ForegroundColor Yellow
} else {
    $busid = ($realtek -split '\s+')[0]
    Write-Host "[+] Realtek device found: $busid" -ForegroundColor Green

    # auto detach first if already attached
    Write-Host "[*] Detaching any existing WSL attachment..."
    usbipd detach --busid $busid 2>$null | Out-Null
    Start-Sleep -Seconds 1

    Write-Host "[*] Attaching Realtek to Kali..."
    usbipd attach --busid $busid --wsl | Out-Null
    Write-Host "[+] Realtek adapter attached successfully to Kali." -ForegroundColor Green
}

# --- Step 6: Open Kali terminal automatically ---
Write-Host "`n[*] Opening a persistent Kali root terminal for verification..."
Start-Process "wsl.exe" -ArgumentList "-d kali-linux --user root -- bash"

Write-Host "`n✅ Setup completed successfully for Kali Linux!" -ForegroundColor Green
Write-Host "📡 To verify inside Kali (in the opened terminal):"
Write-Host "   lsusb && dmesg | tail -n 20"
Write-Host "   iwconfig || ip a"
Write-Host "`n============================================================" -ForegroundColor Cyan
