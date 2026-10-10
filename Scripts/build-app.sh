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
      echo "error: expected slice not found at $slice" >&2
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
  echo "error: built binary not found at $BIN_PATH" >&2
  exit 1
fi

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

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Done: $APP_BUNDLE"
echo "Run with: open \"$APP_BUNDLE\""
