#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "==> Rendering base icon PNG"
swift "$ROOT_DIR/Scripts/generate-icon.swift" "$WORK_DIR/icon-1024.png"

ICONSET="$WORK_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"

SIZES=(
  "16x16:16"
  "16x16@2x:32"
  "32x32:32"
  "32x32@2x:64"
  "128x128:128"
  "128x128@2x:256"
  "256x256:256"
  "256x256@2x:512"
  "512x512:512"
  "512x512@2x:1024"
)

echo "==> Generating iconset sizes"
for entry in "${SIZES[@]}"; do
  name="${entry%%:*}"
  px="${entry##*:}"
  sips -z "$px" "$px" "$WORK_DIR/icon-1024.png" --out "$ICONSET/icon_${name}.png" >/dev/null
done

mkdir -p "$ROOT_DIR/Resources"
echo "==> Building .icns"
iconutil -c icns "$ICONSET" -o "$ROOT_DIR/Resources/AppIcon.icns"

echo "==> Done: $ROOT_DIR/Resources/AppIcon.icns"
