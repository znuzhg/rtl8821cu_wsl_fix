🇹🇷 RTL8821CU WSL2 Otomatik Kurulum ve Onarım Aracı

Sürüm: v3.0 — 2025-10-14
Geliştiriciler: ZNUZHG ONYVXPV
Proje adı: rtl8821cu_wsl_fix

🎯 Bu araç ne işe yarar?

Bu proje, Realtek RTL8821CU / RTL8811CU yonga setine sahip USB Wi-Fi adaptörlerinin
WSL2 (Windows Subsystem for Linux 2) altında tam olarak çalışmasını sağlar.

Tool, kurulumu tamamen otomatik hale getirir:

Windows tarafında gerekli bileşenleri (usbipd, WSL özellikleri) kurar,

WSL tarafında sürücüyü (rtl8821cu) derleyip yükler,

Eksik kernel header’larını otomatik oluşturur,

Hata durumlarını algılar, gerekirse düzeltir,

İsteğe bağlı olarak yapay zekâ (GPT) destekli log analizi sunar.

📂 Dizin Yapısı
rtl8821cu_wsl_fix/
├── ai_helper.py              # Yapay zekâ destekli log analiz aracı
├── openaikeyactivate.sh      # OpenAI API anahtarı yükleyici
├── rtl8821cu_wsl_fix.sh      # Ana WSL2 kurulum ve onarım aracı
├── windows_prereq.ps1        # Windows tarafı hazırlık (usbipd, WSL, vb.)
└── README.md                 # Bu belge

⚙️ Gereksinimler
Platform	Gerekenler
Windows	Windows 10 / 11 (WSL2 etkin), Yönetici yetkisi
WSL	Ubuntu, Kali veya Debian tabanlı dağıtım
Donanım	Realtek RTL8821CU / RTL8811CU Wi-Fi adaptör
Bağlantı	İnternet (paket indirme ve kernel klonlama için)
Python	3.7+ (AI log analizi için gerekli)
🚀 Kurulum Adımları
🪟 1. Windows Tarafı — windows_prereq.ps1

PowerShell’i Yönetici olarak açın ve aşağıdaki komutları çalıştırın:

Set-ExecutionPolicy Bypass -Scope Process -Force
cd "C:\Users\<kullanıcı_adınız>\rtl8821cu_wsl_fix"
.\windows_prereq.ps1


Bu script:

usbipd-win yüklü mü kontrol eder, değilse otomatik kurar,

Gerekli Windows özelliklerini etkinleştirir:

Microsoft-Windows-Subsystem-Linux

VirtualMachinePlatform

Usbip (ve bağlı servisler)

usbipd servisini başlatır ve otomatik başlatmaya alır,

Son olarak cihazı bağlamak için talimat verir.

Eğer winget veya curl eksikse, script manuel yükleme talimatlarını gösterir ve Microsoft’un resmi dökümanına yönlendirir:
🔗 WSL’de USB cihazı kullanma

💡 Kurulum bitince: Bilgisayarı yeniden başlatmanız veya PowerShell’de
wsl --shutdown komutunu çalıştırmanız önerilir.

🔌 2. USB Aygıtını WSL2’ye Bağlayın

Windows PowerShell’de:

usbipd wsl list


Çıktıda Realtek Wi-Fi adaptörünüz görünüyorsa, şu komutla bağlayın:

usbipd wsl attach --busid <BUSID>


(<BUSID> örneğin 1-1 olabilir.)

🐧 3. WSL Tarafı — rtl8821cu_wsl_fix.sh

WSL terminalinizi (ör. Ubuntu veya Kali) açın:

cd ~/rtl8821cu_wsl_fix
chmod +x *.sh ai_helper.py
sudo ./rtl8821cu_wsl_fix.sh


Script şu adımları tam otomatik yapar:

WSL2 ortamını doğrular.

Gerekli bağımlılıkları yükler (dkms, git, build-essential, libelf-dev, vb.).

Kernel header eksikse, Microsoft’un WSL kernel’ını indirip make prepare işlemini yapar.

morrownr/8821cu-20210916 sürücü kaynağını klonlar.

DKMS ile modülü derler, kurar ve sisteme ekler.

modprobe 8821cu komutunu çalıştırır ve wlan0 arayüzünü kontrol eder.

Hata oluşursa, ai_helper.py logları analiz eder ve düzeltme önerir.

🤖 4. (İsteğe Bağlı) Yapay Zekâ Log Analizi

AI destekli hata çözümü için:

./openaikeyactivate.sh


Anahtarınızı girin (sk- ile başlayan OpenAI API anahtarı).
Bu sayede derleme hataları otomatik olarak analiz edilir.

🔍 Sorun Giderme (Sık Görülen Hatalar)
❌ modprobe: FATAL: Module 8821cu not found

Olası nedenler:

DKMS derlemesi başarısız oldu.

Header dosyaları eksik.

Kernel sürümü değişti.

Çözüm:

dkms status
sudo depmod -a
sudo modprobe 8821cu
dmesg | tail -n 40


Eğer 8821cu listelenmiyorsa:

sudo dkms remove rtl8821cu/5.12.0.4 --all
sudo ./rtl8821cu_wsl_fix.sh

⚠️ linux-headers-<sürüm> bulunamadı

WSL çekirdeğinde header paketleri apt üzerinden mevcut değildir.
Script bunu fark edip otomatik olarak:

git clone https://github.com/microsoft/WSL2-Linux-Kernel.git
cp Microsoft/config-wsl .config
make prepare modules_prepare
ln -sf ~/WSL2-Linux-Kernel /lib/modules/$(uname -r)/build


adımlarını uygular.

🔄 usbipd hatası (Windows tarafı)

Eğer cihaz görünmüyorsa:

Get-Service usbipd
Start-Service usbipd
usbipd wsl list


Hâlâ görünmüyorsa windows_prereq.ps1’i tekrar çalıştırın veya Microsoft dokümanındaki yönergeleri izleyin.

🧠 AI Log Analiz Aracı (ai_helper.py)

Bu araç, sürücü derleme hatalarını OpenAI GPT modeliyle analiz eder.
Kullanım:

python3 ai_helper.py --log ~/rtl8821cu_logs/dkms_build.log --out analiz.txt

📜 Loglar

Tüm loglar ~/rtl8821cu_logs/ dizinine kaydedilir:

build.log

install.log

dkms_status.log

Hata durumlarında bu dosyaları inceleyebilir veya paylaşabilirsiniz.

💡 Ek Komutlar

Sürücü durumunu kontrol et:

dkms status
lsmod | grep 8821
ip a


Sürücü elle kaldırmak istersen:

sudo dkms remove rtl8821cu/5.12.0.4 --all
sudo rm -rf /usr/src/rtl8821cu-5.12.0.4

🧰 Geliştiriciler İçin Notlar

DKMS sürüm adı /usr/src/<paket>-<sürüm> dizin adıyla aynı olmalıdır.

Patch (yama) gerekiyorsa sed veya .patch dosyası olarak düzenlenebilir.

CI/CD sistemlerinde test için WSL imajlarıyla otomatik test yapılabilir.

🕒 Sürüm Geçmişi
Sürüm	Tarih	Değişiklik
v3.0	2025-10-14	Tam otomasyon, usbipd kontrolü, kernel header self-fix, AI entegrasyonu
v2.5	2025-05	Manuel kurulum adımları
v2.0	2024-12	DKMS entegrasyonu
v1.0	2024-08	İlk sürüm
🔐 Güvenlik

Script’ler sudo yetkisiyle çalışır; sadece güvenilir sistemlerde kullanın.

ai_helper.py logları OpenAI API’ye gönderir — özel bilgiler içeren loglarda dikkatli olun.

API anahtarı openai_key.conf veya .bashrc içinde saklanır; gizli tutun.

🧾 Lisans

MIT Lisansı
© 2025 ZNUZHG ONYVXPV

📬 Destek & Geri Bildirim

Sorularınız ve önerileriniz için GitHub üzerinden issue açabilirsiniz.
Destek olabilmek için şu bilgileri ekleyin:

uname -r

dkms status

dmesg | tail -n 60

lsusb

lsmod | grep 8821

ip a