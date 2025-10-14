#!/usr/bin/env python3
# ============================================================================
# ai_helper.py - DKMS/Kernel Build AI Analyzer & Auto-Fixer
# Author: ZNUZHG ONYVXPV
# Version: v4.0 auto-repair edition (2025-10-15)
# ============================================================================

import argparse
import os
import re
import subprocess
import sys
from datetime import datetime

PATTERNS = [
    (re.compile(r"flex: not found", re.I), "flex"),
    (re.compile(r"bison: not found", re.I), "bison"),
    (re.compile(r"fatal error: (.+?): No such file or directory", re.I), "missing_header"),
    (re.compile(r"Unable to locate package linux-headers", re.I), "missing_headers_pkg"),
    (re.compile(r"modpost: .*undefined!", re.I), "undefined_symbols"),
    (re.compile(r"undefined reference to `(.*?)'", re.I), "undefined_symbols"),
    (re.compile(r"modprobe: FATAL: Module 8821cu not found", re.I), "missing_module"),
]

HEADER_HINTS = {
    "linux/usb.h": "linux-libc-dev",
    "linux/module.h": "linux-headers",
    "openssl": "libssl-dev",
    "elf.h": "libelf-dev",
}

def run(cmd):
    print(f"\033[1;34m[CMD]\033[0m {cmd}")
    result = subprocess.run(cmd, shell=True, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout)
    return result.stdout.strip()

def apt_install(pkg):
    print(f"\033[1;33m[PKG]\033[0m {pkg} yükleniyor...")
    run(f"sudo apt install -y {pkg}")

def repair_action(tag, match=None):
    if tag == "flex":
        apt_install("flex")
    elif tag == "bison":
        apt_install("bison")
    elif tag == "missing_headers_pkg":
        print("⚙️ linux-headers bulunamadı, WSL kernel kaynakları hazırlanıyor...")
        run("cd ~/WSL2-Linux-Kernel && sudo make prepare -j$(nproc) && sudo make modules_prepare -j$(nproc)")
    elif tag == "missing_header" and match:
        header = match.group(1)
        for key, pkg in HEADER_HINTS.items():
            if key in header:
                apt_install(pkg)
                break
        else:
            print(f"ℹ️ Bilinmeyen header: {header}")
    elif tag == "undefined_symbols":
        print("⚠️ Undefined semboller algılandı, sembol tablosu yenileniyor...")
        run("cd ~/WSL2-Linux-Kernel && sudo make modules_prepare -j$(nproc)")
    elif tag == "missing_module":
        print("⚙️ Modül bulunamadı, manuel yükleme deneniyor...")
        run("sudo find /lib/modules/$(uname -r) -name '8821cu*.ko' -exec sudo insmod {} \\;")
    else:
        print(f"ℹ️ Otomatik çözüm uygulanmadı: {tag}")

def analyze_log(log_text):
    fixes = []
    for pat, tag in PATTERNS:
        for m in pat.finditer(log_text):
            fixes.append((tag, m))
    return fixes

def main():
    parser = argparse.ArgumentParser(description="AI-Assisted DKMS Log Analyzer & Auto-Fixer")
    parser.add_argument("--log", "-l", required=True, help="DKMS/build log dosyası")
    parser.add_argument("--auto", "-a", action="store_true", help="Onarım işlemlerini otomatik uygula (sormadan)")
    parser.add_argument("--out", "-o", help="Rapor dosyası")
    args = parser.parse_args()

    if not os.path.exists(args.log):
        print(f"\033[1;31m[-]\033[0m Log bulunamadı: {args.log}")
        sys.exit(1)

    with open(args.log, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    issues = analyze_log(content)
    if not issues:
        print("✅ Bilinen hata paterni bulunamadı.")
        sys.exit(0)

    print(f"\n\033[1;34m=== {len(issues)} hata tespit edildi, analiz başlıyor... ===\033[0m\n")

    for tag, match in issues:
        print(f"🔍 [{tag}] {match.group(0)[:120]}")
        if args.auto:
            repair_action(tag, match)
        else:
            ans = input(f"⚙️ '{tag}' hatası için otomatik düzeltme yapılsın mı? [Y/n]: ").strip().lower()
            if ans in ("y", "yes", ""):
                repair_action(tag, match)

    report = "\n".join(f"[{t}] {m.group(0)}" for t, m in issues)
    summary = f"\n🧠 AI AUTO-REPAIR REPORT — {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n{report}\n"

    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(summary)
        print(f"\n📄 Rapor kaydedildi: {args.out}")

    print("\n✅ Onarım tamamlandı. Şimdi tekrar 'rtl8821cu_wsl_fix.sh' çalıştırabilirsiniz.")

if __name__ == "__main__":
    main()
