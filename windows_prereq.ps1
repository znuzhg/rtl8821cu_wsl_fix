<#
    windows_prereq.ps1 - Windows setup for rtl8821cu WSL2 driver
    Author: ZNUZHG ONYVXPV
    Version: 2025-10-15 (v4.5)

    Purpose:
      - Enable WSL & VirtualMachinePlatform
      - Ensure winget and curl availability
      - Install usbipd-win if missing
      - Restart WSL safely and verify
#>

# --- Yönetici kontrolü ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "⚠️  Lütfen bu betiği Yönetici olarak çalıştırın." -ForegroundColor Yellow
    Write-Host "Sağ tıklayın → 'Run as Administrator'" -ForegroundColor Cyan
    exit 1
}

# --- UTF-8 console ---
chcp 65001 > $null

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " RTL8821CU WSL2 WINDOWS GEREKSİNİM KURULUMU (v4.5)" -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Cyan

# --- Windows özelliklerini etkinleştir ---
Write-Host "[*] WSL ve VirtualMachinePlatform etkinleştiriliyor..." -ForegroundColor Yellow
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null

# --- Araç kontrolleri ---
$tools = @("winget", "curl")
foreach ($t in $tools) {
    if (Get-Command $t -ErrorAction SilentlyContinue) {
        Write-Host "[+] $t bulundu." -ForegroundColor Green
    } else {
        Write-Host "⚠️  $t eksik. Manuel kurmanız gerekebilir (Microsoft Store → App Installer)." -ForegroundColor Yellow
    }
}

# --- usbipd kurulumu ---
if (-not (Get-Command usbipd -ErrorAction SilentlyContinue)) {
    Write-Host "`n[*] usbipd-win yükleniyor (winget)..." -ForegroundColor Yellow
    try {
        winget install --id=dorssel.usbipd-win -e --source winget -h | Out-Null
        Write-Host "[+] usbipd-win başarıyla yüklendi." -ForegroundColor Green
    } catch {
        Write-Host "❌ usbipd-win yüklenemedi. Manuel kurulum adresi:" -ForegroundColor Red
        Write-Host "👉 https://github.com/dorssel/usbipd-win/releases" -ForegroundColor Cyan
    }
} else {
    Write-Host "[+] usbipd-win zaten yüklü." -ForegroundColor Green
}

# --- Servis başlat ---
try {
    Write-Host "`n[*] usbipd servisi başlatılıyor..." -ForegroundColor Yellow
    Start-Service usbipd -ErrorAction SilentlyContinue
    Write-Host "[+] usbipd servisi aktif." -ForegroundColor Green
} catch {
    Write-Host "⚠️  usbipd servisi başlatılamadı (manuel başlatmayı deneyin)." -ForegroundColor Yellow
}

# --- Cihaz listesi ---
Write-Host "`n[*] Bağlı USB cihazları:" -ForegroundColor Cyan
try {
    $usbipdCmd = Get-Command usbipd -ErrorAction SilentlyContinue
    if ($usbipdCmd -and $usbipdCmd.Path) {
        & "$($usbipdCmd.Path)" list
    } else {
        Write-Host "⚠️  usbipd bulunamadı veya PATH içinde değil." -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  usbipd list başarısız." -ForegroundColor Yellow
}

# --- WSL durumu ---
Write-Host "`n[*] WSL durumu denetleniyor..." -ForegroundColor Yellow
try {
    wsl --status
} catch {
    Write-Host "❌ WSL komutu çalıştırılamadı. Lütfen WSL kurulumunuzu kontrol edin." -ForegroundColor Red
}

# --- Otomatik WSL yeniden başlatma ---
Write-Host "`n[*] WSL yeniden başlatılıyor..." -ForegroundColor Yellow
try {
    wsl --shutdown
    Start-Sleep -Seconds 2
    wsl --set-default-version 2
    Write-Host "[+] WSL yeniden başlatıldı ve varsayılan sürüm 2 olarak ayarlandı." -ForegroundColor Green
} catch {
    Write-Host "⚠️  WSL yeniden başlatma başarısız. Manuel olarak kapatıp açabilirsiniz." -ForegroundColor Yellow
}


# --- Son mesajlar ---
Write-Host "`n✅ Windows ön gereksinimleri başarıyla tamamlandı!" -ForegroundColor Green
Write-Host "💡 Devam etmeden önce USB adaptörünüzü takın ve aşağıdaki komutları çalıştırın:" -ForegroundColor Cyan
Write-Host "  usbipd.exe list" -ForegroundColor Cyan
Write-Host "  usbipd.exe attach --busid `<BUSID`> --wsl" -ForegroundColor Cyan
Write-Host "`n💡 Not: <BUSID> değerini yukarıdaki listeden alın." -ForegroundColor Yellow
