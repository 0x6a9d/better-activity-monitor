#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Better Activity Monitor"
BUILD_ROOT="$ROOT_DIR/Build"
APP_PATH="$BUILD_ROOT/$APP_NAME.app"
ICON_SOURCE="$ROOT_DIR/bam-logo.png"
STATUS_ICON_SOURCE="$ROOT_DIR/bam-logo-mono.png"
INFO_PLIST_SOURCE="$ROOT_DIR/AppBundle/Info.plist"
BUILD_CACHE_ROOT="$BUILD_ROOT/swift-build-cache"
TMP_ROOT="${TMPDIR:-/tmp}"
SWIFT_BUILD_ROOT="$TMP_ROOT/better-activity-monitor-swift-package-build"

rm -rf "$BUILD_CACHE_ROOT" "$SWIFT_BUILD_ROOT"
mkdir -p "$BUILD_CACHE_ROOT/home" "$BUILD_CACHE_ROOT/ModuleCache" "$SWIFT_BUILD_ROOT"

export HOME="$BUILD_CACHE_ROOT/home"
export CLANG_MODULE_CACHE_PATH="$BUILD_CACHE_ROOT/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_CACHE_ROOT/ModuleCache"

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Missing icon source at $ICON_SOURCE" >&2
  exit 1
fi

if [[ ! -f "$STATUS_ICON_SOURCE" ]]; then
  echo "Missing status icon source at $STATUS_ICON_SOURCE" >&2
  exit 1
fi

if [[ ! -f "$INFO_PLIST_SOURCE" ]]; then
  echo "Missing Info.plist template at $INFO_PLIST_SOURCE" >&2
  exit 1
fi

echo "Building release executable..."
swift build -c release --disable-sandbox --scratch-path "$SWIFT_BUILD_ROOT"

EXECUTABLE_PATH="$(find "$SWIFT_BUILD_ROOT" -type f -path "*/release/ActivityMonitorDashboard" | head -n 1)"

if [[ -z "$EXECUTABLE_PATH" || ! -f "$EXECUTABLE_PATH" ]]; then
  echo "Could not locate release executable." >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
ICONSET_DIR="$WORK_DIR/IconPNGSet"
ICNS_PATH="$WORK_DIR/AppIcon.icns"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$ICONSET_DIR"

render_icon() {
  local size="$1"
  local output="$2"
  sips -z "$size" "$size" "$ICON_SOURCE" --out "$output" >/dev/null
}

render_icon 16 "$ICONSET_DIR/16.png"
render_icon 32 "$ICONSET_DIR/32.png"
render_icon 64 "$ICONSET_DIR/64.png"
render_icon 128 "$ICONSET_DIR/128.png"
render_icon 256 "$ICONSET_DIR/256.png"
render_icon 512 "$ICONSET_DIR/512.png"
render_icon 1024 "$ICONSET_DIR/1024.png"

python3 "$ROOT_DIR/scripts/pngs_to_icns.py" "$ICONSET_DIR" "$ICNS_PATH"

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

cp "$EXECUTABLE_PATH" "$APP_PATH/Contents/MacOS/$APP_NAME"
chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"
cp "$INFO_PLIST_SOURCE" "$APP_PATH/Contents/Info.plist"
cp "$ICNS_PATH" "$APP_PATH/Contents/Resources/AppIcon.icns"
cp "$STATUS_ICON_SOURCE" "$APP_PATH/Contents/Resources/bam-logo-mono.png"

codesign --force --deep --sign - "$APP_PATH" >/dev/null

echo "Created app bundle:"
echo "$APP_PATH"
