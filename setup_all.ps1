<#
 RTL8821CU WSL2 Full Setup (AutoDefault v6.7)
 Author: ZNUZHG ONYVXPV
 Date: 2025-10-15

 Notes:
  - Fixed distro name normalization (no WSLError: WSL_E_DISTRO_NOT_FOUND)
  - Fixed UTF-8 issues in Windows PowerShell
  - Cleaned usbipd handling and improved logging
#>

function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Host "⚠️  Bu betiği **Yönetici olarak** çalıştırmalısınız." -ForegroundColor Yellow
        Write-Host "Sağ tıklayın → 'Yönetici olarak çalıştır (Run as Administrator)'" -ForegroundColor Cyan
        exit 1
    }
}

Assert-Admin
chcp 65001 > $null
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " RTL8821CU WSL2 FULL SETUP (AutoDefault v6.7)" -ForegroundColor Green
Write-Host " Directory: $ScriptDir" -ForegroundColor Cyan
Write-Host "============================================================`n"

# --- WSL distro tespiti ---
try {
    $distrosRaw = wsl --list --quiet 2>&1
} catch {
    Write-Host "❌ WSL çalıştırılamadı. WSL yüklü mü?" -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($distrosRaw)) {
    Write-Host "❌ Hiç WSL dağıtımı bulunamadı." -ForegroundColor Red
    Write-Host "💡 Yüklemek için: wsl --install -d Ubuntu" -ForegroundColor Cyan
    exit 1
}

# Try to detect default via verbose (star) first, fallback to first name from quiet list
$verboseList = (wsl --list --verbose 2>$null)
$defaultLine = $verboseList | Select-String '^\s*\*' | Select-Object -First 1
if ($defaultLine) {
    $selected = ($defaultLine.Line -replace '^\s*\*\s*','').Split()[0]
} else {
    $selected = ($distrosRaw -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | Select-Object -First 1)
}

# --- Normalize distro name ---
$selected = $selected.Trim().Trim('"').Trim("'")
$allDistros = (wsl --list --quiet 2>$null | ForEach-Object { $_.Trim() })
if ($allDistros -notcontains $selected) {
    $match = $allDistros | Where-Object { $_.ToLower() -eq $selected.ToLower() }
    if ($match) { $selected = $match }
}

if (-not $selected) {
    Write-Host "❌ Varsayılan dağıtım tespit edilemedi." -ForegroundColor Red
    exit 1
}

Write-Host "[+] Varsayılan dağıtım: $selected" -ForegroundColor Green
Write-Host "[i] Dağıtım adı doğrulama: '$selected'" -ForegroundColor DarkGray
wsl --list --quiet | ForEach-Object { Write-Host "  -> '$_'" -ForegroundColor DarkGray }

# --- windows_prereq kontrolü ---
$prereqPath = Join-Path $ScriptDir "windows_prereq.ps1"
if (-not (Test-Path $prereqPath)) {
    Write-Host "❌ Eksik dosya: windows_prereq.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "`n[*] windows_prereq.ps1 çalıştırılıyor..."
& powershell -ExecutionPolicy Bypass -File $prereqPath

# --- Root erişim kontrolü ---
Write-Host "`n[*] Root erişimi kontrol ediliyor..."
try {
    wsl -d $selected --user root -- bash -c "echo ok" | Out-Null
    Write-Host "[+] Root erişimi onaylandı." -ForegroundColor Green
} catch {
    Write-Host "⚠️  Root erişimi sağlanamadı, devam edilsin mi?" -ForegroundColor Yellow
    $ans = Read-Host "(y/N)"
    if ($ans.ToLower() -ne "y") { exit 1 }
}

# --- Dosya aktarımı ---
$targetPath = "/root/rtl8821cu_wsl_fix"
wsl -d $selected --user root -- bash -c "mkdir -p '$targetPath'" | Out-Null
$files = @("rtl8821cu_wsl_fix.sh","ai_helper.py")
foreach ($f in $files) {
    $src = Join-Path $ScriptDir $f
    if (-not (Test-Path $src)) { Write-Host "Eksik dosya: $f" -ForegroundColor Red; exit 1 }
    Write-Host "[*] $f aktarılıyor..."
    $content = Get-Content -Raw -Encoding UTF8 $src
    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($content))
    wsl -d $selected --user root -- bash -c "echo '$b64' | base64 -d > '$targetPath/$f'"
    if ($f -like "*.sh") {
        wsl -d $selected --user root -- bash -c "chmod +x '$targetPath/$f'"
    }
}
Write-Host "[+] Dosyalar kopyalandı." -ForegroundColor Green

# --- İç script çalıştır ---
$autoFlag = ""
if ($env:AUTO_YES -eq "1" -or $env:AUTO_YES -eq "true") { $autoFlag = "--auto-yes" }
Write-Host "`n[*] İç script çalıştırılıyor..."
wsl -d $selected --user root -- bash -lc "cd '$targetPath' && bash ./rtl8821cu_wsl_fix.sh $autoFlag"

# --- Realtek USB bağlama ---
Write-Host "`n[*] Realtek cihazları taranıyor..."
$usbipdCmd = Get-Command usbipd -ErrorAction SilentlyContinue
if ($usbipdCmd -and $usbipdCmd.Path) {
    try {
        $usbList = & "$($usbipdCmd.Path)" list 2>&1
        $realtek = $usbList | Where-Object { $_ -match "0bda:c811|0bda:c820|Realtek" }
        if ($realtek) {
            $busid = ($realtek -split '\s+')[0]
            & "$($usbipdCmd.Path)" detach --busid $busid 2>$null | Out-Null
            Start-Sleep -Seconds 1
            & "$($usbipdCmd.Path)" attach --busid $busid --wsl | Out-Null
            Write-Host "[+] Realtek cihaz eklendi: $busid" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Realtek cihazı bulunamadı." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️ usbipd bulundu ama işlem sırasında hata oluştu." -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ usbipd bulunamadı veya PATH içinde değil." -ForegroundColor Yellow
    Write-Host "💡 Yüklemek için: https://github.com/dorssel/usbipd-win/releases" -ForegroundColor Cyan
}

# --- Son ---
Start-Process "wsl.exe" -ArgumentList "-d $selected --user root -- bash"
Write-Host "`n✅ Kurulum tamamlandı!" -ForegroundColor Green
Write-Host "Test etmek için WSL içinde şunu çalıştırın:" -ForegroundColor Cyan
Write-Host "  lsusb && dmesg | tail -n 20" -ForegroundColor Cyan
Write-Host "  iwconfig || ip a" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
