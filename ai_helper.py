#!/usr/bin/env python3
# ============================================================================
<<<<<<< HEAD
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
=======
# ai_helper.py - DKMS/Kernel Build AI Analyzer & Auto-Fixer (v4.1)
# Author: ZNUZHG ONYVXPV + assistant (2025-10-15)
# - safer subprocess usage
# - supports globs / multiple input logs
# - prints recommended commands, performs safe fixes with --auto
# - writes short report
# ============================================================================

import argparse
import glob
import os
import re
import shlex
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

# Patterns -> tag
PATTERNS = [
    (re.compile(r"\bflex: not found\b", re.I), "flex"),
    (re.compile(r"\bbison: not found\b", re.I), "bison"),
    (re.compile(r"fatal error: ([\w\/\.\-]+): No such file or directory", re.I), "missing_header"),
    (re.compile(r"Unable to locate package linux-headers", re.I), "missing_headers_pkg"),
    (re.compile(r"modpost: .*undefined!", re.I), "undefined_symbols"),
    (re.compile(r"undefined reference to `([^']+)'", re.I), "undefined_symbols"),
    (re.compile(r"modprobe: FATAL: Module (\S+) not found", re.I), "missing_module"),
    (re.compile(r"error:.*unknown.*", re.I), "generic_error"),
]

# hints for header -> package recommendation (best-effort)
HEADER_HINTS = {
    "linux/usb.h": "linux-libc-dev",
    "linux/module.h": "linux-headers-$(uname -r)",
    "openssl": "libssl-dev",
    "elf.h": "libelf-dev",
    "pci.h": "libpci-dev",
}

# package installer (safe)
APT_CMD = shutil.which("apt") or shutil.which("apt-get")

def run(cmd, check=False, capture=True, shell=False):
    """
    Run subprocess; cmd should be list unless shell=True.
    Returns (returncode, stdout+stderr).
    """
    if isinstance(cmd, (list, tuple)):
        popen_cmd = cmd
    else:
        popen_cmd = cmd if shell else shlex.split(cmd)

    try:
        if capture:
            result = subprocess.run(popen_cmd, check=check, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, shell=shell)
            return result.returncode, result.stdout
        else:
            result = subprocess.run(popen_cmd, check=check, shell=shell)
            return result.returncode, ""
    except subprocess.CalledProcessError as e:
        return e.returncode, getattr(e, "output", "") or ""

def apt_install(pkg):
    if not APT_CMD:
        print(f"[PKG] apt not found, cannot auto-install {pkg}")
        return False
    print(f"[PKG] attempting to install: {pkg}")
    code, out = run([APT_CMD, "install", "-y", pkg])
    print(out)
    return code == 0

def safe_suggest(cmd):
    print(f"[SUGGEST] {cmd}")

def repair_action(tag, match=None, auto=False):
    """
    Perform or suggest a repair action for `tag`.
    If auto is True attempt to run apt installs or make prepare steps.
    """
    if tag == "flex":
        if auto:
            return apt_install("flex")
        safe_suggest("sudo apt install -y flex")
        return None
    if tag == "bison":
        if auto:
            return apt_install("bison")
        safe_suggest("sudo apt install -y bison")
        return None
    if tag == "missing_headers_pkg":
        safe_suggest("Install kernel headers or run: cd ~/WSL2-Linux-Kernel && sudo make prepare && sudo make modules_prepare")
        if auto:
            # Try prepare if kernel source exists
            ksrc = Path.home() / "WSL2-Linux-Kernel"
            if ksrc.exists():
                cmd = ["bash", "-lc", "cd ~/WSL2-Linux-Kernel && sudo make prepare -j$(nproc) && sudo make modules_prepare -j$(nproc)"]
                return run(cmd, shell=True)[0] == 0
            return False
        return None
    if tag == "missing_header" and match:
        header = match.group(1)
        # try best match
        for key, pkg in HEADER_HINTS.items():
            if key in header:
                if auto:
                    # some entries may contain $(uname -r); expand
                    pkg_eval = pkg.replace("$(uname -r)", run("uname -r")[1].strip())
                    return apt_install(pkg_eval)
                safe_suggest(f"sudo apt install -y {pkg}")
                return None
        safe_suggest(f"Header {header} missing; search package that provides it (apt-file search {header})")
        return None
    if tag == "undefined_symbols":
        safe_suggest("Undefined symbols in module build — try: cd ~/WSL2-Linux-Kernel && sudo make modules_prepare && ensure CONFIG options present")
        if auto:
            ksrc = Path.home() / "WSL2-Linux-Kernel"
            if ksrc.exists():
                return run(["bash", "-lc", "cd ~/WSL2-Linux-Kernel && sudo make modules_prepare -j$(nproc)"], shell=True)[0] == 0
        return None
    if tag == "missing_module" and match:
        mod = match.group(1)
        safe_suggest(f"sudo find /lib/modules/$(uname -r) -name '{mod}*.ko' -exec sudo insmod {{}} \\;")
        if auto:
            code, out = run(["bash", "-lc", f"sudo find /lib/modules/$(uname -r) -name '{mod}*.ko' -exec sudo insmod {{}} \\;"], shell=True)
            print(out)
            return code == 0
        return None
    if tag == "generic_error":
        if match:
            safe_suggest(f"Investigate error: {match.group(0)}")
        return None
    safe_suggest(f"No automated fix for tag: {tag}")
    return None

def analyze_log(text):
    findings = []
    for pat, tag in PATTERNS:
        for m in pat.finditer(text):
            findings.append((tag, m))
    return findings

def expand_logs(path_pattern):
    # Expand globs; if single file path, return list
    expanded = []
    for p in glob.glob(path_pattern):
        if os.path.isfile(p):
            expanded.append(p)
    return sorted(set(expanded))

def main():
    p = argparse.ArgumentParser(prog="ai_helper.py", description="DKMS/Build log analyzer + safe fixer")
    p.add_argument("--log", "-l", required=True, help="Log file path or glob (e.g. ~/logs/*.log)")
    p.add_argument("--auto", "-a", action="store_true", help="Automatically apply fixes (non-interactive)")
    p.add_argument("--out", "-o", help="Write short report to file")
    args = p.parse_args()

    logs = expand_logs(os.path.expanduser(args.log))
    if not logs:
        print(f"[-] No logs found for: {args.log}")
        sys.exit(1)

    all_issues = []
    for log in logs:
        print(f"\n[ANALYZE] Reading: {log}")
        try:
            with open(log, "r", encoding="utf-8", errors="ignore") as f:
                txt = f.read()
        except Exception as e:
            print(f"[-] Cannot read {log}: {e}")
            continue

        issues = analyze_log(txt)
        if not issues:
            print("[OK] No known patterns found in this log.")
            continue

        print(f"[FOUND] {len(issues)} potential issue(s) in {Path(log).name}")
        for tag, match in issues:
            snippet = (match.group(0)[:200] + "...") if match and len(match.group(0)) > 200 else (match.group(0) if match else "")
            print(f" - {tag}: {snippet}")
            all_issues.append((log, tag, snippet))
            if args.auto:
                print(f"[AUTO] attempting fix for {tag} ...")
                try:
                    ok = repair_action(tag, match, auto=True)
                    print("[AUTO] OK" if ok else "[AUTO] No change / failed")
                except Exception as e:
                    print(f"[AUTO] Exception during repair: {e}")
            else:
                resp = input(f"Apply suggested action for '{tag}'? [y/N]: ").strip().lower()
                if resp in ("y", "yes"):
                    repair_action(tag, match, auto=False)

    # report
    report_lines = [
        f"AI_HELPER REPORT - {datetime.now().isoformat()}",
        f"Analyzed: {', '.join(Path(x).name for x in logs)}",
        ""
    ]
    if all_issues:
        for log, tag, snippet in all_issues:
            report_lines.append(f"[{Path(log).name}] {tag}: {snippet}")
    else:
        report_lines.append("No known issues detected.")

    report = "\n".join(report_lines)
    print("\n" + report)

    if args.out:
        try:
            with open(args.out, "w", encoding="utf-8") as f:
                f.write(report)
            print(f"[+] Report saved to {args.out}")
        except Exception as e:
            print(f"[-] Could not write report: {e}")

    print("\n[+] Done. If fixes were applied, retry the build process (rtl8821cu_wsl_fix.sh).")
>>>>>>> f60bbde (fully automated WSL2 driver installer)

if __name__ == "__main__":
    main()
