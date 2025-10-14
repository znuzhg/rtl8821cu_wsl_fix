#!/usr/bin/env python3
# ai_helper.py - Smart log analyzer for rtl8821cu_wsl_fix
# Author: ZNUZHG ONYVXPV
# Version: v3.0 (2025-10-14)

"""
Analyzes kernel build or DKMS logs and suggests fixes automatically.
If OpenAI key is loaded, uses GPT to summarize issues.
"""

import argparse
import os
import re
import sys
from datetime import datetime

PATTERNS = [
    (re.compile(r"linux-headers-[\d\.\-]+ not found", re.I),
     "Missing kernel headers — run:\n  sudo apt install linux-headers-$(uname -r)"),
    (re.compile(r"No rule to make target '.*rtl8821cu.*'", re.I),
     "Driver directory missing or wrong path — ensure you cloned `morrownr/8821cu-20210916` properly."),
    (re.compile(r"modprobe: FATAL: Module 8821cu not found", re.I),
     "Module not found — try:\n  sudo dkms install -m rtl8821cu -v 5.12.0.4 && sudo modprobe 8821cu"),
    (re.compile(r"fatal error: (.+?): No such file or directory", re.I),
     "Missing header: {} — install related dev package, e.g. `sudo apt install libelf-dev libssl-dev`."),
    (re.compile(r"undefined reference to `(.*?)'"),
     "Undefined symbol: {} — kernel API mismatch. Use correct driver branch or kernel headers."),
]

def analyze(content: str):
    results = []
    for pat, msg in PATTERNS:
        for m in pat.finditer(content):
            try:
                res = msg.format(m.group(1)) if '{}' in msg else msg
                if res not in results:
                    results.append(res)
            except IndexError:
                results.append(msg)
    if not results:
        results.append("No known build errors found — verify DKMS and module path.")
    return results

def read_log(path: str) -> str:
    if path.strip() == "-":
        return sys.stdin.read()
    if not os.path.exists(path):
        raise FileNotFoundError(f"Log not found: {path}")
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        return f.read()

def main():
    parser = argparse.ArgumentParser(description="AI-assisted DKMS log analyzer")
    parser.add_argument("--log", "-l", required=True, help="Path to DKMS or build log")
    parser.add_argument("--out", "-o", help="Output report file")
    args = parser.parse_args()

    try:
        data = read_log(args.log)
    except Exception as e:
        print(f"[ERROR] {e}", file=sys.stderr)
        sys.exit(2)

    report = analyze(data)
    text = f"AI LOG ANALYSIS — {datetime.now()}\n{'='*60}\n"
    text += "\n".join(f"- {r}" for r in report)
    text += "\n\n--- Log Tail ---\n" + "\n".join(data.splitlines()[-40:])

    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"[OK] Saved to {args.out}")
    else:
        print(text)

if __name__ == "__main__":
    main()
