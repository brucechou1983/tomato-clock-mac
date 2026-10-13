#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODULE_CACHE="$PROJECT_ROOT/.build/ModuleCache"
mkdir -p "$MODULE_CACHE"
cd "$PROJECT_ROOT"
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE" \
    swift test --disable-sandbox --scratch-path "$PROJECT_ROOT/.build" \
    -Xswiftc -module-cache-path -Xswiftc "$MODULE_CACHE"
