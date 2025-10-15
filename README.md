RTL8821CU WSL2 Fix — Full Auto Installer (Kali-focused, Multi-distro-ready)

Author: ZNUZHG ONYVXPV
Repo purpose: WSL2 üzerinde Realtek RTL8821CU / 8821CU tabanlı USB Wi-Fi adaptörlerine çalışan sürücü kurulum/onarım aracıdır. Otomatik adımlar, DKMS/make fallback, AI destekli log analizi ve usbipd entegrasyonu içerir.

Not: Bu araç öncelikle Kali Linux için hazırlanmıştır, ancak setup dosyası ve betikler birkaç basit değişiklikle Debian/Ubuntu/Benzeri dağıtımlarda da çalışacak şekilde tasarlanmıştır. Aşağıda hem Kali-only kullanım hem de multi-distro önerileri bulunur.

İçindekiler

Ön Koşullar

Dosya/Dizin Yapısı

Hızlı Başlangıç — Kali (önerilen)

Detaylı Kurulum Adımları

Nasıl Çalışır — Özet

Logler ve Hata Ayıklama

Sık Karşılaşılan Sorunlar & Çözümleri

Changelog / Sürüm Notları

Lisans

İletişim / Teşekkürler

Ön Koşullar

Windows 10/11 ile WSL2 desteği (VirtualMachinePlatform ve WSL özelliği aktif)

usbipd-win (Windows tarafında USB over IP sağlayan araç) — windows_prereq.ps1 betiği ile kurulabilir

PowerShell (Yönetici) kullanımı — setup_all.ps1 Run as Administrator ile çalıştırılmalı

WSL dağıtımı: tercihen kali-linux (script Kali-only olarak hazırlanmış); ileride otomatik tespit/çoklu-distro desteği eklenecek

İnternet bağlantısı (paketler & git repo çekmek için)

Dosya / Dizin Yapısı (repo kök)
rtl8821cu_wsl_fix-main/
├─ ai_helper.py                 # DKMS/make log analiz ve otomatik onarım aracı (Python)
├─ rtl8821cu_wsl_fix.sh         # WSL içindeki ana installer / builder (bash)
├─ setup_all.ps1                # Windows tarafı kontrol & WSL entegrasyon (PowerShell)
├─ windows_prereq.ps1           # Windows ön-koşul (usbipd-win, winget kontrol vs.)
├─ README.md                    # (Bu dosya)
├─ wsl_distro_log.txt           # (setup sırasında oluşturulan geçici log)
└─ openaikeyactivate.sh         # (opsiyonel/yardımcı)


Not: rtl8821cu_wsl_fix.sh ve ai_helper.py WSL içinden çalıştırılmak üzere kopyalanır. setup_all.ps1 bu dosyaları WSL içine güvenli şekilde aktarır.

Hızlı Başlangıç — Kali (özet)

Windows PowerShell'i Run as Administrator ile aç.

Repo dizinine gel:

cd C:\path\to\rtl8821cu_wsl_fix-main


Setup'ı çalıştır:

.\setup_all.ps1


Script açılışta Kali yüklü olup olmadığını soracaktır. Yüklü değilse:

wsl --install -d kali-linux


Script WSL içine dosyaları kopyalayıp (root olarak) rtl8821cu_wsl_fix.sh'ı çalıştırır.

Windows tarafında USB cihazını WSL'e bağlamak için:

usbipd.exe list
usbipd.exe attach --busid <BUSID> --wsl


Doğrulama (WSL içinde):

# örn. WSL root shell:
wsl -d kali-linux --user root -- bash
lsusb
dmesg | tail -n 20
iwconfig || ip a

Detaylı Kurulum Adımları (adım adım)
1) Windows — gerekli paketler & servis

setup_all.ps1 içinde windows_prereq.ps1 çağrılır. Elle yapmak istersen:

winget ve curl kontrolü

usbipd-win yükleme: winget install --id=usbipd-win -e veya Microsoft Store

VirtualMachinePlatform ve WindowsSubsystemForLinux etkinleştirme (gerekirse)

2) WSL restart & default version

Script wsl --shutdown ve wsl --set-default-version 2 gibi komutları çalıştırır.

3) Distro seçimi / Kali özel akış

Mevcut script Kali odaklıdır. Eğer Kali yoksa kullanıcıya yüklemesi söylenir.

İleride multi-distro otomatik seçimi: kali, ubuntu, debian öncelikli olarak algılanır (plan).

4) Dosyaların WSL içine güvenli aktarımı

PowerShell, dosya içeriklerini Base64 ile kodlayıp WSL root içinde açar — encoding hatalarını azaltmak için.

5) WSL içinde derleme & DKMS

rtl8821cu_wsl_fix.sh:

Gerekli paketleri (dkms, build-essential, libelf-dev, libssl-dev, flex, bison, vb.) kontrol eder/kurar.

WSL kernel kaynaklarını (WSL2-Linux-Kernel) hazırlar ve /lib/modules/<kernel>/build linkini verir.

Driver kaynağını klonlar (morrownr/8821cu-20210916) ve DKMS ile derlemeyi dener.

DKMS başarısız olursa:

ai_helper.py log analizini çalıştırır.

make fallback (in-tree module build) dener.

insmod/modprobe adımlarını uygular.

6) usbipd attach

Script usbipd list çıktısını Windows tarafında okur (Windows PowerShell) ve usbipd attach ile adaptörü WSL'e bağlamayı dener. Attach sırasında hedef distro çalışır durumda olmalıdır; script bu amaçla Kali root shell açıp açık bırakır.

Nasıl Çalışır — Teknik Özet

Windows tarafı (setup_all.ps1) WSL dağıtımını root olarak çalıştırılabilir hale getirir, dosyaları Base64 ile WSL'e aktarır ve root shell'i açık bırakır (usbipd attach için).

WSL tarafı (rtl8821cu_wsl_fix.sh) kernel kaynakları hazırlar, DKMS/make ile sürücüyü derler; başarısızlık halinde AI destekli log analizi (ai_helper.py) ile otomatik öneri/eksik paket kurulumunu dener.

Amaç: mümkün olduğu kadar otomatik, minimum kullanıcı müdahalesiyle çalışır hale getirmek.

Logler & Konumlar

Windows tarafı: wsl_distro_log.txt (setup çalıştırıldığında oluşturulur)

WSL tarafı (kök): ~/rtl8821cu_logs/ dizini

dkms_build_<timestamp>.log

make_build_<timestamp>.log

ai_report_<timestamp>.log

Hataları incelerken önce bu log dosyalarını paylaş veya incele.

Sık Karşılaşılan Hatalar & Çözümleri
There is no WSL 2 distribution running (usbipd attach)

Sebep: usbipd attach çalışırken hedef distro kapalı. Çözüm:

Açık bir WSL shell (root tercihen) bırak.

Veya setup script'in açtığı root terminali açık bırak.

Manuel:

# 1) Open root WSL shell (maintain this window)
wsl -d kali-linux --user root -- bash
# 2) Yeni PowerShell penceresinde attach
usbipd.exe attach --busid 2-13 --wsl

DKMS build ERROR: modpost: "..." undefined!

Genelde Module.symvers eksikliğinden veya kernel kaynaklarıyla eşleşmeme sebebiyle olur.

Çözüm seçenekleri:

ai_helper.py önerilerini uygula (eksik paketleri kurar).

Tam kernel modules derlemesi ile Module.symvers oluştur (ağır işlem).

Önerilen: önce make modules_prepare ile kaynakları hazırlayıp tekrar deneyin. Eğer başarısızsa, özel derlenmiş WSL kernel veya gerçek Linux kernel üzerinde test edin.

base64: invalid input veya dosya bozukluğu

Encoding/decoding sırasında PowerShell konsol kodlaması sebebiyle sorun çıkabilir. setup_all.ps1 UTF-8 (chcp 65001) ile çalıştırılmalı. Eğer sorun devam ederse dosyaları manuel kopyala.

v5.0 — Kali-only, AutoSafe base64 transfer, root-mode, usbipd attach automation

v4.x — AI log analiz, DKMS + make fallback, kernel source prepare

Daha önceki versiyonlarda hata düzeltmeleri ve locale/encoding iyileştirmeleri yapıldı.

Lisans

Bu proje MIT lisansı ile lisanslanmıştır.

Notlar / Güvenlik

Scriptler root hakları ile kernel modülü derlediği için dikkatli olun; değişiklikleri anlamadan çalıştırmak risklidir.

Windows/WSL sürüm farklılıkları derlemeyi etkileyebilir. Loglar ve uname -r bilgisi destek isterken paylaşılması gereken ilk veridir.

Yardım / İletişim

İlk testlerden sonra logları (özellikle ~/rtl8821cu_logs/*) paylaş, uname -r ve lsusb çıktıları ile birlikte yardımcı olabilirim.

