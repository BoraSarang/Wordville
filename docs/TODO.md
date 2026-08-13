# TODO — Wordville 작업 추적

> platform: common/macos/android/server/web

## 진행중

| T | 작업 | platform | 상태 |
|---|------|----------|------|
| T0.1 | 저장소 구조 + .gitignore + GitHub 원격 연결 | common | ✅ 완료 |
| T0.2 | docs/ 문서 세트 작성 | common | 🔄 진행중 |
| T0.3 | scripts/build_and_run.sh 디스패처 | common | ⏳ 대기 |
| T0.4 | server/.env.example + env-expiry-check.sh | server | ⏳ 대기 |

## 대기 (Phase 1~6)

| T | 작업 | platform | 상태 |
|---|------|----------|------|
| T1.1 | server 뼈대 + /health + /debug/* | server | ⏳ |
| T1.2 | Neon 스키마 + pgvector 마이그레이션 | server | ⏳ |
| T1.3 | 익명 인증(UUID) + 닉네임 + DiceBear | server | ⏳ |
| T1.4 | 게임 API (에피소드/채점/EXP/스트릭/랭킹) | server | ⏳ |
| T2.1 | LLM 문제 생성 프롬프트 (JSON 구조화) | server | ⏳ |
| T2.2 | 심판 검증 루프 (최대 2회 재생성) | server | ⏳ |
| T2.3 | Render Cron + 시드 문제 100개 | server | ⏳ |
| T2.4 | 오답 임베딩 + 문제 선별 | server | ⏳ |
| T3.1 | macOS 메뉴바 앱 골격 + 설정(Dock 토글) | macos | ✅ |
| T3.2 | SpriteKit 게임 루프 | macos | ✅ |
| T3.3 | 에셋 통합 + 폰트 + 오프라인 저장 | macos | ⏳ |
| T3.4 | 빌드 + 배포(/Users/lee/Applications) + 맥 테스트 | macos | ⏳ |
| T4.1 | Android libGDX 골격 + 게임 루프 이식 | android | ⏳ |
| T4.2 | API 연동 + 익명 UUID + 오프라인 큐 | android | ⏳ |
| T4.3 | APK 빌드 | android | ⏳ |
| T4.4 | Genymotion 테스트 + apk 배포 | android | ⏳ |
| T5.1 | GitHub 랜딩 페이지 | web | ⏳ |
| T5.2 | GitHub Releases | common | ⏳ |
| T6.1 | a11y-dump + E2E + k6 검증 | common | ⏳ |
| T6.2 | DoD 체크리스트 + CHANGELOG | common | ⏳ |
| T6.3 | 세션 로그 + bd 정리 | common | ⏳ |