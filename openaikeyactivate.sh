#!/usr/bin/env bash
# openaikeyactivate.sh - Load and persist OpenAI API key
# Author: ZNUZHG ONYVXPV
# Version: v3.0

CONF_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/openai_key.conf"

if [ ! -f "$CONF_FILE" ]; then
  echo "openai_key.conf not found. Creating new one..."
  read -rp "Enter your OpenAI API key (starts with sk-): " key
  echo "OPENAI_API_KEY=${key}" > "$CONF_FILE"
fi

set -a
. "$CONF_FILE"
set +a

if [ -z "$OPENAI_API_KEY" ]; then
  echo "[❌] OPENAI_API_KEY is empty. Please update openai_key.conf."
  exit 1
fi

export OPENAI_API_KEY
grep -q "OPENAI_API_KEY" ~/.bashrc || echo "export OPENAI_API_KEY=${OPENAI_API_KEY}" >> ~/.bashrc

echo "[✅] OpenAI API key loaded successfully."
