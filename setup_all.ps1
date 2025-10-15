<#
 RTL8821CU WSL2 Full Setup (AutoDefault v6.3)
 Author: ZNUZHG ONYVXPV
 Date: 2025-10-15

 Notes:
  - Works regardless of system language (Turkish/English)
  - Automatically detects and uses default WSL distro
  - Copies rtl8821cu_wsl_fix.sh and ai_helper.py safely
  - Runs script as root and attaches Realtek USB via usbipd
#>

function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Host "Bu betiği Yönetici olarak çalıştırmalısınız. / Please run this script as Administrator." -ForegroundColor Yellow
        exit 1
    }
}

Assert-Admin
chcp 65001 | Out-Null
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " RTL8821CU WSL2 FULL SETUP (AutoDefault v6.3)" -ForegroundColor Green
Write-Host " Directory: $ScriptDir" -ForegroundColor Cyan
Write-Host "============================================================`n"

# Detect WSL distros
try {
    $distros = wsl --list --quiet 2>&1
} catch {
    Write-Host "❌ WSL çalıştırılamadı. WSL yüklü mü? / WSL could not be executed. Is it installed?" -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($distros)) {
    Write-Host "❌ WSL dağıtımı bulunamadı. Lütfen bir dağıtım (örneğin Ubuntu veya Kali) yükleyin." -ForegroundColor Red
    Write-Host "💡 Install a Linux distribution first using:  wsl --install -d ubuntu"
    exit 1
}

# Detect default distro (language-independent)
$defaultLine = wsl --list --verbose 2>$null | Select-String "\*|Varsayılan" | Select-Object -First 1
if ($defaultLine) {
    $selected = ($defaultLine -split "\s+")[0]
} else {
    # fallback to first distro
    $selected = ($distros -split "`r?`n")[0]
}

Write-Host "[+] Varsayılan dağıtım tespit edildi / Default distro detected: $selected" -ForegroundColor Green

# Check prerequisite
$prereqPath = Join-Path $ScriptDir "windows_prereq.ps1"
if (-not (Test-Path $prereqPath)) {
    Write-Host "❌ Eksik dosya: windows_prereq.ps1 / Missing file: windows_prereq.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "`n[*] windows_prereq.ps1 çalıştırılıyor... / Running windows_prereq.ps1..."
& powershell -ExecutionPolicy Bypass -File $prereqPath

# Ensure root access
Write-Host "`n[*] $selected kök erişimi kontrol ediliyor... / Ensuring root access..."
try {
    wsl -d $selected --user root -- bash -c "echo distro-root-ok" > $null 2>&1
    Write-Host "[+] Root erişimi mevcut / Root access verified." -ForegroundColor Green
} catch {
    Write-Host "⚠️  Root erişimi sağlanamadı. Manuel olarak root kullanıcı oluşturun. / Could not reach root user." -ForegroundColor Yellow
    $ans = Read-Host "Devam edilsin mi? / Continue anyway? (y/N)"
    if ($ans.ToLower() -ne "y") { exit 1 }
}

# Copy files into distro
$targetPath = "/root/rtl8821cu_wsl_fix"
Write-Host "`n[*] $selected içine dizin oluşturuluyor... / Creating directory inside ${selected}: $targetPath"
wsl -d $selected --user root -- bash -c "mkdir -p '$targetPath'"

$files = @("rtl8821cu_wsl_fix.sh","ai_helper.py")
foreach ($f in $files) {
    $src = Join-Path $ScriptDir $f
    if (-not (Test-Path $src)) {
        Write-Host "❌ Eksik dosya: $f / Missing file: $f" -ForegroundColor Red
        exit 1
    }
    Write-Host "[*] $f dosyası aktarılıyor... / Copying $f ..."
    $content = Get-Content -Raw -Encoding UTF8 $src
    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($content))
    wsl -d $selected --user root -- bash -c "echo '$b64' | base64 -d > '$targetPath/$f'"
    if ($f -like "*.sh") {
        wsl -d $selected --user root -- bash -c "chmod +x '$targetPath/$f'"
    }
}

Write-Host "[+] Dosyalar başarıyla kopyalandı. / Files copied successfully." -ForegroundColor Green

# Run fix script
$autoFlag = ""
if ($env:AUTO_YES -eq "1" -or $env:AUTO_YES -eq "true") { $autoFlag = "--auto-yes" }

Write-Host "`n[*] İç script çalıştırılıyor... / Running rtl8821cu_wsl_fix.sh..."
wsl -d $selected --user root -- bash -lc "cd '$targetPath' && bash ./rtl8821cu_wsl_fix.sh $autoFlag"

# USB attach
Write-Host "`n[*] Realtek cihazları taranıyor... / Scanning for Realtek USB device..."
$usbList = & usbipd list 2>&1
$realtek = $usbList | Where-Object { $_ -match "0bda:c811|0bda:c820|Realtek" }

if (-not $realtek) {
    Write-Host "⚠️ Realtek aygıtı bulunamadı. / No Realtek device detected." -ForegroundColor Yellow
} else {
    $busid = ($realtek -split '\s+')[0]
    Write-Host "[+] Realtek cihaz bulundu: $busid / Device found: $busid" -ForegroundColor Green
    usbipd detach --busid $busid 2>$null | Out-Null
    Start-Sleep -Seconds 1
    usbipd attach --busid $busid --wsl | Out-Null
    Write-Host "[+] Realtek cihaz eklendi / Realtek adapter attached." -ForegroundColor Green
}

# Open root terminal
Write-Host "`n[*] Doğrulama için terminal açılıyor... / Opening verification shell..."
Start-Process "wsl.exe" -ArgumentList "-d $selected --user root -- bash"

Write-Host "`n✅ Kurulum tamamlandı. / Setup completed successfully." -ForegroundColor Green
Write-Host "Komutlar / Verify inside distro:"
Write-Host "   lsusb && dmesg | tail -n 20"
Write-Host "   iwconfig || ip a"
Write-Host "`n============================================================" -ForegroundColor Cyan
