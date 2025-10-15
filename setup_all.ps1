<#
 RTL8821CU WSL2 FULL SETUP (AutoSelect v10.5)
 Gelişmiş distro algılama (Türkçe WSL, UTF8 fix, fallback listesi)
 Author: Znuzhg Onyvxpv
 Date: 2025-10-15
#>

function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Host "⚠️  Bu betiği YÖNETİCİ olarak çalıştırmalısınız (Run as Administrator)." -ForegroundColor Yellow
        exit 1
    }
}

function Normalize-Name {
    param($s)
    if ([string]::IsNullOrWhiteSpace($s)) { return "" }
    $n = $s.Trim('"', "'", " ", "`t", "`r", "`n")
    return $n
}

function Test-RunWsl {
    param($name)
    try {
        $out = & wsl -d "$name" --user root -- echo test_ok 2>$null
        if ($out -match "test_ok") { return $true }
    } catch {}
    return $false
}

Assert-Admin
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
cmd /c chcp 65001 > $null

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " RTL8821CU WSL2 FULL SETUP (AutoSelect v10.5)" -ForegroundColor Green
Write-Host " Directory: $ScriptDir" -ForegroundColor Cyan
Write-Host "============================================================`n"

# --- Yüklü distro listesi ---
$installed = @()
try { $installed += (& wsl --list --quiet 2>$null) } catch {}
$installed = $installed | ForEach-Object { Normalize-Name $_ } | Where-Object { $_ -ne "" }

# --- Online distro listesi (Türkçe/İngilizce destekli) ---
$online = @()
try {
    $raw = & cmd /c "chcp 65001 >nul && wsl -l --online" 2>$null
    foreach ($line in $raw) {
        $trim = $line.Trim()
        if ($trim -match "^(NAME|Aşağıdakiler|---|Geçerli|Kullanarak|^$)") { continue }
        if ($trim -match '^[A-Za-z0-9._-]+\s+') {
            $parts = $trim -split '\s{2,}'
            $name = Normalize-Name $parts[0]
            $desc = if ($parts.Length -gt 1) { $parts[1].Trim() } else { "" }
            if ($name -and $desc) {
                $online += [PSCustomObject]@{ Name = $name; Desc = $desc }
            }
        }
    }
} catch {}

# --- Eğer hala boşsa fallback listesi kullan ---
if (-not $online -or $online.Count -eq 0) {
    Write-Host "⚠️  WSL online listesi alınamadı. Yedek liste kullanılacak." -ForegroundColor Yellow
    $online = @(
        [PSCustomObject]@{Name="Ubuntu"; Desc="Ubuntu LTS"},
        [PSCustomObject]@{Name="Ubuntu-22.04"; Desc="Ubuntu 22.04 LTS"},
        [PSCustomObject]@{Name="Ubuntu-24.04"; Desc="Ubuntu 24.04 LTS"},
        [PSCustomObject]@{Name="Debian"; Desc="Debian GNU/Linux"},
        [PSCustomObject]@{Name="kali-linux"; Desc="Kali Linux Rolling"},
        [PSCustomObject]@{Name="FedoraLinux-42"; Desc="Fedora Linux"},
        [PSCustomObject]@{Name="archlinux"; Desc="Arch Linux"},
        [PSCustomObject]@{Name="openSUSE-Tumbleweed"; Desc="openSUSE Tumbleweed"},
        [PSCustomObject]@{Name="OracleLinux_9_5"; Desc="Oracle Linux 9.5"}
    )
}

# --- Listeyi kullanıcıya göster ---
Write-Host "Mevcut WSL dağıtımları:" -ForegroundColor Yellow
for ($i = 0; $i -lt $online.Count; $i++) {
    $isInstalled = $installed -contains $online[$i].Name
    $mark = if ($isInstalled) { "[Yüklü]" } else { "[Yüklü Değil]" }
    Write-Host ("  [{0}] {1,-25} {2}" -f ($i + 1), $online[$i].Name, $mark)
}

# --- Seçim al ---
$sel = ""
while ($true) {
    $sel = Read-Host "Hangi dağıtımı kullanmak istiyorsunuz? (1-$($online.Count))"
    if ([int]::TryParse($sel, [ref]$null) -and $sel -ge 1 -and $sel -le $online.Count) { break }
    Write-Host "❌ Geçersiz seçim. Lütfen 1 ile $($online.Count) arasında bir sayı girin." -ForegroundColor Red
}
$distro = $online[[int]$sel - 1].Name
Write-Host "[+] Seçilen dağıtım: $distro" -ForegroundColor Green

# --- Eğer yüklü değilse yükle ---
if ($installed -notcontains $distro) {
    Write-Host "[*] $distro yükleniyor..." -ForegroundColor Cyan
    try {
        wsl --install -d $distro
        Write-Host "[+] $distro başarıyla yüklendi." -ForegroundColor Green
    } catch {
        Write-Host "❌ $distro yüklenemedi. Manuel kurmanız gerekebilir." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[=] $distro zaten yüklü." -ForegroundColor Yellow
}

# --- Test et ---
if (-not (Test-RunWsl -name $distro)) {
    Write-Host "❌ $distro başlatılamadı." -ForegroundColor Red
    exit 1
}

# --- Klasör ve dosya işlemleri ---
$target = "/root/rtl8821cu_wsl_fix"
Write-Host "`n[*] Dizin oluşturuluyor: $target" -ForegroundColor Cyan
wsl -d "$distro" --user root -- bash -c "mkdir -p '$target'; chmod 700 '$target'"

$files = @("rtl8821cu_wsl_fix.sh","ai_helper.py")
foreach ($f in $files) {
    $src = Join-Path $ScriptDir $f
    if (-not (Test-Path $src)) {
        Write-Host "❌ Eksik dosya: $f" -ForegroundColor Red
        exit 1
    }
    Write-Host "[*] $f aktarılıyor..." -ForegroundColor Cyan
    $data = Get-Content -Raw -Encoding UTF8 $src
    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($data))
    wsl -d "$distro" --user root -- bash -c "echo '$b64' | base64 -d > '$target/$f'; chmod 755 '$target/$f'"
}
Write-Host "[+] Dosyalar aktarıldı." -ForegroundColor Green

# --- İç script ---
Write-Host "`n[*] İç script çalıştırılıyor..." -ForegroundColor Cyan
wsl -d "$distro" --user root -- bash -c "cd '$target'; bash ./rtl8821cu_wsl_fix.sh"

Write-Host "`n✅ Kurulum tamamlandı!" -ForegroundColor Green
Write-Host "Kontrol için WSL içinde çalıştır:" -ForegroundColor Cyan
Write-Host "  lsusb ; dmesg | tail -n 20" -ForegroundColor Cyan
Write-Host "  iwconfig ; ip a" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
