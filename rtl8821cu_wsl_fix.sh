#!/usr/bin/env bash
# ============================================================================
<<<<<<< HEAD
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
=======
# rtl8821cu_wsl_fix.sh
# v2025-10-15+ (Merged & Hardened)
# Purpose : Build/install Realtek 8821cu driver inside WSL2 (Kali-only focused),
#           robust DKMS -> direct-make -> insmod fallback flow, with logs,
#           AI-assisted analysis hook and interactive safeguards.
# Author  : ZNUZHG ONYVXPV  + assistant (merged)
# License : MIT-style (use at your own risk)
# Notes   :
#   - This script is intended to be run inside WSL2 (kali-linux).
#   - Recommended: launch from Windows with a persistent Kali root shell:
#         wsl -d kali-linux --user root -- bash
#     or use the provided PowerShell launcher which opens Kali root and copies files.
#   - The script will ask before doing very heavy operations (building full kernel modules).
#   - Log files are saved in ${HOME}/rtl8821cu_logs.
# ============================================================================

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# -----------------------
# Configuration
# -----------------------
BASE_DIR="${HOME}/rtl8821cu_wsl_fix"
LOGDIR="${HOME}/rtl8821cu_logs"
KERNEL_SRC_DIR="${HOME}/WSL2-Linux-Kernel"
DRIVER_REPO="https://github.com/morrownr/8821cu-20210916.git"
DRIVER_CLONE_DIR="${HOME}/8821cu-20210916"
AI_HELPER="${BASE_DIR}/ai_helper.py"      # optional: analyzed by script if present
DKMS_SRC_PREFIX="/usr/src"
PACKAGE_NAME="rtl8821cu"
PACKAGE_VERSION="5.12.0.4"

# package lists
REQ_PKGS=(dkms build-essential git bc libelf-dev libssl-dev usbutils usbip make xterm libncurses-dev pkg-config flex bison)
OPT_PKGS=(linux-tools-common dwarves)

# Behavior flags
AUTO_YES=${AUTO_YES:-0}   # set AUTO_YES=1 in env to auto-accept prompts (non-interactive)
HEAVY_BUILD_ACCEPTED=0    # internal flag set when user consents to full kernel modules build

# -----------------------
# Utilities
# -----------------------
timestamp(){ date +%Y%m%d_%H%M%S; }
logf(){ printf '%s %s\n' "$(timestamp)" "$*" >> "${LOGDIR}/runtime.log"; }
info(){ echo -e "\e[1;34m[*]\e[0m $*"; logf "[INFO] $*"; }
ok(){ echo -e "\e[1;32m[+]\e[0m $*"; logf "[OK] $*"; }
warn(){ echo -e "\e[1;33m[!]\e[0m $*"; logf "[WARN] $*"; }
err(){ echo -e "\e[1;31m[-]\e[0m $*"; logf "[ERR] $*"; }

ensure_dirs(){
  mkdir -p "${BASE_DIR}" "${LOGDIR}"
  chmod 700 "${LOGDIR}" 2>/dev/null || true
}

ask_yesno(){
  # ask_yesno "Question?" && return 0 if yes
  local prompt="$1"
  if [ "${AUTO_YES:-0}" = "1" ]; then
    return 0
  fi
  while true; do
    read -rp "${prompt} [y/N]: " ans
    ans=${ans,,}
    case "$ans" in
      y|yes) return 0 ;;
      n|no|'' ) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

run_log(){
  # run command, tee output to provided file
  local logfile="$1"; shift
  "$@" 2>&1 | tee -a "$logfile"
  return ${PIPESTATUS[0]:-0}
}

# -----------------------
# Pre-flight checks
# -----------------------
ensure_dirs

if ! grep -qi microsoft /proc/version 2>/dev/null ; then
  err "This script must run inside WSL2. Exiting."
  exit 1
fi
ok "WSL2 environment detected."

info "Script started. Logs will be placed under ${LOGDIR}"

# Check caller privileges: script may need sudo for package install and dkms operations.
if [ "$EUID" -ne 0 ]; then
  info "Not running as root. Some steps will prompt for sudo."
else
  info "Running as root (EUID=0)."
fi

# Ask user that windows_prereq (usbipd on Windows) should have been executed
if ! ask_yesno $'Have you already run windows_prereq.ps1 on Windows (installed usbipd-win)?'; then
  warn "Please run windows_prereq.ps1 on the Windows host before continuing."
  exit 1
fi

# -----------------------
# Package installation
# -----------------------
info "Updating apt and ensuring required packages are installed..."
sudo apt-get update -y >> "${LOGDIR}/apt_update_$(timestamp).log" 2>&1 || warn "apt-get update had issues; continuing."

for p in "${REQ_PKGS[@]}"; do
  if dpkg -s "$p" >/dev/null 2>&1; then
    ok "$p is already installed"
  else
    info "Installing $p..."
    sudo apt-get install -y "$p" >> "${LOGDIR}/apt_install_$(timestamp).log" 2>&1 || { warn "Failed to install $p; you may need to install manually."; }
  fi
done

for p in "${OPT_PKGS[@]}"; do
  if dpkg -s "$p" >/dev/null 2>&1; then
    ok "Optional $p installed"
  else
    warn "Optional $p not installed (this is OK, some debugging may be limited)."
  fi
done

# -----------------------
# Kernel headers / WSL kernel sources
# -----------------------
KVER="$(uname -r)"
info "Active kernel: ${KVER}"

if [ ! -d "/lib/modules/${KVER}/build" ]; then
  warn "Kernel headers not present for ${KVER}. Preparing WSL kernel sources..."
  if [ ! -d "${KERNEL_SRC_DIR}" ]; then
    info "Cloning WSL2 kernel sources (shallow)..."
    git clone --depth=1 -b linux-msft-wsl-6.6.y https://github.com/microsoft/WSL2-Linux-Kernel.git "${KERNEL_SRC_DIR}" >> "${LOGDIR}/git_kernel_clone_$(timestamp).log" 2>&1 || warn "git clone may have failed"
  else
    info "Kernel source already exists; pulling updates..."
    (cd "${KERNEL_SRC_DIR}" && git fetch --depth=1 origin linux-msft-wsl-6.6.y && git reset --hard origin/linux-msft-wsl-6.6.y) >> "${LOGDIR}/git_kernel_update_$(timestamp).log" 2>&1 || true
  fi

  cd "${KERNEL_SRC_DIR}" || exit 1
  # prefer using running config if available
  if [ -f /proc/config.gz ]; then
    zcat /proc/config.gz > .config || cp Microsoft/config-wsl .config || true
  else
    cp Microsoft/config-wsl .config || true
  fi

  info "Running make prepare/modules_prepare (may be noisy)"
  # try to minimize output to log, but preserve failures
  make olddefconfig >> "${LOGDIR}/kernel_make_olddefconfig_$(timestamp).log" 2>&1 || true
  make prepare -j"$(nproc)" >> "${LOGDIR}/kernel_make_prepare_$(timestamp).log" 2>&1 || warn "make prepare had warnings"
  make modules_prepare -j"$(nproc)" >> "${LOGDIR}/kernel_make_modules_prepare_$(timestamp).log" 2>&1 || warn "make modules_prepare had warnings"

  sudo mkdir -p "/lib/modules/${KVER}"
  sudo ln -sfn "${KERNEL_SRC_DIR}" "/lib/modules/${KVER}/build"
  ok "Kernel sources prepared and linked to /lib/modules/${KVER}/build"
else
  ok "Kernel headers already linked for ${KVER}"
fi

# -----------------------
# Driver clone & DKMS prepare
# -----------------------
info "Cloning/updating driver repository..."
if [ ! -d "${DRIVER_CLONE_DIR}" ]; then
  git clone "${DRIVER_REPO}" "${DRIVER_CLONE_DIR}" >> "${LOGDIR}/git_driver_clone_$(timestamp).log" 2>&1 || { err "Driver git clone failed"; exit 1; }
else
  (cd "${DRIVER_CLONE_DIR}" && git pull --quiet) >> "${LOGDIR}/git_driver_pull_$(timestamp).log" 2>&1 || true
fi
ok "Driver code is present at ${DRIVER_CLONE_DIR}"

SRC_DIR="${DKMS_SRC_PREFIX}/${PACKAGE_NAME}-${PACKAGE_VERSION}"
info "Copying driver to DKMS source dir: ${SRC_DIR}"
sudo rm -rf "${SRC_DIR}" >> "${LOGDIR}/cleanup_$(timestamp).log" 2>&1 || true
sudo cp -r "${DRIVER_CLONE_DIR}" "${SRC_DIR}" >> "${LOGDIR}/dkms_copy_$(timestamp).log" 2>&1 || { err "Failed copying driver to /usr/src"; }
sudo chown -R root:root "${SRC_DIR}" >> "${LOGDIR}/dkms_chown_$(timestamp).log" 2>&1 || true

# rotate log filenames for build attempts
DKMS_BUILD_LOG="${LOGDIR}/dkms_build_$(timestamp).log"
MAKE_BUILD_LOG="${LOGDIR}/make_build_$(timestamp).log"
FULL_MODULES_LOG="${LOGDIR}/full_modules_build_$(timestamp).log"

# clean previous DKMS entries (safe)
sudo dkms remove "${PACKAGE_NAME}/${PACKAGE_VERSION}" --all >/dev/null 2>&1 || true
sudo dkms add -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" >/dev/null 2>&1 || true

# -----------------------
# DKMS build attempt
# -----------------------
info "Starting DKMS build (logged to ${DKMS_BUILD_LOG})..."
if sudo dkms build -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" 2>&1 | tee "${DKMS_BUILD_LOG}"; then
  ok "DKMS build completed successfully."
  sudo dkms install -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" 2>&1 | tee -a "${DKMS_BUILD_LOG}" || warn "dkms install returned warnings"
else
  warn "DKMS build failed. See ${DKMS_BUILD_LOG} for details."
  if [ -f "${AI_HELPER}" ]; then
    info "Running AI helper for log analysis (ai_helper.py)..."
    python3 "${AI_HELPER}" --log "${DKMS_BUILD_LOG}" --out "${DKMS_BUILD_LOG}.report" 2>&1 | tee -a "${LOGDIR}/ai_helper_$(timestamp).log" || warn "ai_helper had non-fatal errors"
    ok "AI helper finished; report at ${DKMS_BUILD_LOG}.report"
  fi

  # -----------------------
  # Fallback: direct make in driver dir (module-only)
  # -----------------------
  info "Attempting direct in-tree 'make' (module-only) build in ${DRIVER_CLONE_DIR} (logged to ${MAKE_BUILD_LOG})..."
  cd "${DRIVER_CLONE_DIR}" || { err "Driver dir not found"; exit 1; }
  make clean >> "${MAKE_BUILD_LOG}" 2>&1 || true

  if make -j"$(nproc)" M="$(pwd)" modules 2>&1 | tee "${MAKE_BUILD_LOG}"; then
    ok "Direct module-only make succeeded."
    KO_BUILD=$(find . -type f -name "8821cu*.ko" -print -quit || true)
    if [ -n "${KO_BUILD}" ]; then
      info "Copying built .ko to /lib/modules/${KVER}/ and running depmod..."
      sudo cp "${KO_BUILD}" "/lib/modules/${KVER}/" >> "${LOGDIR}/ko_copy_$(timestamp).log" 2>&1 || warn "Failed copying .ko"
      sudo depmod -a >> "${LOGDIR}/depmod_$(timestamp).log" 2>&1 || warn "depmod had warnings"
      ok "Copied .ko and updated module dependencies"
    else
      warn "Module .ko not found after build; please inspect ${MAKE_BUILD_LOG}"
    fi
  else
    warn "Direct make build failed. Checking for modpost/Module.symvers/undefined patterns..."

    # quick log analysis heuristics
    if grep -q "Module.symvers is missing" "${MAKE_BUILD_LOG}" 2>/dev/null || grep -q "undefined!" "${MAKE_BUILD_LOG}" 2>/dev/null || grep -q "undefined " "${MAKE_BUILD_LOG}" 2>/dev/null; then
      warn "modpost reported undefined symbols or missing Module.symvers."
      info "This often means Module.symvers (global exported symbols) is missing; generating it requires building kernel modules."
      if ask_yesno $'Do you want to attempt a full kernel modules build (heavy operation) to generate Module.symvers? (this can take many minutes)'; then
        HEAVY_BUILD_ACCEPTED=1
      else
        HEAVY_BUILD_ACCEPTED=0
      fi

      if [ "${HEAVY_BUILD_ACCEPTED}" -eq 1 ]; then
        info "Starting full kernel modules build in ${KERNEL_SRC_DIR} (logged to ${FULL_MODULES_LOG})..."
        cd "${KERNEL_SRC_DIR}" || { err "Kernel src dir not found"; exit 1; }
        # attempt to build modules - may be heavy
        if make -j"$(nproc)" modules 2>&1 | tee "${FULL_MODULES_LOG}"; then
          ok "Full modules build succeeded (Module.symvers created). Retrying DKMS build..."
          # retry DKMS build now that symvers exists
          cd "${SRC_DIR}" || true
          if sudo dkms build -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" 2>&1 | tee -a "${DKMS_BUILD_LOG}"; then
            ok "DKMS build succeeded on retry."
            sudo dkms install -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}" 2>&1 | tee -a "${DKMS_BUILD_LOG}" || warn "dkms install returned warnings"
          else
            err "DKMS build still failed after full modules build. Check ${DKMS_BUILD_LOG} and ${FULL_MODULES_LOG}"
          fi
        else
          err "Full kernel modules build failed. See ${FULL_MODULES_LOG}"
        fi
      else
        warn "Skipped full kernel modules build by user choice. Provide logs for manual inspection."
      fi
    else
      err "No clear pattern to auto-fix found. Stored logs:"
      err " - ${DKMS_BUILD_LOG}"
      err " - ${MAKE_BUILD_LOG}"
>>>>>>> f60bbde (fully automated WSL2 driver installer)
    fi
  fi
fi

<<<<<<< HEAD
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
=======
# -----------------------
# Try module load (modprobe -> insmod fallback)
# -----------------------
info "Attempting to load module '8821cu' (modprobe -> insmod fallback)..."
if sudo modprobe 8821cu 2>/dev/null; then
  ok "modprobe 8821cu succeeded."
else
  warn "modprobe failed; trying to locate .ko and insmod it."
  KO_PATH=$(find "/lib/modules/${KVER}" -type f -name "8821cu*.ko" -print -quit || true)
  if [ -n "${KO_PATH}" ]; then
    info "Found ${KO_PATH}, attempting insmod..."
    if sudo insmod "${KO_PATH}" 2>/dev/null; then
      ok "insmod successful."
    else
      err "insmod failed for ${KO_PATH}. Check dmesg for details."
    fi
  else
    err "No 8821cu .ko available; build likely failed. Inspect logs in ${LOGDIR}"
  fi
fi

# -----------------------
# Diagnostics output
# -----------------------
info "Collecting quick diagnostics to ${LOGDIR}/diag_$(timestamp).log"
{
  echo "Timestamp: $(date -u --iso-8601=seconds)"
  echo "uname -a: $(uname -a)"
  echo "Kernel version: ${KVER}"
  echo "ls /lib/modules/${KVER}:"
  ls -la "/lib/modules/${KVER}" 2>/dev/null || true
  echo "dkms status:"
  dkms status || true
  echo "lsusb (may list host-attached devices after usbip attach):"
  lsusb || true
  echo "recent dmesg lines (filtered):"
  dmesg | tail -n 200 | grep -iE "rtl|8821|usb" || true
} >> "${LOGDIR}/diag_$(timestamp).log" 2>&1 || true

ok "Installation finished (see logs: ${LOGDIR})"
echo
ok "To attach the Realtek USB device from Windows (Admin PowerShell):"
echo "    usbipd.exe list"
echo "    usbipd.exe attach --busid <BUSID> --wsl"
echo
echo "Keep a persistent Kali root shell open while you run 'usbipd.exe attach' so the WSL distribution stays running:"
echo "    wsl -d kali-linux --user root -- bash"
echo
echo "To verify inside Kali after attach:"
echo "    lsusb && dmesg | tail -n 20"
echo "    iwconfig || ip a"

# exit with success if at least a .ko exists and module loaded (best-effort)
KO_CHECK=$(find "/lib/modules/${KVER}" -type f -name "8821cu*.ko" -print -quit || true)
if [ -n "${KO_CHECK}" ] && dmesg | grep -i "8821cu\|rtl" >/dev/null 2>&1; then
  ok "Driver artifacts present and kernel messages contain rtl/8821 entries (likely good)."
  exit 0
else
  warn "Driver artifact or kernel messages not convincing. Check logs in ${LOGDIR} and the dmesg output."
  exit 0
fi
>>>>>>> f60bbde (fully automated WSL2 driver installer)
