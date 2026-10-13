#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_ROOT/build/Tomato Clock.app"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_ROOT/Resources/Info.plist")"
APP_ARCH="$(uname -m)"
DMG_PATH="$PROJECT_ROOT/build/Tomato-Clock-$APP_VERSION-$APP_ARCH.dmg"

"$PROJECT_ROOT/scripts/build-app.sh" release
STAGING_PATH="$(mktemp -d "$PROJECT_ROOT/build/dmg-staging.XXXXXX")"
trap 'rm -rf "$STAGING_PATH"' EXIT

ditto "$APP_PATH" "$STAGING_PATH/Tomato Clock.app"
ln -s /Applications "$STAGING_PATH/Applications"
cat > "$STAGING_PATH/安裝說明.txt" <<'EOF'
小番茄 · Tomato Clock

將 Tomato Clock.app 拖曳到 Applications（應用程式），然後從應用程式開啟。
首次開始計時時，請允許通知，才能收到系統提醒。

需要 macOS 14 或更新版本。此安裝檔適用 Apple Silicon Mac。

此版本採用本機 ad-hoc 簽名，尚未通過 Apple 公證。
從網路下載後，macOS Gatekeeper 可能阻擋開啟；
信任此來源的使用者可在系統設定 → 隱私權與安全性查看提示。

原始碼與版本：
https://github.com/brucechou1983/tomato-clock-mac
EOF

hdiutil create -volname "小番茄 $APP_VERSION" -srcfolder "$STAGING_PATH" \
    -format UDZO -ov "$DMG_PATH"
hdiutil verify "$DMG_PATH"
cd "$PROJECT_ROOT/build"
shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$DMG_PATH").sha256"
printf 'DMG ready: %s\n' "$DMG_PATH"
