#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Kapi Money (咔皮记账 iOS Native Clone) - WSL2 + xtool One-Command Build Script
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> [1/3] Checking Swift & xtool environment..."
if ! command -v swift >/dev/null 2>&1; then
  echo "Error: 'swift' not found in PATH. Install Swift 6 toolchain in WSL2 Ubuntu first:"
  echo "  curl -O https://download.swift.org/swiftly/linux/swiftly-\$(uname -m).tar.gz && tar zxf swiftly-*.tar.gz && ./swiftly init"
  exit 1
fi

if ! command -v xtool >/dev/null 2>&1; then
  echo "Error: 'xtool' not found in PATH. Install xtool in WSL2 Ubuntu:"
  echo "  Refer to https://github.com/xtool-org/xtool"
  exit 1
fi

cd "${PROJECT_DIR}"

echo "==> [2/3] Running KapiMoneyCore XCTest suite..."
swift test

echo "==> [3/3] Building & installing KapiMoneyApp via xtool..."
xtool dev
