#!/bin/bash
# screenshot.sh — 플랫폼별 스크린샷 캡처 (AGENTS.md 7.6)
# usage: ./scripts/screenshot.sh [android|macos|server] [name]
set -euo pipefail

PLATFORM="${1:-android}"
NAME="${2:-v0.3_capture}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/screenshots/$PLATFORM"
mkdir -p "$OUT"

case "$PLATFORM" in
  android)
    ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
    DEV="127.0.0.1:6555"
    [ -x "$ADB" ] || { echo "[screenshot] adb 없음"; exit 1; }
    "$ADB" -s $DEV exec-out screencap -p > "$OUT/$NAME.png"
    echo "저장: $OUT/$NAME.png"
    ;;
  macos)
    screencapture -x "$OUT/$NAME.png"
    echo "저장: $OUT/$NAME.png (전체 화면 — 앱 메뉴바 확인)"
    ;;
  server)
    BASE="${SERVER_BASE:-http://localhost:${SERVER_PORT:-3000}}"
    for ep in health debug/logs debug/cache debug/queue; do
      curl -s "$BASE/$ep" > "$OUT/${NAME}_${ep//\//_}.json"
    done
    echo "저장: $OUT/${NAME}_*.json"
    ;;
  *) echo "플랫폼: android/macos/server"; exit 1 ;;
esac