#!/bin/bash
# Uses existing Git/gh authentication. No credentials are stored or printed.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPOSITORY="brucechou1983/tomato-clock-mac"
VERSION="1.0.0"
TAG="v$VERSION"
APP_PATH="$PROJECT_ROOT/build/Tomato Clock.app"
INSTALLED_APP="/Applications/Tomato Clock.app"
DMG_NAME="Tomato-Clock-$VERSION-arm64.dmg"
DMG_PATH="$PROJECT_ROOT/build/$DMG_NAME"
CHECKSUM_PATH="$DMG_PATH.sha256"
NOTES_PATH="$PROJECT_ROOT/docs/release-$TAG.md"
CHECK_ONLY=false

fail() { printf '%s\n' "$*" >&2; exit 1; }

case "${1:-}" in
    --check) CHECK_ONLY=true ;;
    --help|-h)
        printf '%s\n' \
            'Usage: ./scripts/release.sh [--check]' \
            '--check: only check local prerequisites; no build, install, commit, push or release.' \
            'Default: test, package DMG, commit/push, publish v1.0.0, install and open the app.'
        exit 0 ;;
    '') ;;
    *) fail "不支援的參數：$1" ;;
esac
[[ $# -le 1 ]] || fail '最多只接受一個參數。'

cd "$PROJECT_ROOT"
[[ "$(uname -s)" == Darwin ]] || fail '請在 macOS Terminal 執行。'
[[ "$(uname -m)" == arm64 ]] || fail 'v1.0.0 使用 Apple Silicon；請使用原生 arm64 Terminal。'
for command in git gh swift hdiutil ditto codesign shasum open osascript; do
    command -v "$command" >/dev/null || fail "缺少指令：$command"
done
[[ "$(git branch --show-current)" == main ]] || fail '請先切換到 main，再執行此發布腳本。'
case "$(git remote get-url origin)" in
    https://github.com/brucechou1983/tomato-clock-mac|https://github.com/brucechou1983/tomato-clock-mac.git|git@github.com:brucechou1983/tomato-clock-mac.git|ssh://git@github.com/brucechou1983/tomato-clock-mac.git) ;;
    *) fail 'origin 必須是 brucechou1983/tomato-clock-mac；腳本不會修改 remote。' ;;
esac
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)" == "$VERSION" ]] \
    || fail 'Info.plist 的版本不是 1.0.0。'
[[ -s docs/images/main.png && -s "$NOTES_PATH" ]] || fail '缺少 README 截圖或 Release notes。'
for script in scripts/build-app.sh scripts/test.sh scripts/package-dmg.sh; do
    [[ -x "$script" ]] || fail "腳本不可執行：$script"
done
if "$CHECK_ONLY"; then
    printf '%s\n' '本機前置條件通過。尚未檢查 GitHub 登入與網路，也未執行任何發布動作。'
    exit 0
fi

# Suppress auth-status output so even masked credential values stay out of logs.
gh auth status --hostname github.com >/dev/null 2>&1 \
    || fail '請先執行 gh auth login --hostname github.com，再重跑此腳本。'
permission="$(gh repo view "$REPOSITORY" --json viewerPermission --jq .viewerPermission)"
case "$permission" in
    ADMIN|MAINTAIN|WRITE) ;;
    *) fail '目前的 GitHub CLI 帳號沒有此 repository 的寫入權限；請切換帳號後重跑。' ;;
esac
git var GIT_AUTHOR_IDENT >/dev/null \
    || fail '請先設定 Git 的 user.name 與 user.email。'

printf '%s\n' '1/6 檢查並提交原始碼、文件與發布腳本'
# Do not include unrelated files that someone staged before running the script.
while IFS= read -r path; do
    case "$path" in
        .gitignore|Package.swift|README.md|Resources/Info.plist|Sources/*|Tests/*|scripts/*|docs/*) ;;
        *) fail "暫存區含本專案發布範圍外的檔案，請先取消暫存：$path" ;;
    esac
done < <(git diff --cached --name-only)
git add -- .gitignore Package.swift README.md Resources/Info.plist Sources Tests scripts docs
git diff --cached --check
if ! git diff --cached --quiet; then
    git commit -m 'Release Tomato Clock v1.0.0'
fi
release_commit="$(git rev-parse HEAD)"

git fetch origin
if git show-ref --verify --quiet refs/remotes/origin/main; then
    git merge-base --is-ancestor origin/main "$release_commit" \
        || fail '遠端 main 有本機未包含的提交；請先同步並解決差異，腳本不會 force-push。'
fi
remote_tag="$(git ls-remote origin "refs/tags/$TAG")"
if [[ -n "$remote_tag" ]]; then
    git fetch origin "refs/tags/$TAG:refs/tags/$TAG"
fi
if git show-ref --verify --quiet "refs/tags/$TAG"; then
    [[ "$(git rev-parse "$TAG^{commit}")" == "$release_commit" ]] \
        || fail 'v1.0.0 tag 已指向其他 commit；腳本不會移動既有 tag。'
fi

printf '%s\n' '2/6 執行核心測試'
./scripts/test.sh
printf '%s\n' '3/6 建置並驗證 DMG'
./scripts/package-dmg.sh
[[ -s "$DMG_PATH" && -s "$CHECKSUM_PATH" ]] || fail 'DMG 或 SHA-256 校驗檔未產生。'
(cd build && shasum -a 256 -c "$DMG_NAME.sha256")
[[ -z "$(git status --porcelain --untracked-files=normal)" ]] \
    || fail '建置期間原始碼有變動或有未追蹤檔案；請確認後重新執行，避免發布不一致的產物。'
[[ "$(git rev-parse HEAD)" == "$release_commit" ]] || fail '建置期間 HEAD 有變動，請重新執行。'

printf '%s\n' '4/6 推送 main 與 v1.0.0 tag'
if ! git show-ref --verify --quiet "refs/tags/$TAG"; then
    git tag -a "$TAG" -m "Tomato Clock $TAG"
fi
git push --atomic -u origin main "refs/tags/$TAG"

printf '%s\n' '5/6 上傳 DMG、校驗檔並發布 GitHub Release'
if draft="$(gh release view "$TAG" --repo "$REPOSITORY" --json isDraft --jq .isDraft 2>/dev/null)"; then
    if [[ "$draft" == true ]]; then
        gh release upload "$TAG" "$DMG_PATH" "$CHECKSUM_PATH" --repo "$REPOSITORY" --clobber
    else
        printf '%s\n' '相同 tag 的 Release 已發布，保留現有資產。'
    fi
else
    gh release create "$TAG" "$DMG_PATH" "$CHECKSUM_PATH" --repo "$REPOSITORY" \
        --verify-tag --draft --title "小番茄 $TAG" --notes-file "$NOTES_PATH"
    draft=true
fi
# Verify both assets exist before publishing the draft.
assets="$(gh release view "$TAG" --repo "$REPOSITORY" --json assets \
    --jq '.assets[] | select(.size > 0) | .name')"
printf '%s\n' "$assets" | /usr/bin/grep -Fxq "$DMG_NAME" || fail 'Release 中缺少 DMG，草稿不會發布。'
printf '%s\n' "$assets" | /usr/bin/grep -Fxq "$DMG_NAME.sha256" || fail 'Release 中缺少校驗檔，草稿不會發布。'
if [[ "$draft" == true ]]; then
    gh release edit "$TAG" --repo "$REPOSITORY" --draft=false --latest \
        --verify-tag --title "小番茄 $TAG" --notes-file "$NOTES_PATH"
fi
[[ "$(gh release view "$TAG" --repo "$REPOSITORY" --json isDraft --jq .isDraft)" == false ]] \
    || fail 'Release 仍是草稿；尚未完成發布。'

printf '%s\n' '6/6 安裝到應用程式並開啟'
if pgrep -x TomatoClock >/dev/null; then
    # Graceful quit lets the app save and pause its current timer.
    osascript -e 'tell application id "com.bruce.tomato-clock" to quit'
fi
if [[ -w /Applications && ( ! -e "$INSTALLED_APP" || -w "$INSTALLED_APP" ) ]]; then
    ditto "$APP_PATH" "$INSTALLED_APP"
else
    printf '%s\n' '安裝需要管理員權限；密碼只會在 Terminal 的 sudo 提示中輸入。'
    sudo ditto "$APP_PATH" "$INSTALLED_APP"
fi
codesign --verify --strict "$INSTALLED_APP"
open "$INSTALLED_APP"
printf '\n%s\n' 'v1.0.0 已發布，app 已安裝並開啟。'
gh release view "$TAG" --repo "$REPOSITORY" --json url --jq .url
