<#
    windows_prereq.ps1 - Windows setup for rtl8821cu WSL2 driver
    Author: ZNUZHG ONYVXPV
    Version: 2025-10-15
    Purpose: Enable WSL & VirtualMachinePlatform, ensure winget/curl, install usbipd-win if missing.
#>

# Admin check
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "UYARI: Bu PowerShell betiğini Yönetici olarak çalıştırmalısınız." -ForegroundColor Yellow
    exit 1
}

# set utf-8 console
chcp 65001 | Out-Null

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " RTL8821CU WSL2 WINDOWS GEREKSINIM KURULUMU" -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Cyan

Write-Host "[*] Gerekli Windows özellikleri etkinleştiriliyor..." -ForegroundColor Yellow
# Enable features (no-restart to avoid forcing reboot here)
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null

# Check winget and curl
$tools = @("winget","curl")
foreach ($t in $tools) {
    if (Get-Command $t -ErrorAction SilentlyContinue) {
        Write-Host "[+] $t bulundu." -ForegroundColor Green
    } else {
        Write-Host "Eksik araç: $t. Manuel kurun (App Installer / Microsoft Store veya curl install)." -ForegroundColor Yellow
    }
}

# Install usbipd-win if missing
if (-not (Get-Command usbipd.exe -ErrorAction SilentlyContinue)) {
    Write-Host "`n[*] usbipd-win yükleniyor (winget üzerinden)..." -ForegroundColor Yellow
    try {
        winget install --id=dorssel.usbipd-win -e --source winget -h | Out-Null
        Write-Host "[+] usbipd-win yüklendi." -ForegroundColor Green
    } catch {
        Write-Host "⚠️  usbipd-win otomatik yüklenemedi." -ForegroundColor Red
        Write-Host "Lütfen manuel yükleyin: https://github.com/dorssel/usbipd-win/releases" -ForegroundColor Cyan
    }
} else {
    Write-Host "[+] usbipd-win zaten yüklü." -ForegroundColor Green
}

# Start/enable usbipd service if available
if (Get-Command usbipd.exe -ErrorAction SilentlyContinue) {
    try {
        Start-Process -FilePath usbipd.exe -ArgumentList "wsl","--help" -NoNewWindow -WindowStyle Hidden -ErrorAction SilentlyContinue
    } catch {}
    Write-Host "`n[*] usbipd list (mevcut cihazlar):" -ForegroundColor Cyan
    try {
        usbipd list
    } catch {
        Write-Host "usbipd çalıştırılamadı." -ForegroundColor Yellow
    }
} else {
    Write-Host "`nusbipd komutu bulunamadı." -ForegroundColor Yellow
}

# Check WSL status
Write-Host "`n[*] WSL durumu:" -ForegroundColor Yellow
try {
    wsl --status
} catch {
    Write-Host "wsl komutu çalıştırılamadı. Lütfen Windows'ta WSL kurulumunu kontrol edin." -ForegroundColor Red
}

Write-Host "`n[+] Windows ön gereksinimleri tamamlandı!" -ForegroundColor Green
Write-Host "Sonraki adımlar (Yönetici PowerShell):" -ForegroundColor Cyan
Write-Host "  1) USB cihazınızı takın." -ForegroundColor Cyan
Write-Host "  2) usbipd.exe list" -ForegroundColor Cyan
Write-Host "  3) usbipd.exe attach --busid '<BUSID>' --wsl" -ForegroundColor Cyan
Write-Host "`nNot: '<BUSID>' yerine usbipd list çıktısındaki busid değerini girin." -ForegroundColor Yellow
