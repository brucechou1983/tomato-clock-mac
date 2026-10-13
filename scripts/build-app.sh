#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_CONFIGURATION="${1:-release}"
BUILD_MODE="${2:-app}"
APP_PATH="$PROJECT_ROOT/build/Tomato Clock.app"
if [[ "$BUILD_MODE" == "ui-test" ]]; then
    APP_PATH="$PROJECT_ROOT/build/Tomato Clock QA.app"
fi
MODULE_CACHE="$PROJECT_ROOT/.build/ModuleCache"

cd "$PROJECT_ROOT"
mkdir -p "$MODULE_CACHE"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE"

# SwiftPM's optional nested sandbox is unavailable in some managed workspaces.
# All build outputs remain inside the project; no third-party dependencies run.
swift build --disable-sandbox -c "$BUILD_CONFIGURATION" --scratch-path "$PROJECT_ROOT/.build" \
    -Xswiftc -module-cache-path -Xswiftc "$MODULE_CACHE"

mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$PROJECT_ROOT/.build/$BUILD_CONFIGURATION/TomatoClock" "$APP_PATH/Contents/MacOS/TomatoClock"
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
if [[ "$BUILD_MODE" == "ui-test" ]]; then
    /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.bruce.tomato-clock.uitests' "$APP_PATH/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleName Tomato Clock QA' "$APP_PATH/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Add :TomatoUITestMode bool true' "$APP_PATH/Contents/Info.plist"
fi

swift -module-cache-path "$MODULE_CACHE" "$PROJECT_ROOT/scripts/make-icon.swift" "$PROJECT_ROOT/build"
cp "$PROJECT_ROOT/build/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"

# Local signing allows Notification Center to identify this app bundle.
codesign --force --sign - "$APP_PATH"
codesign --verify --strict "$APP_PATH"
printf 'App ready: %s\n' "$APP_PATH"
