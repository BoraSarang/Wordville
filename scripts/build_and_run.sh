#!/bin/bash
# build_and_run.sh — Wordville 빌드 디스패처 (AGENTS.md 18장 표준)
# usage:
#   ./build_and_run.sh debug macos      macOS 빌드 + /Users/lee/Applications 배포 + 실행
#   ./build_and_run.sh debug android    Android APK 빌드 + Genymotion 설치
#   ./build_and_run.sh debug server     Server 개발 모드
#   ./build_and_run.sh e2e server       Server API E2E 스모크 테스트
#   ./build_and_run.sh load server      k6 부하 테스트
#   ./build_and_run.sh release          GitHub Releases (macOS zip + APK)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# --- 환경 상수 ---
ADB="${ADB:-/opt/homebrew/bin/adb}"
APPS_DIR="${APPS_DIR:-/Users/lee/Applications}"
MAC_APP_NAME="Wordville.app"
APK_OUT="android/app/build/outputs/apk/debug/app-debug.apk"
SERVER_PORT="${SERVER_PORT:-3000}"

# --- 헬퍼 ---
log()  { echo "[build_and_run] $*"; }
fail() { echo "[build_and_run] ERROR: $*" >&2; exit 1; }

usage() {
  sed -n '2,9p' "$0"
  exit 1
}

# --- 서버 기동/테스트 ---
server_dev() {
  log "server dev 모드 시작 (port $SERVER_PORT)"
  cd "$ROOT/server"
  [ -f .env ] || cp .env.example .env
  npm install
  npm run dev
}

server_e2e() {
  log "server E2E 스모크 테스트"
  local base="${SERVER_BASE:-http://localhost:${SERVER_PORT}}"
  for ep in /health /debug/logs; do
    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' "$base$ep" || true)"
    log "GET $ep -> $code"
    [ "$code" = "200" ] || fail "E2E 실패: $ep -> $code"
  done
  log "E2E 통과"
}

server_load() {
  log "k6 부하 테스트"
  [ -x "$(command -v k6)" ] || fail "k6 미설치 (brew install k6)"
  k6 run scripts/load-test.js
}

# --- macOS ---
macos_debug() {
  [ -d "$ROOT/macos" ] || fail "macos/ 프로젝트가 아직 없습니다 (T3 이후 빌드 가능)"
  log "macOS 빌드 시작"
  cd "$ROOT/macos"
  xcodebuild -project Wordville.xcodeproj -scheme Wordville -configuration Debug \
    -derivedDataPath build/DerivedData build
  local built_app="build/DerivedData/Build/Products/Debug/$MAC_APP_NAME"
  [ -d "$built_app" ] || fail "빌드 산출물 없음: $built_app"
  rm -rf "$APPS_DIR/$MAC_APP_NAME"
  cp -R "$built_app" "$APPS_DIR/$MAC_APP_NAME"
  log "배포 완료: $APPS_DIR/$MAC_APP_NAME"
  open "$APPS_DIR/$MAC_APP_NAME"
}

# --- Android ---
android_debug() {
  [ -d "$ROOT/android" ] || fail "android/ 프로젝트가 아직 없습니다 (T4 이후 빌드 가능)"
  log "Android APK 빌드 시작"
  cd "$ROOT/android"
  ./gradlew :app:assembleDebug
  [ -f "$APK_OUT" ] || fail "APK 산출물 없음: $APK_OUT"
  mkdir -p "$APPS_DIR/apk"
  cp "$APK_OUT" "$APPS_DIR/apk/Wordville-debug.apk"
  log "APK 복사 완료: $APPS_DIR/apk/Wordville-debug.apk"

  # Genymotion 연결 확인
  if "$ADB" devices | grep -q "emulator"; then
    log "Genymotion 에뮬레이터 감지 — 설치 시도"
    "$ADB" install -r "$APPS_DIR/apk/Wordville-debug.apk" || log "설치 실패 (에뮬레이터 상태 확인)"
    log "adb shell am start -n com.wordville.game/.AndroidLauncher"
    "$ADB" shell am start -n com.wordville.game/.AndroidLauncher || true
  else
    log "Genymotion 미연결 — APK만 준비됨 (Genymotion 실행 후 ./build_and_run.sh debug android 재실행)"
  fi
}

# --- Release (T5.2 이후 구현) ---
release() {
  fail "release는 T5.2에서 구현 예정"
}

# --- 디스패처 ---
[ $# -ge 1 ] || usage
MODE="$1"; PLATFORM="${2:-}"

case "$MODE" in
  debug)
    case "$PLATFORM" in
      macos)   macos_debug ;;
      android) android_debug ;;
      server)  server_dev ;;
      *) fail "알 수 없는 플랫폼: $PLATFORM (macos/android/server)" ;;
    esac
    ;;
  e2e)
    case "$PLATFORM" in
      server) server_e2e ;;
      *) fail "e2e는 server만 지원" ;;
    esac
    ;;
  load)
    case "$PLATFORM" in
      server) server_load ;;
      *) fail "load는 server만 지원" ;;
    esac
    ;;
  release) release ;;
  *) usage ;;
esac

log "완료 ($MODE $PLATFORM)"
