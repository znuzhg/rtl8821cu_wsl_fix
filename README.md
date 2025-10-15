# ⚙️ RTL8821CU WSL2 Fix — Full Auto Installer  
**Kali-Focused | Multi-Distro-Ready | AI-Assisted Driver Builder**

**Author:**  - ZNUZHG ONYVXPV -  
**Purpose:** Realtek RTL8821CU / 8821CU USB Wi-Fi adaptörleri için tam otomatik WSL2 sürücü kurulum ve onarım aracı.  
**Desteklenenler:** Kali Linux (odaklı), Debian, Ubuntu, ve benzeri WSL2 dağıtımları.

---

## 📘 Özellikler
- 🔧 **Tam otomatik sürücü kurulumu** (WSL2 içinde)
- 🧠 **AI destekli log analizi** (`ai_helper.py`)
- 🧱 **DKMS + make fallback sistemi**
- 🔌 **usbipd-win entegrasyonu**
- 🧰 **Kernel source auto-prepare** (eksik header durumunda)
- 🪟 **PowerShell + Bash entegrasyonu**
- ✅ **Kali Linux için optimize**  
  (Multi-distro desteği test aşamasında)

---

## 🧩 İçindekiler
1. [Ön Koşullar](#-ön-koşullar)
2. [Dizin Yapısı](#-dizin-yapısı)
3. [⚡ Hızlı Başlangıç — Kali](#-hızlı-başlangıç--kali)
4. [🔍 Detaylı Kurulum Adımları](#-detaylı-kurulum-adımları)
5. [🧠 Nasıl Çalışır](#-nasıl-çalışır)
6. [🪵 Loglar & Konumlar](#-loglar--konumlar)
7. [🚨 Sık Hatalar & Çözümler](#-sık-hatalar--çözümler)
8. [🧾 Changelog](#-changelog)
9. [⚖️ Lisans & Güvenlik](#️-lisans--güvenlik)
10. [💬 İletişim / Teşekkür](#-iletişim--teşekkür)

---

## 🧱 Ön Koşullar

| Gereksinim | Açıklama |
|-------------|----------|
| 🪟 **Windows 10/11 (WSL2)** | WSL2 ve VirtualMachinePlatform etkin olmalı |
| 🔌 **usbipd-win** | `windows_prereq.ps1` tarafından otomatik kurulur |
| ⚙️ **PowerShell (Yönetici)** | `setup_all.ps1` mutlaka *Run as Administrator* çalıştırılmalı |
| 🐧 **WSL Dağıtımı** | `kali-linux` önerilir (ileride Debian/Ubuntu desteği eklenecek) |
| 🌐 **İnternet** | Paket kurulumu ve GitHub reposu için gerekli |

---

## 📂 Dizin Yapısı

```bash
rtl8821cu_wsl_fix/
├── ai_helper.py             # AI log analizi & otomatik düzeltme aracı
├── rtl8821cu_wsl_fix.sh     # WSL içindeki ana installer (Bash)
├── setup_all.ps1            # Windows tarafı setup (PowerShell)
├── windows_prereq.ps1       # usbipd-win + WSL ön gereksinimleri
├── openaikeyactivate.sh     # (Opsiyonel yardımcı script)
├── README.md                # Bu dosya
└── wsl_distro_log.txt       # Setup sırasında oluşturulan log

📎 Not:
setup_all.ps1, ai_helper.py ve rtl8821cu_wsl_fix.sh dosyalarını güvenli şekilde WSL içerisine aktarır.

⚡ Hızlı Başlangıç — Kali Linux
1️⃣ PowerShell’i yönetici olarak aç:
cd "C:\Users\<kullanıcı>\Downloads\rtl8821cu_wsl_fix-main"
.\setup_all.ps1

2️⃣ Kali Linux yüklü değilse:
wsl --install -d kali-linux

3️⃣ Script WSL içine geçip kurulumu başlatır:
wsl -d kali-linux --user root
lsusb
dmesg | tail -n 20
iwconfig || ip a

4️⃣ Windows tarafında adaptörü bağla:
usbipd.exe list
usbipd.exe attach --busid <BUSID> --wsl

🔍 Detaylı Kurulum Adımları

Windows tarafı gereksinimler
windows_prereq.ps1:

usbipd-win kurulumu

WSL ve VirtualMachinePlatform etkinleştirme

WSL restart & default version set

Distro kontrolü ve WSL bağlantısı

Şu anda Kali için özel.

Gelecekte otomatik algılama (kali, ubuntu, debian) eklenecek.

Dosyaların WSL içine aktarımı

PowerShell dosyaları Base64 ile WSL içine taşır.

UTF-8 kodlaması sayesinde bozulma yaşanmaz.

Driver kurulumu (WSL içi)
rtl8821cu_wsl_fix.sh:

Paket kurulum kontrolü (dkms, build-essential, libelf-dev, vs.)

Kernel kaynaklarının hazırlanması

morrownr/8821cu-20210916 reposunun klonlanması

DKMS derlemesi → başarısızsa make fallback

AI log analizi (ai_helper.py) → otomatik düzeltme

modprobe / insmod ile yükleme

usbipd attach işlemi

WSL dağıtımı açık olmalıdır.

Setup script, Kali’yi root olarak başlatır.

🧠 Nasıl Çalışır
graph TD
    A[Windows setup_all.ps1] --> B[Check & install usbipd-win]
    B --> C[Start WSL as root]
    C --> D[Copy fix scripts into WSL]
    D --> E[Run rtl8821cu_wsl_fix.sh]
    E --> F[Check kernel headers / prepare]
    F --> G[DKMS build or fallback make]
    G --> H[AI log analysis (ai_helper.py)]
    H --> I[Module load & verification]


Amaç:
Her kullanıcıda minimum müdahaleyle sürücüyü çalışır hale getirmek.

🪵 Loglar & Konumlar
Konum	Açıklama
🪟 wsl_distro_log.txt	Windows tarafı log
🐧 ~/rtl8821cu_logs/	WSL tarafı log dizini
┣━━ dkms_build_*.log	DKMS derleme logu
┣━━ make_build_*.log	make fallback logu
┗━━ ai_report_*.log	AI analiz raporu
🚨 Sık Hatalar & Çözümler
❌ There is no WSL 2 distribution running

Sebep: usbipd attach sırasında distro kapalı.
Çözüm:

# Distroyu açık bırak:
wsl -d kali-linux --user root
# Ayrı pencerede attach et:
usbipd attach --busid 2-13 --wsl

⚠️ ERROR: modpost: "..." undefined!

Sebep: Module.symvers eksik veya kernel modül imzaları uyumsuz.
Çözüm:

ai_helper.py önerilerini uygula

make modules_prepare komutunu çalıştır

Gerekirse tam make modules ile Module.symvers oluştur

💥 base64: invalid input

Sebep: PowerShell kod sayfası hatalı.
Çözüm:

chcp 65001
.\setup_all.ps1

🧾 Changelog
Sürüm	Değişiklikler
v5.0	Kali-only AutoSafe, Base64 transfer, usbipd attach automation
v4.x	AI log analizi, DKMS + make fallback
v3.x	Kernel prepare optimizasyonu, locale iyileştirmeleri
⚖️ Lisans & Güvenlik

📝 Lisans: MIT License

⚠️ Root yetkileriyle çalışır.
Kernel modüllerini değiştirdiği için sadece güvenilir kaynaklardan edinilmiş sürümleri kullanın.

🔒 WSL ve Windows sürüm farkları derleme davranışını etkileyebilir.
Yardım isterken uname -r ve lsusb çıktısını paylaşın.

💬 İletişim & Teşekkür

Proje sahibi: - ZNUZHG ONYVXPV -
Destek & öneri: GitHub Issues (https://github.com/znuzhg/rtl8821cu_wsl_fix/issues)
💡 Bu proje WSL2 üzerinde Wi-Fi adaptörleri için tam otomatik, modern bir çözüm geliştirme hedefindedir.

"İMKANSIZI BAŞARMANIN YOLU DENEMEKTEN GEÇER" - znuzhg -
