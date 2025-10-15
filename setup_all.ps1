<#
 RTL8821CU WSL2 Full Setup (Multi-Distro AutoSafe v6.1)
 Author: ZNUZHG (Mahmut) + GPT Assistant
 Date: 2025-10-15 (updated)

 Notes:
  - Detects installed WSL distros and picks preferred one (kali-linux, ubuntu, debian, parrot, arch)
  - Copies rtl8821cu_wsl_fix.sh and ai_helper.py into distro as root using base64
  - Runs the inner script as root: wsl -d <distro> --user root -- bash -lc ...
  - Attaches Realtek USB via usbipd (user must keep a distro shell open for persistent attach)
  - If you want fully non-interactive heavy actions (like building kernel modules), set environment variable:
        $env:AUTO_YES = "1"
#>

function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Host "Please run this script as Administrator." -ForegroundColor Yellow
        exit 1
    }
}

Assert-Admin
chcp 65001 | Out-Null
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " RTL8821CU WSL2 FULL SETUP (Multi-Distro AutoSafe v6.1)" -ForegroundColor Green
Write-Host " Directory: $ScriptDir" -ForegroundColor Cyan
Write-Host "============================================================`n"

# detect installed WSL distros (quiet list)
try {
    $distros = wsl --list --quiet 2>&1
} catch {
    Write-Host "Error calling wsl.exe. Is WSL installed and available?" -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($distros)) {
    Write-Host "No WSL distributions found. Install Kali/Ubuntu/Debian or other distro first." -ForegroundColor Red
    exit 1
}

$distros = $distros -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
Write-Host "[*] Installed WSL distributions:"
$distros | ForEach-Object { Write-Host "   - $_" }

# preferred order
$preferredList = @("kali-linux","ubuntu","debian","parrot","arch")
$selected = $null
foreach ($p in $preferredList) {
    $found = $distros | Where-Object { $_ -match [regex]::Escape($p) }
    if ($found) { $selected = $found[0]; break }
}

if (-not $selected) {
    # ask user to pick
    Write-Host "`nNo preferred distro auto-detected. Choose from the list below:"
    for ($i=0; $i -lt $distros.Count; $i++) {
        Write-Host " [$($i+1)] $($distros[$i])"
    }
    $sel = Read-Host "Choose distribution (1..$($distros.Count)) [1]"
    if ([string]::IsNullOrWhiteSpace($sel)) { $sel = "1" }
    if (-not ($sel -as [int]) -or [int]$sel -lt 1 -or [int]$sel -gt $distros.Count) {
        Write-Host "Invalid selection." -ForegroundColor Red
        exit 1
    }
    $selected = $distros[[int]$sel - 1]
}

Write-Host "`n[+] Selected distribution: $selected" -ForegroundColor Green

# prereq file check
$prereqPath = Join-Path $ScriptDir "windows_prereq.ps1"
if (-not (Test-Path $prereqPath)) {
    Write-Host "Missing windows_prereq.ps1 in script directory: $ScriptDir" -ForegroundColor Red
    exit 1
}

Write-Host "`n[*] Running windows_prereq.ps1 (this may install usbipd-win and restart WSL)..."
& powershell -ExecutionPolicy Bypass -File $prereqPath

# ensure distro reachable as root
Write-Host "`n[*] Ensuring $selected is reachable as root..."
try {
    wsl -d $selected --user root -- bash -c "echo distro-root-ok" > $null 2>&1
    Write-Host "[+] $selected reachable as root." -ForegroundColor Green
} catch {
    Write-Host "Failed to reach $selected as root. Try running `wsl -d $selected` and configure root user or set up sudo access." -ForegroundColor Yellow
    $ans = Read-Host "Continue anyway? (y/N)"
    if ($ans.ToLower() -ne "y") { exit 1 }
}

# copy files via base64 to avoid encoding issues
$targetPath = "/root/rtl8821cu_wsl_fix"
Write-Host "`n[*] Creating target directory inside $selected: $targetPath"
wsl -d $selected --user root -- bash -c "mkdir -p '$targetPath'"

$files = @("rtl8821cu_wsl_fix.sh","ai_helper.py")
foreach ($f in $files) {
    $src = Join-Path $ScriptDir $f
    if (-not (Test-Path $src)) {
        Write-Host "Missing file: $f" -ForegroundColor Red
        exit 1
    }
    Write-Host "[*] Encoding & copying $f -> $targetPath/$f"
    $content = Get-Content -Raw -Encoding UTF8 $src
    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($content))
    # send base64 string; base64 does not include single-quote so safe to embed in single quotes
    wsl -d $selected --user root -- bash -c "echo '$b64' | base64 -d > '$targetPath/$f'"
    if ($f -like "*.sh") {
        wsl -d $selected --user root -- bash -c "chmod +x '$targetPath/$f'"
    }
}

Write-Host "[+] Files copied successfully to $targetPath" -ForegroundColor Green

# run inner script (allow AUTO_YES if set)
$autoFlag = ""
if ($env:AUTO_YES -eq "1" -or $env:AUTO_YES -eq "true") { $autoFlag = "--auto-yes" }

Write-Host "`n[*] Running rtl8821cu_wsl_fix.sh inside $selected as root..."
wsl -d $selected --user root -- bash -lc "cd '$targetPath' && bash ./rtl8821cu_wsl_fix.sh $autoFlag"

# usbipd attach
Write-Host "`n[*] Scanning for Realtek USB device via usbipd..."
$usbList = & usbipd list 2>&1
$realtek = $usbList | Where-Object { $_ -match "0bda:c811|0bda:c820|Realtek" }

if (-not $realtek) {
    Write-Host "No Realtek device detected. Plug it in and run `usbipd.exe list` to get BUSID." -ForegroundColor Yellow
} else {
    $busid = ($realtek -split '\s+')[0]
    Write-Host "[+] Realtek device found: $busid" -ForegroundColor Green
    Write-Host "[*] Detaching any existing WSL attachment (best effort)..."
    usbipd detach --busid $busid 2>$null | Out-Null
    Start-Sleep -Seconds 1
    Write-Host "[*] Attaching Realtek to $selected..."
    usbipd attach --busid $busid --wsl | Out-Null
    Write-Host "[+] Realtek adapter attached successfully (or attach attempted)." -ForegroundColor Green
    Write-Host "Note: Keep a shell open in the distro to keep the device available."
}

# open persistent root terminal
Write-Host "`n[*] Opening a persistent root terminal for verification..."
Start-Process "wsl.exe" -ArgumentList "-d $selected --user root -- bash"

Write-Host "`n✅ Setup finished for $selected." -ForegroundColor Green
Write-Host "To verify inside distro (in the opened terminal):"
Write-Host "   lsusb && dmesg | tail -n 20"
Write-Host "   iwconfig || ip a"
Write-Host "`n============================================================" -ForegroundColor Cyan
