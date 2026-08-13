#!/bin/bash
# a11y-dump.sh — 텍스트 전용 모델 대응 3종 세트 (AGENTS.md 7.6.1 / 부록 C)
#   .a11y.txt     접근성/상태 덤프 (화면·화면 상태 텍스트)
#   .storage.json 저장소 덤프 (설정·캐시·큐)
#   .perf.json    성능 덤프 (메모리·CPU·응답시간)
# usage: ./scripts/a11y-dump.sh [macos|android|server] [version]
set -euo pipefail

PLATFORM="${1:-android}"
VERSION="${2:-v0.3}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/screenshots/$PLATFORM"
mkdir -p "$OUT"
A="$OUT/${VERSION}_dump.a11y.txt"
S="$OUT/${VERSION}_dump.storage.json"
P="$OUT/${VERSION}_dump.perf.json"
echo "[a11y] $PLATFORM → $OUT"

dump_android() {
  local ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
  local DEV="127.0.0.1:6555"
  if ! "$ADB" devices | grep -q "$DEV"; then
    echo "  [skip] Genymotion 미연결 — 연결 후 재실행 (adb connect $DEV)"
    exit 0
  fi
  {
    echo "=== Wordville a11y dump ($(date +%F\ %T)) ==="
    echo "--- 포커스 ---"
    "$ADB" -s $DEV shell "dumpsys window | grep -E 'mCurrentFocus|mFocusedApp'"
    echo "--- 앱 로그 (Wordville) ---"
    "$ADB" -s $DEV logcat -d -s Wordville:V 2>/dev/null | tail -40
    echo "--- 액티비티 상태 ---"
    "$ADB" -s $DEV shell "dumpsys activity activities | grep -E 'topResumedActivity|mResumedActivity'" | head -2
  } > "$A"
  {
    echo "{"
    echo "\"package\": \"com.borasarang.wordville\","
    echo "\"version\": \"$VERSION\","
    echo "\"shared_prefs\":"
    "$ADB" -s $DEV shell "run-as com.borasarang.wordville cat shared_prefs/*.xml 2>/dev/null || echo null"
    echo ","
    echo "\"installed_time\": \"$("$ADB" -s $DEV shell dumpsys package com.borasarang.wordville | grep -m1 lastUpdateTime || echo unknown)\""
    echo "}"
  } > "$S" 2>/dev/null || echo "{\"error\":\"storage dump 실패\"}" > "$S"
  {
    "$ADB" -s $DEV shell "dumpsys meminfo com.borasarang.wordville | grep -E 'TOTAL|Native Heap|Dalvik Heap'" | head -4
    echo "---"
    "$ADB" -s $DEV shell "cat /proc/$(adb -s $DEV shell pidof com.borasarang.wordville | tr -d '\r')/status 2>/dev/null | grep -E 'VmRSS|VmSize'" || true
  } > "$P"
}

dump_macos() {
  local BUNDLE="com.borasarang.wordville"
  {
    echo "=== Wordville a11y dump (macOS, $(date +%F\ %T)) ==="
    echo "--- 프로세스 ---"
    pgrep -fl "글마을 달인" || pgrep -fl Wordville || echo "앱 미실행"
    echo "--- 앱 실행 상태 ---"
    osascript -e 'tell application "System Events" to get name of every process whose background only is false' 2>/dev/null | tr ',' '\n' | grep -i "글마을\|Wordville" || echo "앱 창 없음 (메뉴바 상주)"
  } > "$A"
  {
    echo "=== defaults ($BUNDLE) ==="
    defaults read "$BUNDLE" 2>/dev/null || echo "(설정 없음 또는 앱 미실행)"
  } > "$S"
  {
    local pid
    pid="$(pgrep -f '글마을 달인' || pgrep -f 'Contents/MacOS/Wordville' || true)"
    if [ -n "$pid" ]; then
      ps -o pid,rss,%cpu,etime -p "$pid"
    else
      echo "앱 미실행"
    fi
  } > "$P"
}

dump_server() {
  local base="${SERVER_BASE:-http://localhost:${SERVER_PORT:-3000}}"
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' "$base/health" || true)"
  [ "$code" = "200" ] || { echo "  [fail] 서버 미기동 ($base/health -> $code) — npm run dev 먼저"; exit 1; }
  {
    echo "=== Wordville server a11y dump ($(date +%F\ %T)) ==="
    echo "--- /health ---"
    curl -s "$base/health"
    echo ""
    echo "--- /debug/logs (최근 50줄) ---"
    curl -s "$base/debug/logs" | head -c 8000
  } > "$A"
  {
    echo "{\"health\": $(curl -s "$base/health"),"
    echo "\"cache\": $(curl -s "$base/debug/cache"),"
    echo "\"queue\": $(curl -s "$base/debug/queue")}"
  } > "$S"
  {
    echo "{\"health_ms\": $(curl -s -o /dev/null -w '%{time_total}' "$base/health" | sed 's/\./,/' | awk -F, '{print $1"."$2}'),"
    echo "\"debug_logs_ms\": $(curl -s -o /dev/null -w '%{time_total}' "$base/debug/logs" | sed 's/\./,/' | awk -F, '{print $1"."$2}')}"
  } > "$P"
}

case "$PLATFORM" in
  android) dump_android ;;
  macos)   dump_macos ;;
  server)  dump_server ;;
  *) echo "플랫폼: macos/android/server"; exit 1 ;;
esac

ls -la "$A" "$S" "$P" 2>/dev/null | awk '{print "  " $NF " (" $5 "B)"}'
echo "[a11y] 완료"