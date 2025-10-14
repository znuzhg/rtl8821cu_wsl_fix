#!/usr/bin/env bash
# ============================================================================
# rtl8821cu_wsl_fix.sh (v4.1 adaptive-autoheal)
# WSL2 Otomatik Kurulum + Onarım + AI destekli Kernel/Driver Fixer
# Author: ZNUZHG ONYVXPV
# ============================================================================
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

BASE_DIR="${HOME}/rtl8821cu_wsl_fix"
KERNEL_SRC_DIR="${HOME}/WSL2-Linux-Kernel"
DRIVER_REPO="https://github.com/morrownr/8821cu-20210916.git"
DRIVER_CLONE_DIR="${HOME}/8821cu-20210916"
AI_HELPER="${BASE_DIR}/ai_helper.py"
LOGDIR="${HOME}/rtl8821cu_logs"
DKMS_SRC_PREFIX="/usr/src"
PKGS=(dkms build-essential git bc libelf-dev libssl-dev usbutils usbip make xterm libncurses-dev pkg-config flex bison)
OPTIONAL_PKGS=(linux-tools-common)

mkdir -p "${BASE_DIR}" "${LOGDIR}"
timestamp(){ date +%Y%m%d_%H%M%S; }
info(){ echo -e "\e[1;34m[*]\e[0m $*"; }
ok(){ echo -e "\e[1;32m[+]\e[0m $*"; }
warn(){ echo -e "\e[1;33m[!]\e[0m $*"; }
err(){ echo -e "\e[1;31m[-]\e[0m $*"; }

# --- WSL kontrolü ---
if ! grep -qi microsoft /proc/version 2>/dev/null; then
  err "Bu betik yalnızca WSL2 ortamında çalıştırılabilir."
  exit 1
fi
ok "WSL2 ortamı doğrulandı."

# --- Windows tarafı doğrulama ---
read -rp $'\nWindows tarafındaki windows_prereq.ps1 (usbipd kurulumu) çalıştırıldı mı? [y/N]: ' RESP
RESP=${RESP,,}
[[ "$RESP" != "y" && "$RESP" != "yes" ]] && { warn "Lütfen önce windows_prereq.ps1'i çalıştırın."; exit 1; }

# --- Paket yüklemeleri ---
info "apt update çalıştırılıyor..."
sudo apt update -y >/dev/null || warn "apt update başarısız olabilir, yine de devam."
info "Gerekli paketler kontrol ediliyor..."
for p in "${PKGS[@]}"; do
  dpkg -s "$p" >/dev/null 2>&1 && ok "$p yüklü" || { info "$p yükleniyor..."; sudo apt install -y "$p"; }
done
for p in "${OPTIONAL_PKGS[@]}"; do
  dpkg -s "$p" >/dev/null 2>&1 || warn "Opsiyonel $p yok (USB/IP debug kısıtlı olabilir)"
done

KVER="$(uname -r)"
info "Aktif kernel sürümü: $KVER"

# --- Kernel Headers / WSL kaynak ---
if [ ! -d "/lib/modules/${KVER}/build" ]; then
  warn "Headers yok, WSL2 kernel kaynakları hazırlanacak..."
  if [ ! -d "${KERNEL_SRC_DIR}" ]; then
    git clone https://github.com/microsoft/WSL2-Linux-Kernel.git --depth=1 -b linux-msft-wsl-6.6.y "${KERNEL_SRC_DIR}"
  fi
  cd "${KERNEL_SRC_DIR}"
  cp Microsoft/config-wsl .config || true
  make olddefconfig >/dev/null 2>&1 || yes "" | make oldconfig
  make prepare -j"$(nproc)" || warn "prepare başarısız"
  make modules_prepare -j"$(nproc)" || warn "modules_prepare başarısız"
  sudo mkdir -p "/lib/modules/${KVER}"
  sudo ln -sfn "${KERNEL_SRC_DIR}" "/lib/modules/${KVER}/build"
  ok "Kernel headers hazırlandı."
else
  ok "Headers zaten bağlı."
fi

# --- Driver clone/update ---
if [ ! -d "${DRIVER_CLONE_DIR}" ]; then
  git clone "${DRIVER_REPO}" "${DRIVER_CLONE_DIR}"
else
  (cd "${DRIVER_CLONE_DIR}" && git pull)
fi

PACKAGE_NAME="rtl8821cu"
PACKAGE_VERSION="5.12.0.4"
SRC_DIR="${DKMS_SRC_PREFIX}/${PACKAGE_NAME}-${PACKAGE_VERSION}"

sudo rm -rf "${SRC_DIR}"
sudo cp -r "${DRIVER_CLONE_DIR}" "${SRC_DIR}"
sudo chown -R root:root "${SRC_DIR}"

BUILD_LOG="${LOGDIR}/dkms_build_$(timestamp).log"

# --- DKMS add/build ---
sudo dkms remove "${PACKAGE_NAME}/${PACKAGE_VERSION}" --all >/dev/null 2>&1 || true
sudo dkms add -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" || true

info "DKMS derleme başlatılıyor..."
if sudo dkms build -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" 2>&1 | tee "${BUILD_LOG}"; then
  ok "DKMS build tamamlandı"
else
  warn "DKMS build başarısız. Kernel sembollerini ve eksik header'ları analiz ediyorum..."

  # --- AI destekli analiz + otomatik onarım ---
  if [ -f "${AI_HELPER}" ]; then
    info "AI log analiz başlatılıyor..."
    python3 "${AI_HELPER}" --log "${BUILD_LOG}" --auto || warn "AI onarım tamamlanamadı."
  fi

  # --- manuel adaptif onarım (senin v3.3 logic'in) ---
  if grep -q "undefined" "${BUILD_LOG}"; then
    warn "Kernel modül sembolleri eksik. WSL2 kernel’i sınırlı olabilir."
    info "config içinde kablosuz modüller etkinleştiriliyor..."
    cd "${KERNEL_SRC_DIR}"
    for opt in CFG80211 MAC80211 WIRELESS USB_NET_DRIVERS NETDEVICES; do
      sed -i "s/^# CONFIG_${opt} is not set/CONFIG_${opt}=y/" .config || true
    done
    make olddefconfig && make prepare -j"$(nproc)" && make modules_prepare -j"$(nproc)" || warn "yeniden hazırlama başarısız"
    info "Tekrar DKMS derlemesi deneniyor..."
    if sudo dkms build -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" 2>&1 | tee -a "${BUILD_LOG}"; then
      ok "İkinci deneme başarılı!"
    else
      err "Semboller yine eksik. WSL2 çekirdeği modül geliştirmeyi desteklemiyor."
      echo
      warn "❌ Çözüm: Gerçek Linux kernel’inde veya özel derlenmiş WSL2 kernel’inde yeniden deneyin."
      echo "🧩 İpucu: https://github.com/microsoft/WSL2-Linux-Kernel adresinden 'make menuconfig' ile"
      echo "          NETWORK ve WIRELESS modüllerini aktif ederek özel kernel derleyebilirsiniz."
      exit 2
    fi
  fi
fi

# --- DKMS install ---
info "DKMS install çalıştırılıyor..."
sudo dkms install -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" || warn "Install sırasında uyarı oluştu."
sudo depmod -a

# --- Modül yükleme ---
info "Modül yükleniyor: 8821cu"
if sudo modprobe 8821cu 2>/dev/null; then
  ok "modprobe 8821cu başarılı"
else
  warn "modprobe başarısız, manuel insmod deneniyor..."
  KO_PATH=$(find /lib/modules/"${KVER}" -name "8821cu*.ko" | head -n1)
  [ -n "$KO_PATH" ] && sudo insmod "$KO_PATH" && ok "insmod başarılı" || err "8821cu.ko bulunamadı"
fi

# --- Log + sonuç ---
info "dmesg (rtl8821 ilgili satırlar):"
sudo dmesg | grep -i rtl | tail -n 20 || true

ok "Kurulum tamamlandı ✅ Loglar: ${LOGDIR}"
echo
ok "Windows tarafında bağlamak için:"
echo "  usbipd.exe list"
echo "  usbipd.exe attach --busid <BUSID> --wsl"
echo
ok "Bağlantı sonrası test:"
echo "  lsusb && dmesg | tail -n 20"
