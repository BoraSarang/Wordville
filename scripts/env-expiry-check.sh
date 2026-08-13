#!/bin/bash
# env-expiry-check.sh — .env.example의 시크릿 만료일 체크 (AGENTS.md 8.12장)
# - .env.example 내 "# expires: YYYY-MM-DD" 파싱
# - 만료 30일 전: WARN / 만료: ERROR (빌드 실패)
# usage: ./scripts/env-expiry-check.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TODAY="$(date +%Y-%m-%d)"
FAIL=0
WARN=0

check_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  echo "[env-expiry] $file"
  while IFS= read -r line; do
    case "$line" in
      *"# expires:"*)
        local key expires
        key="$(echo "$line" | sed 's/=.*//; s/^# *//')"
        expires="$(echo "$line" | sed 's/.*# expires: *//; s/ .*//')"
        local days=$(( ($(date -j -f "%Y-%m-%d" "$expires" +%s) - $(date -j -f "%Y-%m-%d" "$TODAY" +%s)) / 86400 ))
        if [ "$days" -lt 0 ]; then
          echo "  [ERROR] $key 만료됨 ($expires)"
          FAIL=1
        elif [ "$days" -le 30 ]; then
          echo "  [WARN]  $key ${days}일 후 만료 ($expires)"
          WARN=1
        else
          echo "  [OK]    $key (${days}일 유효)"
        fi
        ;;
    esac
  done < "$file"
}

check_file "$ROOT/server/.env.example"
check_file "$ROOT/.env.example"

if [ "$FAIL" -eq 1 ]; then
  echo "[env-expiry] FAIL: 만료된 시크릿 존재 — 빌드 중단"
  exit 1
fi
[ "$WARN" -eq 1 ] && echo "[env-expiry] WARN: 곧 만료되는 시크릿 있음 (30일 내 갱신)"
echo "[env-expiry] 완료"