#!/bin/bash
set -euo pipefail

CONFIG="debug"
UNIVERSAL=0
for arg in "$@"; do
  case "$arg" in
    --release)   CONFIG="release" ;;
    --universal) UNIVERSAL=1; CONFIG="release" ;;
    *) echo "usage: $0 [--release] [--universal]" >&2; exit 2 ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="歌词精灵"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
DEPLOY_TARGET="13.0"

ADAPTER_PL="$ROOT_DIR/Sources/MacSpotifyLyrics/Resources/mediaremote-adapter.pl"
ADAPTER_FW="$ROOT_DIR/Sources/MacSpotifyLyrics/Resources/MediaRemoteAdapter.framework"

# ---------- 前置检查 ----------

if [[ ! -f "$ADAPTER_PL" ]]; then
  echo "error: 缺少 $ADAPTER_PL" >&2
  exit 1
fi

if [[ ! -d "$ADAPTER_FW" ]]; then
  echo "error: 缺少 $ADAPTER_FW" >&2
  exit 1
fi

# ---------- 编译 ----------

if [[ "$UNIVERSAL" == "1" ]]; then
  # SwiftPM's own `--arch a --arch b` needs xcbuild from a full Xcode install. Building each
  # slice with an explicit triple works with just the Command Line Tools, then lipo joins them.
  echo "==> swift build -c $CONFIG (arm64 + x86_64, universal)"
  swift build -c "$CONFIG" --triple "arm64-apple-macosx$DEPLOY_TARGET"
  swift build -c "$CONFIG" --triple "x86_64-apple-macosx$DEPLOY_TARGET"

  ARM_BIN="$ROOT_DIR/.build/arm64-apple-macosx/$CONFIG/$APP_NAME"
  X86_BIN="$ROOT_DIR/.build/x86_64-apple-macosx/$CONFIG/$APP_NAME"
  for slice in "$ARM_BIN" "$X86_BIN"; do
    if [[ ! -f "$slice" ]]; then
      echo "error: 找不到编译产物 $slice" >&2
      exit 1
    fi
  done

  BIN_PATH="$ROOT_DIR/.build/$APP_NAME-universal"
  lipo -create -output "$BIN_PATH" "$ARM_BIN" "$X86_BIN"
else
  echo "==> swift build -c $CONFIG"
  swift build -c "$CONFIG"
  BIN_PATH="$ROOT_DIR/.build/$CONFIG/$APP_NAME"
fi

if [[ ! -f "$BIN_PATH" ]]; then
  echo "error: 找不到编译产物 $BIN_PATH" >&2
  exit 1
fi

# ---------- 定位 SwiftPM 资源 bundle ----------

RESOURCE_BUNDLE=""
for candidate in \
  "$ROOT_DIR/.build/arm64-apple-macosx/$CONFIG/歌词精灵_歌词精灵.bundle" \
  "$ROOT_DIR/.build/x86_64-apple-macosx/$CONFIG/歌词精灵_歌词精灵.bundle" \
  "$ROOT_DIR/.build/$CONFIG/歌词精灵_歌词精灵.bundle"
do
  if [[ -d "$candidate" ]]; then
    RESOURCE_BUNDLE="$candidate"
    break
  fi
done

# 兜底：名称可能因 SwiftPM 版本不同而变化
if [[ -z "$RESOURCE_BUNDLE" ]]; then
  RESOURCE_BUNDLE="$(find "$ROOT_DIR/.build" -maxdepth 4 -type d -name '*.bundle' \
    -not -path '*/.build/*/checkouts/*' | head -n 1)"
fi

echo "==> Resource bundle: $RESOURCE_BUNDLE"

# ---------- 组装 .app ----------

echo "==> Assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
echo "==> Architectures: $(lipo -archs "$MACOS_DIR/$APP_NAME")"

cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"

if [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

if [[ -d "$ROOT_DIR/Resources/Assets.xcassets" ]]; then
  cp -R "$ROOT_DIR/Resources/Assets.xcassets" "$RESOURCES_DIR/" 2>/dev/null || true
fi

echo "==> 复制 SwiftPM 资源 bundle"
RESOURCE_BUNDLE_NAME="$(basename "$RESOURCE_BUNDLE")"
ditto "$RESOURCE_BUNDLE" "$RESOURCES_DIR/$RESOURCE_BUNDLE_NAME"

# ---------- universal 架构检查 ----------

if [[ "" == "1" ]]; then
  FRAMEWOEK_DIR="$RESOURCE_DIR/$RESOURCE_BUNDLE_NAME/MediaRemoteAdapter.framework"
  ADAPTER_BIN="$FRAMEWORK_DIR/Versions/A/MediaRemoteAdapter"
  
  if [[ ! -f "$ADAPTER_BIN" ]]; then
      ADAPTER_BIN="$FRAMEWOEK_DIR/MediaRemoteAdapter"
  fi
  
  if [[ -f "$ADAPTER_BIN" ]]; then
    FW_ARCHS="$(lipo -archs "ADAPTER_BIN" 2>/dev/null || echo unknown)"
    echo "==> Adapter architectures: $FW_ARCHS"
    
    if [[ "$FW_ARCHS" != *"arm64"* || "$FW_ARCHS" != *"x86_64"* ]]; then
      echo "警告：MediaRemoteAdapter.framework 不是 arm64+x86_64 双架构" >&2
      echo "          x86_64 机器上可能无法运行" >&2
    fi
  fi
fi

# ---------- 签名 ----------

echo "==> Ad-hoc signing"
FRAMEWORK_DIR="$RESOURCES_DIR/$RESOURCE_BUNDLE_NAME/MediaRemoteAdapter.framework"

if [[ -d "$FRAMEWORK_DIR" ]]; then
  codesign --force --deep --sign - "$FRAMEWORK_DIR"
fi

codesign --force --deep --sign - "$APP_BUNDLE"

# ---------- 校验 ----------

echo "==> 校验 bundle"
test -x "$MACOS_DIR/$APP_NAME"
test -f "$CONTENTS/Info.plist"
test -d "$FRAMEWORK_DIR"
test -f "$RESOURCES_DIR/$RESOURCE_BUNDLE_NAME/mediaremote-adapter.pl"

echo "==> Done: $APP_BUNDLE"
echo "Run with: open \"$APP_BUNDLE\""
