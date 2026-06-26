#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="CueFetch"
BUNDLE_ID="com.edgariraheta.CueFetch"
MIN_SYSTEM_VERSION="14.0"
VERSION="${CUEFETCH_VERSION:-0.1.0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON_SOURCE="$ROOT_DIR/Assets/AppIcon.icns"
SAVED_STATE="$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"
INSTALL_APP="/Applications/$APP_NAME.app"

build_app() {
  local configuration="${1:-debug}"
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true

  swift build -c "$configuration"
  BUILD_DIR="$(swift build -c "$configuration" --show-bin-path)"
  BUILD_BINARY="$BUILD_DIR/$APP_NAME"

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES"
  cp "$BUILD_BINARY" "$APP_BINARY"
  chmod +x "$APP_BINARY"

  if [[ -f "$APP_ICON_SOURCE" ]]; then
    cp "$APP_ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
  fi

  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSQuitAlwaysKeepsWindows</key>
  <false/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST

  if [[ -n "${CUEFETCH_SIGN_IDENTITY:-}" ]]; then
    codesign \
      --force \
      --deep \
      --options runtime \
      --timestamp \
      --sign "$CUEFETCH_SIGN_IDENTITY" \
      "$APP_BUNDLE"
  else
    codesign \
      --force \
      --deep \
      --sign - \
      "$APP_BUNDLE"
  fi
}

open_app() {
  rm -rf "$SAVED_STATE"
  /usr/bin/open -n "$APP_BUNDLE"
}

build_dmg() {
  build_app release
  rm -rf "$DMG_ROOT" "$DMG_PATH"
  mkdir -p "$DMG_ROOT"
  ditto "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
  ln -s /Applications "$DMG_ROOT/Applications"
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null
  if [[ -n "${CUEFETCH_SIGN_IDENTITY:-}" ]]; then
    codesign \
      --force \
      --timestamp \
      --sign "$CUEFETCH_SIGN_IDENTITY" \
      "$DMG_PATH"
  fi
  hdiutil verify "$DMG_PATH" >/dev/null
  echo "$DMG_PATH"
}

install_app() {
  build_app release
  rm -rf "$INSTALL_APP"
  ditto "$APP_BUNDLE" "$INSTALL_APP"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALL_APP" >/dev/null 2>&1 || true
  touch "$INSTALL_APP"
  rm -rf "$SAVED_STATE"
  /usr/bin/open -n "$INSTALL_APP"
  sleep 1
  pgrep -x "$APP_NAME" >/dev/null
  echo "$INSTALL_APP"
}

case "$MODE" in
  run)
    build_app
    open_app
    ;;
  --debug|debug)
    build_app
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    build_app
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --dmg|dmg)
    build_dmg
    ;;
  --install|install)
    install_app
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--dmg|--install]" >&2
    exit 2
    ;;
esac
