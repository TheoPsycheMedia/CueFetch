#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="CueFetch"
BUNDLE_ID="com.theopsychemedia.CueFetch"
MIN_SYSTEM_VERSION="14.0"
RELEASE_VERSION="${CUEFETCH_VERSION:-0.2.0-preview}"
MARKETING_VERSION="${CUEFETCH_MARKETING_VERSION:-${RELEASE_VERSION%%-*}}"
BUILD_NUMBER="${CUEFETCH_BUILD_NUMBER:-2}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/$APP_NAME-$RELEASE_VERSION.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"
RELEASE_NOTES_PATH="$DIST_DIR/$APP_NAME-$RELEASE_VERSION-release-notes.md"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON_SOURCE="$ROOT_DIR/Assets/AppIcon.icns"
SAVED_STATE="$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"
INSTALL_APP="/Applications/$APP_NAME.app"
RELEASE_ARCHS=(arm64 x86_64)

fail() {
  echo "error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

validate_release_metadata() {
  [[ "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z][0-9A-Za-z.-]*)?$ ]] || \
    fail "CUEFETCH_VERSION must look like 0.2.0 or 0.2.0-preview"
  [[ "$MARKETING_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
    fail "CUEFETCH_MARKETING_VERSION must contain three numeric components"
  [[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || \
    fail "CUEFETCH_BUILD_NUMBER must be a positive integer"
  [[ "$RELEASE_VERSION" == "$MARKETING_VERSION" || "$RELEASE_VERSION" == "$MARKETING_VERSION-"* ]] || \
    fail "release version must use marketing version $MARKETING_VERSION"
}

is_developer_id_identity() {
  [[ "${CUEFETCH_SIGN_IDENTITY:-}" == "Developer ID Application:"* ]]
}

release_gate() {
  local empty_tree

  require_command git
  require_command swift

  if [[ -n "$(git -C "$ROOT_DIR" status --porcelain --untracked-files=normal)" ]]; then
    git -C "$ROOT_DIR" status --short >&2
    fail "release packaging requires a clean tracked and untracked worktree"
  fi

  empty_tree="$(git -C "$ROOT_DIR" hash-object -t tree /dev/null)"
  git -C "$ROOT_DIR" diff --check "$empty_tree" HEAD
  (
    cd "$ROOT_DIR"
    swift test
  )
}

build_release_binary() {
  local arch
  local build_dir
  local scratch_path
  local thin_binary
  local triple
  local thin_binaries=()

  require_command lipo

  for arch in "${RELEASE_ARCHS[@]}"; do
    scratch_path="$ROOT_DIR/.build/cuefetch-release-$arch"
    triple="$arch-apple-macosx$MIN_SYSTEM_VERSION"

    swift build \
      --package-path "$ROOT_DIR" \
      --scratch-path "$scratch_path" \
      --configuration release \
      --triple "$triple"

    build_dir="$(swift build \
      --package-path "$ROOT_DIR" \
      --scratch-path "$scratch_path" \
      --configuration release \
      --triple "$triple" \
      --show-bin-path)"
    thin_binary="$DIST_DIR/$APP_NAME-$arch"
    cp "$build_dir/$APP_NAME" "$thin_binary"
    thin_binaries+=("$thin_binary")
  done

  lipo -create "${thin_binaries[@]}" -output "$APP_BINARY"
  rm -f "${thin_binaries[@]}"
}

copy_legal_files() {
  local destination="$1"
  mkdir -p "$destination"
  cp "$ROOT_DIR/LICENSE" "$destination/LICENSE"
  cp "$ROOT_DIR/NOTICE" "$destination/NOTICE"
  cp "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$destination/THIRD_PARTY_NOTICES.md"
}

write_info_plist() {
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
  <string>$MARKETING_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>CueFetchReleaseVersion</key>
  <string>$RELEASE_VERSION</string>
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
}

sign_app() {
  if [[ -n "${CUEFETCH_SIGN_IDENTITY:-}" ]]; then
    codesign \
      --force \
      --options runtime \
      --timestamp \
      --sign "$CUEFETCH_SIGN_IDENTITY" \
      "$APP_BUNDLE"
  else
    codesign --force --sign - "$APP_BUNDLE"
  fi
}

verify_app() {
  local configuration="${1:-debug}"
  local arch
  local app_archs

  plutil -lint "$INFO_PLIST" >/dev/null
  [[ "$(plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")" == "$MARKETING_VERSION" ]] || \
    fail "app marketing version does not match $MARKETING_VERSION"
  [[ "$(plutil -extract CFBundleVersion raw -o - "$INFO_PLIST")" == "$BUILD_NUMBER" ]] || \
    fail "app build number does not match $BUILD_NUMBER"
  [[ "$(plutil -extract CueFetchReleaseVersion raw -o - "$INFO_PLIST")" == "$RELEASE_VERSION" ]] || \
    fail "app release label does not match $RELEASE_VERSION"

  if [[ "$configuration" == "release" ]]; then
    app_archs="$(lipo -archs "$APP_BINARY")"
    for arch in "${RELEASE_ARCHS[@]}"; do
      [[ " $app_archs " == *" $arch "* ]] || fail "app binary is missing $arch support"
    done
  fi

  for legal_file in LICENSE NOTICE THIRD_PARTY_NOTICES.md; do
    [[ -f "$APP_RESOURCES/Legal/$legal_file" ]] || fail "app bundle is missing $legal_file"
  done

  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
}

build_app() {
  local configuration="${1:-debug}"
  local build_dir

  require_command codesign
  require_command plutil
  require_command swift
  mkdir -p "$DIST_DIR"
  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES"

  if [[ "$configuration" == "release" ]]; then
    build_release_binary
  else
    swift build --package-path "$ROOT_DIR" --configuration "$configuration"
    build_dir="$(swift build \
      --package-path "$ROOT_DIR" \
      --configuration "$configuration" \
      --show-bin-path)"
    cp "$build_dir/$APP_NAME" "$APP_BINARY"
  fi
  chmod +x "$APP_BINARY"

  if [[ -f "$APP_ICON_SOURCE" ]]; then
    cp "$APP_ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
  fi
  copy_legal_files "$APP_RESOURCES/Legal"
  write_info_plist
  sign_app
  verify_app "$configuration"
}

open_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  rm -rf "$SAVED_STATE"
  /usr/bin/open -n "$APP_BUNDLE"
}

notarize_app() {
  local app_archive="$DIST_DIR/$APP_NAME-$RELEASE_VERSION.zip"

  [[ -n "${CUEFETCH_SIGN_IDENTITY:-}" ]] || \
    fail "CUEFETCH_SIGN_IDENTITY is required for notarization"
  [[ -n "${CUEFETCH_NOTARY_PROFILE:-}" ]] || \
    fail "CUEFETCH_NOTARY_PROFILE must name credentials stored in the Keychain"
  xcrun --find notarytool >/dev/null
  xcrun --find stapler >/dev/null

  rm -f "$app_archive"
  ditto -c -k --keepParent "$APP_BUNDLE" "$app_archive"
  xcrun notarytool submit \
    "$app_archive" \
    --keychain-profile "$CUEFETCH_NOTARY_PROFILE" \
    --wait
  rm -f "$app_archive"

  xcrun stapler staple "$APP_BUNDLE"
  xcrun stapler validate "$APP_BUNDLE"
  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
  spctl --assess --type execute --verbose=2 "$APP_BUNDLE"
}

notarization_gate() {
  [[ -n "${CUEFETCH_SIGN_IDENTITY:-}" ]] || \
    fail "CUEFETCH_SIGN_IDENTITY is required for notarization"
  is_developer_id_identity || \
    fail "notarization requires a Developer ID Application identity"
  [[ -n "${CUEFETCH_NOTARY_PROFILE:-}" ]] || \
    fail "CUEFETCH_NOTARY_PROFILE must name credentials stored in the Keychain"
  require_command xcrun
  xcrun --find notarytool >/dev/null
  xcrun --find stapler >/dev/null
}

sign_dmg() {
  if [[ -n "${CUEFETCH_SIGN_IDENTITY:-}" ]]; then
    codesign \
      --force \
      --timestamp \
      --sign "$CUEFETCH_SIGN_IDENTITY" \
      "$DMG_PATH"
  else
    codesign --force --sign - "$DMG_PATH"
  fi
  codesign --verify --strict --verbose=2 "$DMG_PATH"
}

notarize_dmg() {
  xcrun notarytool submit \
    "$DMG_PATH" \
    --keychain-profile "$CUEFETCH_NOTARY_PROFILE" \
    --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  codesign --verify --strict --verbose=2 "$DMG_PATH"
  spctl --assess \
    --type open \
    --context context:primary-signature \
    --verbose=2 \
    "$DMG_PATH"
}

write_release_outputs() {
  local notarization_status="$1"
  local signing_status="Ad-hoc signed app and DMG"
  local commit="unknown"
  local checksum
  local dmg_name
  local release_notes_name

  dmg_name="$(basename "$DMG_PATH")"
  release_notes_name="$(basename "$RELEASE_NOTES_PATH")"
  if is_developer_id_identity; then
    signing_status="Developer ID signed app and DMG"
  elif [[ "${CUEFETCH_SIGN_IDENTITY:-}" == "-" ]]; then
    signing_status="Ad-hoc signed app and DMG"
  elif [[ -n "${CUEFETCH_SIGN_IDENTITY:-}" ]]; then
    signing_status="Signed with a configured non-Developer-ID identity"
  fi
  if git -C "$ROOT_DIR" rev-parse --verify HEAD >/dev/null 2>&1; then
    commit="$(git -C "$ROOT_DIR" rev-parse HEAD)"
  fi

  (
    cd "$DIST_DIR"
    shasum -a 256 "$dmg_name" >"$dmg_name.sha256"
  )
  checksum="$(awk '{print $1}' "$CHECKSUM_PATH")"

  cat >"$RELEASE_NOTES_PATH" <<NOTES
# CueFetch $RELEASE_VERSION

- Marketing version: $MARKETING_VERSION
- Build number: $BUILD_NUMBER
- Minimum macOS: $MIN_SYSTEM_VERSION
- Architectures: arm64, x86_64
- Signing: $signing_status
- Notarization: $notarization_status
- Source commit: $commit

## Artifact

- File: \`$dmg_name\`
- SHA-256: \`$checksum\`
- Checksum file: \`$dmg_name.sha256\`

Verify after download:

\`\`\`bash
shasum -a 256 -c $dmg_name.sha256
\`\`\`

See \`CHANGELOG.md\` for release changes and \`SECURITY.md\` for private reporting guidance.
NOTES

  echo "$DMG_PATH"
  echo "$CHECKSUM_PATH"
  echo "$DIST_DIR/$release_notes_name"
}

build_dmg() {
  local should_notarize="${1:-false}"
  local notarization_status="Not submitted to Apple"

  require_command hdiutil
  require_command shasum
  build_app release

  if [[ "$should_notarize" == "true" ]]; then
    notarize_app
  fi

  rm -rf "$DMG_ROOT"
  rm -f "$DMG_PATH" "$CHECKSUM_PATH" "$RELEASE_NOTES_PATH"
  mkdir -p "$DMG_ROOT"
  ditto "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
  copy_legal_files "$DMG_ROOT/Legal"
  ln -s /Applications "$DMG_ROOT/Applications"
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null
  sign_dmg

  if [[ "$should_notarize" == "true" ]]; then
    notarize_dmg
    notarization_status="Accepted, stapled, and validated by Apple"
  fi

  hdiutil verify "$DMG_PATH" >/dev/null
  write_release_outputs "$notarization_status"
}

install_app() {
  build_app release
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  rm -rf "$INSTALL_APP"
  ditto "$APP_BUNDLE" "$INSTALL_APP"
  codesign --verify --deep --strict --verbose=2 "$INSTALL_APP"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$INSTALL_APP" >/dev/null 2>&1 || true
  touch "$INSTALL_APP"
  rm -rf "$SAVED_STATE"
  /usr/bin/open -n "$INSTALL_APP"
  sleep 1
  pgrep -x "$APP_NAME" >/dev/null
  echo "$INSTALL_APP"
}

usage() {
  cat >&2 <<USAGE
usage: $0 [run|--debug|--logs|--telemetry|--verify|--dmg|--notarize|--install]

  --dmg       Run release gates and build a universal DMG.
  --notarize  Run release gates, Developer ID sign, notarize, and staple.
  --install   Build and install a universal local QA app; a clean tree is not required.
USAGE
}

validate_release_metadata

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
    release_gate
    build_dmg false
    ;;
  --notarize|notarize)
    notarization_gate
    release_gate
    build_dmg true
    ;;
  --install|install)
    install_app
    ;;
  *)
    usage
    exit 2
    ;;
esac
