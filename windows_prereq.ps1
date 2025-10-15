<<<<<<< HEAD
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
=======
﻿<#
    windows_prereq.ps1 - Windows setup for rtl8821cu WSL2 driver
    Author: ZNUZHG ONYVXPV
    Version: 2025-10-15
    Purpose: Enable WSL & VirtualMachinePlatform, ensure winget/curl, install usbipd-win if missing, restart WSL safely.
#>

# --- Yönetici kontrolü ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "⚠️  Lütfen bu betiği **Yönetici olarak** çalıştırın." -ForegroundColor Yellow
    Write-Host "Sağ tıklayın → 'Run as Administrator'" -ForegroundColor Cyan
    exit 1
}

# UTF-8
chcp 65001 | Out-Null

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " RTL8821CU WSL2 WINDOWS GEREKSİNİM KURULUMU (v4.2)" -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Cyan

# --- Windows özelliklerini etkinleştir ---
Write-Host "[*] WSL ve VirtualMachinePlatform etkinleştiriliyor..." -ForegroundColor Yellow
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null

# --- Araç kontrolleri ---
$tools = @("winget", "curl")
>>>>>>> f60bbde (fully automated WSL2 driver installer)
foreach ($t in $tools) {
    if (Get-Command $t -ErrorAction SilentlyContinue) {
        Write-Host "[+] $t bulundu." -ForegroundColor Green
    } else {
<<<<<<< HEAD
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
=======
        Write-Host "⚠️  $t eksik. Manuel kurmanız gerekebilir (Microsoft Store → App Installer)." -ForegroundColor Yellow
    }
}

# --- usbipd kurulumu ---
if (-not (Get-Command usbipd.exe -ErrorAction SilentlyContinue)) {
    Write-Host "`n[*] usbipd-win yükleniyor (winget)..." -ForegroundColor Yellow
    try {
        winget install --id=dorssel.usbipd-win -e --source winget -h | Out-Null
        Write-Host "[+] usbipd-win başarıyla yüklendi." -ForegroundColor Green
    } catch {
        Write-Host "❌ usbipd-win yüklenemedi. Manuel kurulum: https://github.com/dorssel/usbipd-win/releases" -ForegroundColor Red
>>>>>>> f60bbde (fully automated WSL2 driver installer)
    }
} else {
    Write-Host "[+] usbipd-win zaten yüklü." -ForegroundColor Green
}

<<<<<<< HEAD
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
=======
# --- Servis başlat ---
try {
    Write-Host "`n[*] usbipd servisi başlatılıyor..." -ForegroundColor Yellow
    Start-Service usbipd -ErrorAction SilentlyContinue
    Write-Host "[+] usbipd servisi aktif." -ForegroundColor Green
} catch {
    Write-Host "⚠️  usbipd servisi başlatılamadı." -ForegroundColor Yellow
}

# --- Cihaz listesi ---
Write-Host "`n[*] Bağlı USB cihazları:" -ForegroundColor Cyan
try { usbipd list } catch { Write-Host "⚠️  usbipd list başarısız." -ForegroundColor Yellow }

# --- WSL durumu ---
Write-Host "`n[*] WSL durumu:" -ForegroundColor Yellow
try { wsl --status } catch { Write-Host "❌ WSL komutu çalıştırılamadı." -ForegroundColor Red }

# --- Otomatik WSL restart ---
Write-Host "`n[*] WSL yeniden başlatılıyor..." -ForegroundColor Yellow
try {
    wsl --shutdown
    Start-Sleep -Seconds 2
    wsl --set-default-version 2
    Write-Host "[+] WSL yeniden başlatıldı ve varsayılan sürüm 2 olarak ayarlandı." -ForegroundColor Green
} catch {
    Write-Host "⚠️  WSL yeniden başlatma başarısız." -ForegroundColor Yellow
}

Write-Host "`n✅ Windows ön gereksinimleri tamamlandı." -ForegroundColor Green
Write-Host "USB cihazınızı bağlayın ve aşağıdakileri uygulayın:" -ForegroundColor Cyan
Write-Host "  usbipd.exe list" -ForegroundColor Cyan
Write-Host "  usbipd.exe attach --busid <BUSID> --wsl" -ForegroundColor Cyan
Write-Host "`n💡 Not: <BUSID> değerini yukarıdaki listeden alın." -ForegroundColor Yellow
>>>>>>> f60bbde (fully automated WSL2 driver installer)
