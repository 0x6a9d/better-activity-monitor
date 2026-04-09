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
APP_ICON_SOURCE_SIZE=1024
APP_ICON_MAX_SIZE="${APP_ICON_MAX_SIZE:-1024}"
APP_ICON_CROP_SIZE="${APP_ICON_CROP_SIZE:-940}"
STATUS_ICON_RENDER_SIZE="${STATUS_ICON_RENDER_SIZE:-36}"
SUPPORTED_APP_ICON_SIZES=(16 32 64 128 256 512 1024)

case "$APP_ICON_MAX_SIZE" in
  16|32|64|128|256|512|1024) ;;
  *)
    echo "APP_ICON_MAX_SIZE must be one of: ${SUPPORTED_APP_ICON_SIZES[*]}" >&2
    exit 1
    ;;
esac

if [[ "$APP_ICON_CROP_SIZE" != <-> ]] || (( APP_ICON_CROP_SIZE < 256 || APP_ICON_CROP_SIZE > APP_ICON_SOURCE_SIZE )); then
  echo "APP_ICON_CROP_SIZE must be an integer between 256 and $APP_ICON_SOURCE_SIZE" >&2
  exit 1
fi

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
APP_ICON_RENDER_SOURCE="$WORK_DIR/bam-logo.png"
STATUS_ICON_PATH="$WORK_DIR/bam-logo-mono.png"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$ICONSET_DIR"

if (( APP_ICON_CROP_SIZE < APP_ICON_SOURCE_SIZE )); then
  sips -c "$APP_ICON_CROP_SIZE" "$APP_ICON_CROP_SIZE" "$ICON_SOURCE" --out "$WORK_DIR/bam-logo-cropped.png" >/dev/null
  sips -z "$APP_ICON_SOURCE_SIZE" "$APP_ICON_SOURCE_SIZE" "$WORK_DIR/bam-logo-cropped.png" --out "$APP_ICON_RENDER_SOURCE" >/dev/null
else
  cp "$ICON_SOURCE" "$APP_ICON_RENDER_SOURCE"
fi

render_icon() {
  local size="$1"
  local output="$2"
  sips -z "$size" "$size" "$APP_ICON_RENDER_SOURCE" --out "$output" >/dev/null
}

compress_png_if_possible() {
  local png_path="$1"

  if ! command -v pngquant >/dev/null 2>&1; then
    return 0
  fi

  pngquant --force --skip-if-larger --strip --ext .png "$png_path" >/dev/null 2>&1 || {
    local rc="$?"

    if [[ "$rc" -ne 98 ]]; then
      echo "pngquant failed for $png_path" >&2
      exit "$rc"
    fi
  }
}

for size in "${SUPPORTED_APP_ICON_SIZES[@]}"; do
  if (( size > APP_ICON_MAX_SIZE )); then
    continue
  fi

  render_icon "$size" "$ICONSET_DIR/$size.png"
done

sips -z "$STATUS_ICON_RENDER_SIZE" "$STATUS_ICON_RENDER_SIZE" "$STATUS_ICON_SOURCE" --out "$STATUS_ICON_PATH" >/dev/null
compress_png_if_possible "$STATUS_ICON_PATH"

python3 "$ROOT_DIR/scripts/pngs_to_icns.py" "$ICONSET_DIR" "$ICNS_PATH"

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

cp "$EXECUTABLE_PATH" "$APP_PATH/Contents/MacOS/$APP_NAME"
chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"
strip -Sx "$APP_PATH/Contents/MacOS/$APP_NAME"
cp "$INFO_PLIST_SOURCE" "$APP_PATH/Contents/Info.plist"
cp "$ICNS_PATH" "$APP_PATH/Contents/Resources/AppIcon.icns"
cp "$STATUS_ICON_PATH" "$APP_PATH/Contents/Resources/bam-logo-mono.png"

codesign --force --deep --sign - "$APP_PATH" >/dev/null

echo "Created app bundle:"
echo "$APP_PATH"
