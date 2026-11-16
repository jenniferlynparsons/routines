#!/bin/bash
# Builds Routines.app from source.
#   bash build.sh            build Routines.app in this folder
#   bash build.sh --install  build, then copy it to /Applications and open it
# Set UNIVERSAL=1 to build for both Apple silicon and Intel Macs.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift isn't installed. Run:  xcode-select --install"
  echo "Then run this script again."
  exit 1
fi

APP="Routines.app"

ARCH_FLAGS=""
if [ "${UNIVERSAL:-}" = "1" ]; then
  ARCH_FLAGS="--arch arm64 --arch x86_64"
fi

echo "Compiling…"
swift build -c release $ARCH_FLAGS
BIN="$(swift build -c release $ARCH_FLAGS --show-bin-path)/Routines"

echo "Packaging $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Routines"
cp Support/Info.plist "$APP/Contents/Info.plist"
iconutil -c icns Support/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "Built $(pwd)/$APP"

if [ "${1:-}" = "--install" ]; then
  osascript -e 'quit app "Routines"' >/dev/null 2>&1 || true
  rm -rf "/Applications/$APP"
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/$APP"
  open "/Applications/$APP"
fi
