#!/usr/bin/env bash
# ============================================================================
# rtl8821cu_wsl_fix.sh
# WSL2 Tarafı Otomatik Kurulum ve Onarım Aracı (v3.0)
# ============================================================================
# Yazarlar : ZNUZHG ONYVXPV
# Sürüm    : 3.0 (2025-10-14)
# Amaç     : WSL2 altında Realtek RTL8821CU Wi-Fi sürücüsünü (morrownr/8821cu)
#            DKMS yöntemiyle derleyip yüklemek, eksik header veya hataları
#            otomatik tespit edip düzeltmek, gerekirse AI analiziyle logları çözümlemek.
# ============================================================================
# Özellikler:
#  - Tüm paketleri otomatik kontrol ve yükleme
#  - WSL kernel headers eksikse kendisi oluşturur
#  - DKMS otomasyonu: add/build/install
#  - Hata durumunda yapay zekâ destekli analiz (ai_helper.py)
#  - Menü desteği (xterm + rehber pencere)
#  - Log arşivleme
# ============================================================================

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# -------- AYARLANABİLİR DEĞİŞKENLER --------
BASE_DIR="${HOME}/rtl8821cu_wsl_fix"
KERNEL_SRC_DIR="${HOME}/WSL2-Linux-Kernel"
DRIVER_REPO="https://github.com/morrownr/8821cu-20210916.git"
DRIVER_CLONE_DIR="${HOME}/8821cu-20210916"
AI_HELPER="${BASE_DIR}/ai_helper.py"
LOGDIR="${HOME}/rtl8821cu_logs"
DKMS_TMP_PREFIX="/usr/src"
# --------------------------------------------

mkdir -p "${BASE_DIR}" "${LOGDIR}"

# -------- RENKLİ MESAJ FONKSİYONLARI --------
info() { echo -e "\e[1;34m[*]\e[0m $*"; }
ok()   { echo -e "\e[1;32m[+]\e[0m $*"; }
warn() { echo -e "\e[1;33m[!]\e[0m $*"; }
err()  { echo -e "\e[1;31m[-]\e[0m $*"; }

# -------- ROOT KONTROLÜ --------
if [ "$EUID" -ne 0 ]; then
  warn "Bazı işlemler için sudo yetkisi gereklidir. Gerekirse şifre sorulacaktır."
fi

# -------- WSL2 ORTAMI KONTROLÜ --------
if ! grep -qi microsoft /proc/version 2>/dev/null; then
  err "Bu script sadece WSL2 ortamında çalıştırılabilir!"
  exit 1
fi
ok "WSL2 ortamı doğrulandı."

# -------- WINDOWS TARAFI KONTROL SORUSU --------
read -rp $'\nWindows tarafındaki windows_prereq.ps1 betiğini (usbipd kurulumu) çalıştırdınız mı? [y/N]: ' resp
resp=${resp,,}
if [[ "$resp" != "y" && "$resp" != "yes" ]]; then
  warn "Lütfen önce windows_prereq.ps1 betiğini Windows üzerinde (Yönetici olarak) çalıştırın."
  exit 1
fi

# -------- PAKET KONTROLLERİ --------
PKGS=(dkms build-essential git bc libelf-dev libssl-dev usbutils usbip linux-tools-common make xterm libncurses-dev pkg-config)
info "Gerekli paketler kontrol ediliyor..."
sudo apt update -y
for p in "${PKGS[@]}"; do
  if dpkg -s "$p" >/dev/null 2>&1; then
    ok "$p zaten kurulu."
  else
    info "$p yükleniyor..."
    sudo apt install -y "$p" || {
      err "$p yüklenemedi. Bağlantınızı kontrol edin veya el ile yükleyin."
      exit 1
    }
  fi
done
ok "Tüm paketler hazır."

# -------- KERNEL HEADER / WSL KERNEL --------
KVER="$(uname -r)"
info "Aktif kernel sürümü: $KVER"

if dpkg -s "linux-headers-$KVER" >/dev/null 2>&1; then
  ok "linux-headers-$KVER sistemde mevcut."
else
  warn "linux-headers-$KVER paketlerde bulunamadı (WSL için normal). Kernel kaynakları hazırlanacak."
  if [ ! -d "${KERNEL_SRC_DIR}" ]; then
    info "WSL2 kernel kaynakları indiriliyor..."
    git clone https://github.com/microsoft/WSL2-Linux-Kernel.git --depth=1 -b linux-msft-wsl-6.6.y "${KERNEL_SRC_DIR}"
  else
    info "Kernel kaynakları güncelleniyor..."
    (cd "${KERNEL_SRC_DIR}" && git pull) || true
  fi

  cd "${KERNEL_SRC_DIR}"
  if [ ! -f .config ]; then
    cp Microsoft/config-wsl .config || yes "" | make oldconfig
  fi

  info "Kernel headers hazırlanıyor..."
  make prepare -j"$(nproc)" || true
  make modules_prepare -j"$(nproc)" || true
  sudo mkdir -p "/lib/modules/${KVER}"
  sudo ln -sf "${KERNEL_SRC_DIR}" "/lib/modules/${KVER}/build"
  ok "Headers hazır ve linklendi."
fi

# -------- SÜRÜCÜ KODU --------
if [ ! -d "${DRIVER_CLONE_DIR}" ]; then
  info "RTL8821CU sürücü kaynağı indiriliyor..."
  git clone "${DRIVER_REPO}" "${DRIVER_CLONE_DIR}"
else
  info "Sürücü deposu mevcut, güncelleniyor..."
  (cd "${DRIVER_CLONE_DIR}" && git pull)
fi

DKMS_CONF="${DRIVER_CLONE_DIR}/dkms.conf"
if [ -f "${DKMS_CONF}" ]; then
  PACKAGE_NAME=$(grep -E '^PACKAGE_NAME' "${DKMS_CONF}" | sed 's/.*=//;s/"//g')
  PACKAGE_VERSION=$(grep -E '^PACKAGE_VERSION' "${DKMS_CONF}" | sed 's/.*=//;s/"//g')
else
  PACKAGE_NAME="rtl8821cu"
  PACKAGE_VERSION="5.12.0.4"
fi

ok "Sürücü bilgisi: ${PACKAGE_NAME}-${PACKAGE_VERSION}"

# -------- ESKİ DKMS GİRİŞLERİNİ TEMİZLE --------
if dkms status | grep -qi "${PACKAGE_NAME}"; then
  warn "Mevcut DKMS girdileri temizleniyor..."
  sudo dkms remove "${PACKAGE_NAME}/${PACKAGE_VERSION}" --all || true
fi

sudo rm -rf "${DKMS_TMP_PREFIX:?}/${PACKAGE_NAME}-${PACKAGE_VERSION}"
sudo cp -r "${DRIVER_CLONE_DIR}" "${DKMS_TMP_PREFIX}/${PACKAGE_NAME}-${PACKAGE_VERSION}"

# -------- DKMS ADD/BUILD/INSTALL --------
info "DKMS: ekleme..."
sudo dkms add -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" || true

info "DKMS: derleniyor..."
sudo dkms build -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" | tee "${LOGDIR}/dkms_build_$(date +%s).log"

info "DKMS: yükleniyor..."
sudo dkms install -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" | tee "${LOGDIR}/dkms_install_$(date +%s).log"

# -------- MODÜL YÜKLEME --------
sudo depmod -a
if sudo modprobe 8821cu; then
  ok "Modül başarıyla yüklendi (modprobe 8821cu)"
else
  err "modprobe başarısız. 8821cu.ko dosyası aranıyor..."
  KO=$(find /lib/modules/"${KVER}" -name "8821cu*.ko" -print -quit)
  if [ -n "$KO" ]; then
    sudo insmod "$KO" && ok "Modül elle yüklendi."
  else
    err "8821cu.ko bulunamadı. Loglar ${LOGDIR} dizininde."
    exit 1
  fi
fi

# -------- MENÜCONFIG (OPSİYONEL) --------
read -rp $'\nMenüconfig ekranını (xterm ile) açmak ister misiniz? [y/N]: ' ans
ans=${ans,,}
if [[ "$ans" == "y" || "$ans" == "yes" ]]; then
  if command -v xterm >/dev/null 2>&1; then
    xterm -geometry 100x30 -T "Kernel Menüconfig" -e "make menuconfig" &
    xterm -geometry 90x10+1200+50 -T "Yardım" -e "bash -lc 'echo \"Device Drivers -> Wireless LAN -> Realtek 8821CU olarak M işaretleyin.\"; read -p \"Bitince ENTER'a basın...\"'"
  else
    warn "xterm kurulu değil, menüconfig atlanıyor."
  fi
fi

# -------- ÖZET --------
ok "Kurulum tamamlandı."
dkms status | tee "${LOGDIR}/dkms_status_$(date +%s).log"
ip a | tee "${LOGDIR}/ip_a_$(date +%s).log"

echo
ok "USB adaptörü bağlamak için Windows tarafında PowerShell (Yönetici) ile:"
echo "  usbipd wsl list"
echo "  usbipd wsl attach --busid <BUSID>"
echo
ok "Sonra WSL'de 'ip a' ve 'dmesg | tail' ile wlan0 arayüzünü kontrol edin."
ok "Tüm loglar: ${LOGDIR}"

exit 0
