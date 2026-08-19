#!/bin/zsh
# Builds Pomodoro.app. Use --install to drop it in /Applications and relaunch it.
set -euo pipefail
cd "${0:A:h}"

APP_NAME="Pomodoro"
DIST="dist/${APP_NAME}.app"

echo "▸ compiling (release)…"
swift build -c release

echo "▸ assembling ${DIST}…"
rm -rf "$DIST"
mkdir -p "$DIST/Contents/MacOS" "$DIST/Contents/Resources"
cp ".build/release/${APP_NAME}" "$DIST/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "$DIST/Contents/Info.plist"
codesign --force --sign - "$DIST" >/dev/null 2>&1 || echo "  (ad-hoc signing skipped)"

if [[ "${1:-}" == "--install" ]]; then
  echo "▸ installing to /Applications…"
  pkill -x "$APP_NAME" 2>/dev/null || true
  sleep 1
  rm -rf "/Applications/${APP_NAME}.app"
  cp -R "$DIST" "/Applications/${APP_NAME}.app"
  open "/Applications/${APP_NAME}.app"
  echo "✓ installed and running"
else
  echo "✓ built at ${DIST}  —  open it with:  open ${DIST}"
fi
