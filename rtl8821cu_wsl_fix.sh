#!/usr/bin/env bash
# ============================================================================
# rtl8821cu_wsl_fix.sh
# v2025-10-15+ (Unified, Hardened, Turkish UI)
# Purpose : Robust WSL2 installer/fixer for Realtek 8821cu driver (DKMS / direct-make / fallback)
# Author  : ZNUZHG ONYVXPV + assistant (merged)
# License : MIT-style (use at your own risk)
# Notes   : Designed for Kali-on-WSL2 but generally applicable to WSL2 distributions.
#           Run interactively from a persistent WSL root shell for best results.
# ============================================================================

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# ----------------------- Configuration -----------------------
BASE_DIR="${HOME}/rtl8821cu_wsl_fix"
LOGDIR="${HOME}/rtl8821cu_logs"
KERNEL_SRC_DIR="${HOME}/WSL2-Linux-Kernel"
DRIVER_REPO="https://github.com/morrownr/8821cu-20210916.git"
DRIVER_CLONE_DIR="${HOME}/8821cu-20210916"
AI_HELPER="${BASE_DIR}/ai_helper.py"      # optional
DKMS_SRC_PREFIX="/usr/src"
PACKAGE_NAME="rtl8821cu"
PACKAGE_VERSION="5.12.0.4"

REQ_PKGS=(dkms build-essential git bc libelf-dev libssl-dev usbutils usbip make xterm libncurses-dev pkg-config flex bison)
OPT_PKGS=(linux-tools-common dwarves)

# Behavior flags
AUTO_YES=${AUTO_YES:-0}   # set AUTO_YES=1 to auto-accept prompts (non-interactive)
HEAVY_BUILD_ACCEPTED=0    # set after user consents to full kernel modules build

# ----------------------- Utilities -----------------------
timestamp(){ date +%Y%m%d_%H%M%S; }
logf(){ printf '%s %s\n' "$(timestamp)" "$*" >> "${LOGDIR}/runtime.log"; }
info(){ echo -e "\e[1;34m[*]\e[0m $*"; logf "[INFO] $*"; }
ok(){ echo -e "\e[1;32m[+]\e[0m $*"; logf "[OK] $*"; }
warn(){ echo -e "\e[1;33m[!]\e[0m $*"; logf "[WARN] $*"; }
err(){ echo -e "\e[1;31m[-]\e[0m $*"; logf "[ERR] $*"; }

ensure_dirs(){ mkdir -p "${BASE_DIR}" "${LOGDIR}"; chmod 700 "${LOGDIR}" 2>/dev/null || true; }

ask_yesno(){
  local prompt="$1"
  if [ "${AUTO_YES:-0}" = "1" ]; then return 0; fi
  while true; do
    read -rp "${prompt} [y/N]: " ans
    ans=${ans,,}
    case "$ans" in
      y|yes) return 0 ;;
      n|no|"") return 1 ;;
      *) echo "Lütfen y veya n ile yanıt verin." ;;
    esac
  done
}

run_log(){ local logfile="$1"; shift; "$@" 2>&1 | tee -a "$logfile"; return ${PIPESTATUS[0]:-0}; }

# ----------------------- Pre-flight -----------------------
ensure_dirs

if ! grep -qi microsoft /proc/version 2>/dev/null ; then
  err "Bu betik yalnızca WSL2 ortamında çalıştırılabilir."
  exit 1
fi
ok "WSL2 ortamı doğrulandı."

info "Script started. Loglar: ${LOGDIR}"

if [ "$EUID" -ne 0 ]; then
  info "Root değil. Bazı adımlar sudo isteyebilir."
else
  ok "Root erişimi var (EUID=0)."
fi

if ! ask_yesno $'Windows tarafındaki windows_prereq.ps1 (usbipd kurulumu) çalıştırıldı mı?'; then
  warn "Lütfen önce Windows tarafında windows_prereq.ps1\'i çalıştırın (usbipd-win)."
  exit 1
fi

# ----------------------- Package install -----------------------
info "apt güncelleniyor ve gerekli paketler kontrol ediliyor..."
sudo apt-get update -y >> "${LOGDIR}/apt_update_$(timestamp).log" 2>&1 || warn "apt-get update sırasında uyarı oluştu; devam ediyorum."

for p in "${REQ_PKGS[@]}"; do
  if dpkg -s "$p" >/dev/null 2>&1; then
    ok "$p yüklü"
  else
    info "$p yükleniyor..."
    sudo apt-get install -y "$p" >> "${LOGDIR}/pkg_${p}_$(timestamp).log" 2>&1 || warn "$p yüklenemedi; elle kurmanız gerekebilir."
  fi
done
for p in "${OPT_PKGS[@]}"; do dpkg -s "$p" >/dev/null 2>&1 || warn "Opsiyonel $p yüklü değil (debug sınırlı olabilir)."; done

# ----------------------- Kernel headers / WSL sources -----------------------
KVER="$(uname -r)"
info "Aktif kernel: ${KVER}"

if [ ! -d "/lib/modules/${KVER}/build" ]; then
  warn "Kernel headers/link yok; WSL2 kernel kaynakları hazırlanıyor..."
  if [ ! -d "${KERNEL_SRC_DIR}" ]; then
    info "WSL2 kernel kaynakları klonlanıyor (shallow)..."
    git clone --depth=1 -b linux-msft-wsl-6.6.y https://github.com/microsoft/WSL2-Linux-Kernel.git "${KERNEL_SRC_DIR}" >> "${LOGDIR}/git_kernel_clone_$(timestamp).log" 2>&1 || warn "Kernel clone başarısız olabilir"
  else
    info "Kernel kaynağı mevcut; güncelleniyor..."
    (cd "${KERNEL_SRC_DIR}" && git fetch --depth=1 origin linux-msft-wsl-6.6.y && git reset --hard origin/linux-msft-wsl-6.6.y) >> "${LOGDIR}/git_kernel_update_$(timestamp).log" 2>&1 || true
  fi

  cd "${KERNEL_SRC_DIR}" || { err "Kernel src klasörü bulunamadı"; exit 1; }
  if [ -f /proc/config.gz ]; then
    zcat /proc/config.gz > .config || cp Microsoft/config-wsl .config || true
  else
    cp Microsoft/config-wsl .config || true
  fi

  info "make prepare + modules_prepare çalıştırılıyor (loglanıyor)..."
  make olddefconfig >> "${LOGDIR}/kernel_make_olddefconfig_$(timestamp).log" 2>&1 || true
  make prepare -j"$(nproc)" >> "${LOGDIR}/kernel_make_prepare_$(timestamp).log" 2>&1 || warn "make prepare uyarı"
  make modules_prepare -j"$(nproc)" >> "${LOGDIR}/kernel_make_modules_prepare_$(timestamp).log" 2>&1 || warn "make modules_prepare uyarı"

  sudo mkdir -p "/lib/modules/${KVER}"
  sudo ln -sfn "${KERNEL_SRC_DIR}" "/lib/modules/${KVER}/build"
  ok "Kernel kaynakları hazırlandı ve /lib/modules/${KVER}/build'e bağlandı."
else
  ok "Kernel headers zaten bağlı: /lib/modules/${KVER}/build"
fi

# ----------------------- Driver clone & DKMS prep -----------------------
info "Sürücü deposu klonlanıyor/güncelleniyor..."
if [ ! -d "${DRIVER_CLONE_DIR}" ]; then
  git clone "${DRIVER_REPO}" "${DRIVER_CLONE_DIR}" >> "${LOGDIR}/git_driver_clone_$(timestamp).log" 2>&1 || { err "Driver klonlanamadı"; exit 1; }
else
  (cd "${DRIVER_CLONE_DIR}" && git pull --quiet) >> "${LOGDIR}/git_driver_pull_$(timestamp).log" 2>&1 || true
fi
ok "Driver kodu: ${DRIVER_CLONE_DIR}"

SRC_DIR="${DKMS_SRC_PREFIX}/${PACKAGE_NAME}-${PACKAGE_VERSION}"
info "Driver DKMS dizinine kopyalanıyor: ${SRC_DIR}"
sudo rm -rf "${SRC_DIR}" >> "${LOGDIR}/cleanup_$(timestamp).log" 2>&1 || true
sudo cp -r "${DRIVER_CLONE_DIR}" "${SRC_DIR}" >> "${LOGDIR}/dkms_copy_$(timestamp).log" 2>&1 || { err "Sürücü /usr/src'ye kopyalanamadı"; }
sudo chown -R root:root "${SRC_DIR}" >> "${LOGDIR}/dkms_chown_$(timestamp).log" 2>&1 || true

DKMS_BUILD_LOG="${LOGDIR}/dkms_build_$(timestamp).log"
MAKE_BUILD_LOG="${LOGDIR}/make_build_$(timestamp).log"
FULL_MODULES_LOG="${LOGDIR}/full_modules_build_$(timestamp).log"

sudo dkms remove "${PACKAGE_NAME}/${PACKAGE_VERSION}" --all >/dev/null 2>&1 || true
sudo dkms add -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" >/dev/null 2>&1 || true

# ----------------------- DKMS build attempt -----------------------
info "DKMS build başlatılıyor (log: ${DKMS_BUILD_LOG})..."
if sudo dkms build -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" 2>&1 | tee "${DKMS_BUILD_LOG}"; then
  ok "DKMS build başarıyla tamamlandı."
  sudo dkms install -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" 2>&1 | tee -a "${DKMS_BUILD_LOG}" || warn "dkms install uyarılar üretti"
else
  warn "DKMS build başarısız. ${DKMS_BUILD_LOG} dosyasına bakın."

  if [ -f "${AI_HELPER}" ]; then
    info "AI helper ile log analizi çalıştırılıyor..."
    python3 "${AI_HELPER}" --log "${DKMS_BUILD_LOG}" --out "${DKMS_BUILD_LOG}.report" 2>&1 | tee -a "${LOGDIR}/ai_helper_$(timestamp).log" || warn "ai_helper hata verdi"
    ok "AI raporu: ${DKMS_BUILD_LOG}.report"
  fi

  # Fallback: direct make in driver dir (module-only)
  info "Driver dizininde doğrudan 'make' denemesi (log: ${MAKE_BUILD_LOG})..."
  cd "${DRIVER_CLONE_DIR}" || { err "Driver dizini bulunamadı"; exit 1; }
  make clean >> "${MAKE_BUILD_LOG}" 2>&1 || true

  if make -j"$(nproc)" M="$(pwd)" modules 2>&1 | tee "${MAKE_BUILD_LOG}"; then
    ok "Doğrudan module-only make başarılı."
    KO_BUILD=$(find . -type f -name "8821cu*.ko" -print -quit || true)
    if [ -n "${KO_BUILD}" ]; then
      info "Derlenen .ko kopyalanıyor ve depmod çalıştırılıyor..."
      sudo cp "${KO_BUILD}" "/lib/modules/${KVER}/" >> "${LOGDIR}/ko_copy_$(timestamp).log" 2>&1 || warn ".ko kopyalama başarısız"
      sudo depmod -a >> "${LOGDIR}/depmod_$(timestamp).log" 2>&1 || warn "depmod uyarıları"
      ok ".ko kopyalandı ve depmod çalıştırıldı."
    else
      warn "Derlenen .ko bulunamadı; ${MAKE_BUILD_LOG} dosyasını inceleyin."
    fi
  else
    warn "Doğrudan make başarısız. Loglar inceleniyor..."

    if grep -q "Module.symvers is missing" "${MAKE_BUILD_LOG}" 2>/dev/null || grep -q "undefined" "${MAKE_BUILD_LOG}" 2>/dev/null; then
      warn "modpost/undefined sembol hatası tespit edildi — Module.symvers gerekebilir."
      if ask_yesno $'Module.symvers üretmek için tam kernel modules derlemesini denemek ister misiniz? (Ağır işlem, zaman alabilir)'; then
        HEAVY_BUILD_ACCEPTED=1
      else
        HEAVY_BUILD_ACCEPTED=0
      fi

      if [ "${HEAVY_BUILD_ACCEPTED}" -eq 1 ]; then
        info "Tam kernel modules derlemesi başlatılıyor (log: ${FULL_MODULES_LOG})..."
        cd "${KERNEL_SRC_DIR}" || { err "Kernel kaynak dizini yok"; exit 1; }
        if make -j"$(nproc)" modules 2>&1 | tee "${FULL_MODULES_LOG}"; then
          ok "Full modules build başarılı — Module.symvers oluşturulmuş olabilir. DKMS yeniden deneniyor..."
          cd "${SRC_DIR}" || true
          if sudo dkms build -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" 2>&1 | tee -a "${DKMS_BUILD_LOG}"; then
            ok "DKMS build retry başarılı."
            sudo dkms install -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" 2>&1 | tee -a "${DKMS_BUILD_LOG}" || warn "dkms install uyarı"
          else
            err "DKMS build hala başarısız. ${DKMS_BUILD_LOG} ve ${FULL_MODULES_LOG} dosyalarını inceleyin."
          fi
        else
          err "Full kernel modules build başarısız. ${FULL_MODULES_LOG} dosyasına bakın."
        fi
      else
        warn "Kullanıcı tam kernel build'ini atladı. Elle müdahale veya log paylaşımı gerekebilir."
      fi
    else
      err "Otomatik onarım için net bir kalıp bulunamadı. Logları inceleyin: ${DKMS_BUILD_LOG}, ${MAKE_BUILD_LOG}"
    fi
  fi
fi

# ----------------------- Module load -----------------------
info "Modül yükleniyor (modprobe → insmod fallback)..."
if sudo modprobe 8821cu 2>/dev/null; then
  ok "modprobe 8821cu başarılı."
else
  warn "modprobe başarısız; .ko aranıyor..."
  KO_PATH=$(find "/lib/modules/${KVER}" -type f -name "8821cu*.ko" -print -quit || true)
  if [ -n "${KO_PATH}" ]; then
    info "Bulunan .ko: ${KO_PATH} — insmod deneniyor..."
    if sudo insmod "${KO_PATH}" 2>/dev/null; then
      ok "insmod başarılı."
    else
      err "insmod başarısız. dmesg'i inceleyin."
    fi
  else
    err "8821cu .ko dosyası bulunamadı; derleme başarısız olabilir."
  fi
fi

# ----------------------- Diagnostics -----------------------
info "Tanı (diagnostic) bilgileri toplanıyor..."
{
  echo "=== Diagnostic @ $(date -u --iso-8601=seconds) ==="
  echo "uname -a: $(uname -a)"
  echo "Kernel version: ${KVER}"
  echo "ls /lib/modules/${KVER}:"
  ls -la "/lib/modules/${KVER}" 2>/dev/null || true
  echo "dkms status:"
  dkms status || true
  echo "lsusb:"
  lsusb || true
  echo "dmesg (rtl/8821/usb filtresi):"
  dmesg | tail -n 300 | grep -iE "rtl|8821|usb" || true
} >> "${LOGDIR}/diag_$(timestamp).log" 2>&1 || true

ok "Kurulum tamamlandı. Loglar: ${LOGDIR}"

cat <<'EOF'

Windows tarafında cihazı WSL'e vermek için (PowerShell, Yönetici):

  usbipd.exe list
  usbipd.exe bind --busid <BUSID>
  usbipd.exe attach --busid <BUSID> --wsl <DistributionName>

Örnek (PowerShell):
  usbipd.exe list
  usbipd.exe attach --busid 2-13 --wsl kali-linux

Kali içinde test:
  lsusb && dmesg | tail -n 20
  iwconfig || ip a
  ip link set wlan0 up

EOF

# Exit code: 0 (best-effort). Check ${LOGDIR} for full details.
exit 0
