#!/usr/bin/env bash
set -euo pipefail

# Build + install + launch EstateMate on a connected iOS device.
# Requires: Xcode installed, device paired (USB or Wi‑Fi), device unlocked.

PROJECT="EstateMate.xcodeproj"
SCHEME="EstateMate"
CONFIG="Debug"
BUNDLE_ID="EstateMate.EstateMate"

DEVICE_UDID="${1:-}"
if [[ -z "$DEVICE_UDID" ]]; then
  echo "Usage: $0 <DEVICE_UDID>"
  echo
  echo "Tip: list devices with: xcrun xctrace list devices"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Use a temp (non-iCloud/non-FileProvider) DerivedData path to avoid codesign failures caused by extended attributes.
DERIVED="${TMPDIR:-/tmp}/EstateMateDerivedData"

echo "==> Building ($SCHEME) for device $DEVICE_UDID..."
xcodebuild \
  -project "$ROOT_DIR/$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "id=$DEVICE_UDID" \
  -derivedDataPath "$DERIVED" \
  build

APP_PATH="$DERIVED/Build/Products/${CONFIG}-iphoneos/${SCHEME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app not found at: $APP_PATH"
  echo "Check scheme/product name."
  exit 2
fi

echo "==> Installing to device..."
xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH"

echo "==> Launching $BUNDLE_ID ..."
# Try to terminate first (best-effort)
xcrun devicectl device process terminate --device "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun devicectl device process launch --device "$DEVICE_UDID" "$BUNDLE_ID"

echo "==> Done"
