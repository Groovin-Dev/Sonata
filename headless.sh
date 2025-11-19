#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
MODULE_CACHE="$BUILD_DIR/module-cache"
HOME_DIR="$BUILD_DIR/home"

mkdir -p "$MODULE_CACHE" "$HOME_DIR/Library/Caches"

if [[ -z "${HYPEM_USERNAME:-}" || -z "${HYPEM_PASSWORD:-}" ]]; then
  cat <<'EOF' >&2
Missing env vars. Set:
  HYPEM_USERNAME=your_username
  HYPEM_PASSWORD=your_password
Optional:
  HYPEM_DEVICE_ID=hex_device_id
  HYPEM_API_KEY=override_api_key
EOF
  exit 1
fi

echo "Building headless probe..."
swiftc -parse-as-library -module-cache-path "$MODULE_CACHE" "$ROOT_DIR/Tools/AuthProbe.swift" -o "$BUILD_DIR/authprobe"

echo "Running headless probe..."
HOME="$HOME_DIR" \
CFFIXED_USER_HOME="$HOME_DIR" \
XDG_CACHE_HOME="$HOME_DIR/Library/Caches" \
HYPEM_USERNAME="${HYPEM_USERNAME}" \
HYPEM_PASSWORD="${HYPEM_PASSWORD}" \
${HYPEM_DEVICE_ID:+HYPEM_DEVICE_ID="${HYPEM_DEVICE_ID}"} \
${HYPEM_API_KEY:+HYPEM_API_KEY="${HYPEM_API_KEY}"} \
"$BUILD_DIR/authprobe"
