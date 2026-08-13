# TODO — Wordville 작업 추적

> platform: common/macos/android/server/web

## 진행중

| T | 작업 | platform | 상태 |
|---|------|----------|------|
| T0.2 | docs/ 문서 세트 작성 | common | ✅ 완료 |
| T0.3 | scripts/build_and_run.sh 디스패처 | common | ✅ 완료 (macos/android/server + pre-hook gitleaks/env-expiry + a11y 연동) |
| T0.4 | server/.env.example + env-expiry-check.sh | server | ✅ 완료 |
| T1.1 | server 뼈대 + /health + /debug/* | server | ✅ 완료 |
| T1.2 | Neon 스키마 + pgvector 마이그레이션 | server | ✅ 완료 |
| T1.3 | 익명 인증(UUID) + 닉네임 + DiceBear | server | ✅ 완료 |
| T1.4 | 게임 API (에피소드/채점/EXP/스트릭/랭킹) | server | ✅ 완료 |
| T2.1 | LLM 문제 생성 프롬프트 (JSON 구조화) | server | ✅ 완료 |
| T2.2 | 심판 검증 루프 (최대 2회 재생성) | server | ✅ 완료 |
| T2.3 | Render Cron + 시드 문제 100개 | server | ✅ 완료 (110문항 확보) |
| T2.4 | 오답 임베딩 + 문제 선별 | server | ✅ 완료 (Gemini 임베딩 384차원 + quick 개인화 매칭) |
| T3.1 | macOS 메뉴바 앱 골격 + 설정(Dock 토글) | macos | ✅ |
| T3.2 | SpriteKit 게임 루프 | macos | ✅ |
| T3.3 | 에셋 통합 + 폰트 + 오프라인 저장 | macos | ✅ (Kenney 스프라이트 + 폰트 3종 + 자동 flush) |
| T3.4 | 빌드 + 배포(/Users/lee/Applications) + 맥 테스트 | macos | 🔄 진행중 (선택 화면/아카이브/복습/랭킹 실기 확인 중) |
| T3.5 | 5콤보 보너스 (이펙트 + 보너스 EXP) | macos+server | ✅ 완료 (combo=5 → 28 EXP curl 검증) |
| T3.6 | 골든패스 (7일 연속 EXP 2배 + 배지 표시) | macos+server | ✅ 완료 (첫 정답 20 EXP / 두 번째 10 검증) |

## 대기 (Phase 1~6)

| T | 작업 | platform | 상태 |
|---|------|----------|------|
| T4.1 | Android libGDX 골격 + 게임 루프 이식 | android | ✅ (상태 머신 9종 + 폰트 + 도형 캐릭터) |
| T4.2 | API 연동 + 익명 UUID + 오프라인 큐 | android | ✅ (OkHttp + serialization + SharedPreferences 큐) |
| T4.3 | APK 빌드 | android | ✅ (debug APK, natives 4 ABI 포함) |
| T4.4 | Genymotion 테스트 + apk 배포 | android | ✅ (전 화면 실기 검증 + 폰트/아이콘 수정, 5콤보 배너는 실기 확인) |
| T5.1 | GitHub 랜딩 페이지 | web | ✅ (https://borasarang.github.io/Wordville/ — gh-pages) |
| T5.2 | GitHub Releases | common | ✅ (v0.3.0 — macOS zip + APK, build_and_run.sh release 구현) |
| T6.1 | a11y-dump + E2E + k6 검증 | common | ✅ (a11y-dump 3종 + e2e-server 10/10 + k6 p95=250ms 실패 0%) |
| T6.2 | DoD 체크리스트 + CHANGELOG | common | ✅ (CHANGELOG v0.3.0 갱신) |
| T6.3 | 세션 로그 + bd 정리 | common | ✅ (세션 로그 8줄 요약 작성) |
| T7.1 | 일일 리마인더 알림 실기 테스트 (macOS) | macos | ✅ (Apple Development 서명으로 UNErrorDomain Code=1 해결, 00:00 KST 예약 확인) |
| T7.2 | 서버 /debug 연동 실기 테스트 (패널 서버 탭) | macos | ✅ (Cmd+Shift+D → health db:up 106ms + 서버 로그 500건 + 2초 폴링) |
| T7.3 | 시드 100문항 → 사용자 실기 검증 | common | ⏳ (macOS/Android 5콤보 배너 + 골든패스 실기 확인 대기) |