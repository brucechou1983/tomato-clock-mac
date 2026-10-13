#!/bin/bash
# Installs the already-built app without pushing code or publishing a release.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_ROOT/build/Tomato Clock.app"
INSTALLED_APP="/Applications/Tomato Clock.app"

fail() { printf '%s\n' "$*" >&2; exit 1; }

# pgrep status 1 means no process; other errors do not prove the app exited.
app_is_running() {
    local result=0
    pgrep -x TomatoClock >/dev/null || result=$?
    case "$result" in
        0) return 0 ;;
        1) return 1 ;;
        *) fail '無法查詢 app 程序，請在一般 macOS Terminal 執行此腳本。' ;;
    esac
}

[[ "$(uname -s)" == Darwin ]] || fail '請在 macOS Terminal 執行。'
[[ -x "$APP_PATH/Contents/MacOS/TomatoClock" ]] \
    || fail '找不到已建置的 app，請先執行 ./scripts/build-app.sh。'
codesign --verify --strict "$APP_PATH"

if app_is_running; then
    printf '%s\n' '正在結束小番茄並保存計時進度⋯'
    osascript -e 'tell application id "com.bruce.tomato-clock" to quit'
    # Quit is asynchronous. Never overwrite the executable while it is running.
    for ((attempt = 0; attempt < 50; attempt++)); do
        if ! app_is_running; then break; fi
        sleep 0.2
    done
    if app_is_running; then
        fail 'app 尚未退出。請先關閉小番茄及 QA 測試版，再重跑安裝腳本；目前尚未覆寫 app。'
    fi
fi

printf '%s\n' '安裝到應用程式⋯'
if [[ -w /Applications && ( ! -e "$INSTALLED_APP" || -w "$INSTALLED_APP" ) ]]; then
    ditto "$APP_PATH" "$INSTALLED_APP"
else
    printf '%s\n' '安裝需要管理員權限；請在 Terminal 的 sudo 提示中輸入密碼。'
    sudo ditto "$APP_PATH" "$INSTALLED_APP"
fi
codesign --verify --strict "$INSTALLED_APP"

printf '%s\n' '開啟小番茄⋯'
for ((attempt = 0; attempt < 3; attempt++)); do
    # Start a fresh instance instead of addressing a stale LaunchServices PID.
    if open -n -a "$INSTALLED_APP"; then break; fi
    if app_is_running; then break; fi
    sleep 1
done
for ((attempt = 0; attempt < 15; attempt++)); do
    if app_is_running; then
        printf '%s\n' '小番茄已安裝並啟動。'
        exit 0
    fi
    sleep 0.2
done
fail 'app 已安裝，但未能確認啟動。請從「應用程式」打開 Tomato Clock.app；不需要重新發布 Release。'
