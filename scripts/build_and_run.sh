#!/bin/bash
# build_and_run.sh — Wordville 빌드 디스패처 (AGENTS.md 18장 표준)
# usage:
#   ./scripts/build_and_run.sh debug macos      macOS 빌드 + /Users/lee/Applications 배포 + 실행
#   ./scripts/build_and_run.sh debug android    Android APK 빌드 + Genymotion 설치
#   ./scripts/build_and_run.sh debug server     Server 개발 모드 (foreground)
#   ./scripts/build_and_run.sh e2e server       Server API E2E 스모크 테스트
#   ./scripts/build_and_run.sh load server      k6 부하 테스트 (k6 미설치 시 curl 대체 안내)
#   ./scripts/build_and_run.sh a11y {platform}  a11y-dump 3종 세트 (macos/android/server)
#   ./scripts/build_and_run.sh release          GitHub Releases (T5.2 구현 예정)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# --- 환경 상수 ---
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="${ADB:-$ANDROID_HOME/platform-tools/adb}"
JAVA_HOME_DEFAULT="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
APPS_DIR="${APPS_DIR:-/Users/lee/Applications}"
MAC_APP_NAME="글마을 달인.app"
PKG="com.borasarang.wordville"
APK_OUT="android/app/build/outputs/apk/debug/app-debug.apk"
SERVER_PORT="${SERVER_PORT:-3000}"
VERSION="${VERSION:-v0.3}"

# --- 헬퍼 ---
log()  { echo "[build_and_run] $*"; }
fail() { echo "[build_and_run] ERROR: $*" >&2; exit 1; }

usage() {
  sed -n '2,12p' "$0"
  exit 1
}

# --- pre-hook: 시크릿/품질 게이트 ---
pre_hook() {
  log "pre-hook: env-expiry-check + gitleaks"
  ./scripts/env-expiry-check.sh || fail "시크릿 만료 체크 실패"
  if [ -x "$(command -v gitleaks)" ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    gitleaks git --no-banner --exit-code=0 2>/dev/null \
      || gitleaks detect --no-banner --source . --log-opts=--all 2>/dev/null \
      || log "gitleaks: 리포 전체 스캔 경고 (커밋 검증은 훅에서)"
  else
    log "gitleaks 미설치 — 스킵 (brew install gitleaks)"
  fi
}

# --- 서버 ---
server_dev() {
  log "server dev 모드 시작 (port $SERVER_PORT)"
  cd "$ROOT/server"
  [ -f .env ] || { cp .env.example .env; log ".env 생성됨 (내용 확인 필수)"; }
  npm install
  exec npm run dev
}

server_e2e() {
  log "server E2E 스모크 테스트"
  ./scripts/e2e-server.sh
}

server_load() {
  log "k6 부하 테스트"
  if [ -x "$(command -v k6)" ]; then
    k6 run scripts/load-test.js
  else
    fail "k6 미설치 (brew install k6) — 또는 ./scripts/e2e-server.sh로 기능 스모크만"
  fi
}

# --- macOS ---
macos_debug() {
  [ -d "$ROOT/macos" ] || fail "macos/ 프로젝트 없음"
  log "macOS 빌드 시작"
  cd "$ROOT/macos"
  xcodebuild -project Wordville.xcodeproj -scheme Wordville -configuration Debug \
    -derivedDataPath build/DerivedData build
  local built_app="build/DerivedData/Build/Products/Debug/Wordville.app"
  [ -d "$built_app" ] || fail "빌드 산출물 없음: $built_app"
  rm -rf "$APPS_DIR/$MAC_APP_NAME"
  cp -R "$built_app" "$APPS_DIR/$MAC_APP_NAME"
  log "배포 완료: $APPS_DIR/$MAC_APP_NAME"
  open "$APPS_DIR/$MAC_APP_NAME"
  sleep 3
  ./scripts/a11y-dump.sh macos "$VERSION" || log "a11y-dump 경고 (선택)"
}

# --- Android ---
android_debug() {
  [ -d "$ROOT/android" ] || fail "android/ 프로젝트 없음"
  [ -d "$JAVA_HOME_DEFAULT" ] && export JAVA_HOME="$JAVA_HOME_DEFAULT"
  log "Android APK 빌드 시작 (JAVA_HOME=${JAVA_HOME:-시스템})"
  cd "$ROOT/android"
  ./gradlew :app:assembleDebug
  [ -f "$APK_OUT" ] || fail "APK 산출물 없음: $APK_OUT"
  mkdir -p "$APPS_DIR/apk"
  cp "$APK_OUT" "$APPS_DIR/apk/Wordville-debug.apk"
  log "APK 복사 완료: $APPS_DIR/apk/Wordville-debug.apk"

  if "$ADB" devices | grep -q "127.0.0.1:6555"; then
    log "Genymotion 감지 — 설치"
    "$ADB" -s 127.0.0.1:6555 install -r "$APK_OUT" || log "설치 실패 (에뮬레이터 상태 확인)"
    "$ADB" -s 127.0.0.1:6555 shell am force-stop com.talkmance.app || true
    "$ADB" -s 127.0.0.1:6555 shell am start -n "$PKG/.AndroidLauncher" || true
    sleep 6
    ./scripts/a11y-dump.sh android "$VERSION" || log "a11y-dump 경고 (선택)"
  else
    log "Genymotion 미연결 — APK만 준비됨 (Genymotion 실행 후 재실행)"
  fi
}

# --- Release (T5.2) ---
release() {
  [ -x "$(command -v gh)" ] || fail "gh 미설치 (brew install gh + gh auth login)"
  local tag="${TAG:-v0.3.0}"
  local dir="/tmp/wordville-release"
  rm -rf "$dir" && mkdir -p "$dir"
  log "아티팩트 준비: $dir"
  ditto -c -k --keepParent "$APPS_DIR/$MAC_APP_NAME" "$dir/Wordville-macOS-$tag.zip"
  [ -f "$APK_OUT" ] && cp "$APK_OUT" "$dir/Wordville-android-$tag.apk" || fail "APK 없음"
  ls -la "$dir"
  gh release create "$tag" --title "$tag" --notes "글마을 달인 릴리스 $tag" \
    "$dir/Wordville-macOS-$tag.zip" "$dir/Wordville-android-$tag.apk"
  log "릴리스 완료: https://github.com/BoraSarang/Wordville/releases/tag/$tag"
}

# --- 디스패처 ---
[ $# -ge 1 ] || usage
MODE="$1"; PLATFORM="${2:-}"

case "$MODE" in
  debug)
    pre_hook
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
  a11y)
    case "$PLATFORM" in
      macos|android|server) ./scripts/a11y-dump.sh "$PLATFORM" "$VERSION" ;;
      *) fail "a11y 플랫폼: macos/android/server" ;;
    esac
    ;;
  release) release ;;
  *) usage ;;
esac

log "완료 ($MODE $PLATFORM)"
