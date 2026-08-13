# PLAN v0.1 — Wordville (글마을 달인: Daily Spelling Quest)

> 버전: v0.1 (MVP) | 날짜: 2026-08-13 | 작성자: BoRaSaRang
> 플랫폼: macOS / Android / Server (chrome/firefox/safari/web 제외)

---

## 1. 개요

일상 생활/장소(회사, 여행, 부엌)를 탐험하며 한글 맞춤법을 익히는 2D 픽셀 게임.
단어 암기가 아닌 **소설형 상황극 + 문장/맥락**을 파악해 푸는 문제를 제공한다.

- 게임명: Wordville (글마을 달인: Daily Spelling Quest)
- 배포: GitHub 랜딩 페이지 + GitHub Releases (스토어 배포 없음)
- 테스트: macOS = 실제 맥, Android = Genymotion 에뮬레이터

## 2. 결정 사항 (확정)

| 항목 | 결정 |
|------|------|
| macOS | Swift + SwiftUI + SpriteKit (네이티브) |
| Android | Kotlin + Jetpack Compose + libGDX (네이티브) |
| 게임 캔버스 | 360×780 고정 (갤럭시 S26: 6.3", 2340×1080 FHD+, density 3x 기준) |
| macOS 앱 형태 | 메뉴바 아이콘(NSStatusItem) + 설정에서 Dock 표시 토글 (기본 Dock 숨김) |
| 디자인 | 레트로 파스텔 픽셀 (16px 타일, Kenney CC0 에셋, 한글 폰트: 갈무리 11 + 둥근모꼴) |
| 백엔드 | Render (Node.js) |
| DB | Neon PostgreSQL + pgvector (오답 기억 RAG) |
| AI 문제 생성 | OpenRouter `deepseek/deepseek-v4-flash-free` (무료) |
| 문제 검증 | 심판 LLM 루프: 정답 명확성/난이도/선택지 헷갈림 평가, 미달 시 최대 2회 재생성 |
| 회원 | 익명 UUID + 닉네임 (가입 폼 없음), 아바타 = DiceBear (seed=user_id) |
| 앱 배포 위치 | macOS: `/Users/lee/Applications/Wordville.app`, Android: `/Users/lee/Applications/apk/` |
| MVP 범위 | 상황극 에피소드 + 문제 자동 생성 + 오답 기억 + 랭킹/아바타 (게임화·TTS·OCR은 v0.2+) |

## 3. 아키텍처

```
macOS(SpriteKit) ─┐                ┌─ Neon PostgreSQL + pgvector
Android(libGDX) ──┼─ REST API ────┼─ Render(Node.js) ──┼─ OpenRouter LLM(문제 생성/심판)
                  └ 360×780 캔버스  └ Cron(매일 00:00 KST)
```

- 게임 루프: 에피소드(상황극 시나리오) → 장면 지문 → 문제 출제(2~4지선다, 문장형) → 채점 → 결과(정답 시 다음 장면 / 오답 시 재도전)
- 오답 기억: 틀린 문제 유형 임베딩(pgvector) 저장 → 다음 문제 선별에 "틀린 유형 우선, 맞힌 유형 제외"
- 문제 생성: Render Cron → LLM JSON 생성(상황극 5문항) → 심판 검증 → DB 저장

## 4. 구현 단계

| T | 내용 | 플랫폼 | 상태 |
|---|------|--------|------|
| T0.1 | 저장소 구조 + .gitignore + GitHub 원격 연결 | 공통 | ✅ |
| T0.2 | docs/ 문서 세트 작성 | 공통 | 진행중 |
| T0.3 | scripts/build_and_run.sh 디스패처 | 공통 | - |
| T0.4 | server/.env.example + env-expiry-check.sh | server | - |
| T1.1 | server 뼈대 + /health + /debug/* | server | - |
| T1.2 | Neon 스키마 + pgvector 마이그레이션 | server | - |
| T1.3 | 익명 인증(UUID) + 닉네임 + DiceBear | server | - |
| T1.4 | 게임 API (에피소드/채점/EXP/스트릭/랭킹) | server | - |
| T2.1 | LLM 문제 생성 프롬프트 (JSON 구조화) | server | - |
| T2.2 | 심판 검증 루프 (최대 2회 재생성) | server | - |
| T2.3 | Render Cron + 시드 문제 100개 | server | - |
| T2.4 | 오답 임베딩 + 문제 선별 | server | - |
| T3.1 | macOS 메뉴바 앱 골격 + 설정(Dock 토글) | macos | - |
| T3.2 | SpriteKit 게임 루프 (상황극→문제→결과) | macos | - |
| T3.3 | 에셋 통합 + 폰트 + 오프라인 저장 | macos | - |
| T3.4 | 빌드 + /Users/lee/Applications 배포 + 맥 테스트 | macos | - |
| T4.1 | Android libGDX 골격 + 게임 루프 이식 | android | - |
| T4.2 | API 연동 + 익명 UUID + 오프라인 큐 | android | - |
| T4.3 | APK 빌드 | android | - |
| T4.4 | Genymotion 테스트 + /Users/lee/Applications/apk 배포 | android | - |
| T5.1 | GitHub 랜딩 페이지 | web | - |
| T5.2 | GitHub Releases (macOS zip + APK) | 공통 | - |
| T6.1 | a11y-dump + E2E + k6 검증 | 공통 | - |
| T6.2 | DoD 체크리스트 + CHANGELOG | 공통 | - |
| T6.3 | 세션 로그 + bd 정리 | 공통 | - |

## 5. 테스트 계획

- macOS: 실기 테스트 (게임 루프, 메뉴바, Dock 토글, DebugPanel Cmd+Shift+D)
- Android: Genymotion (Pixel 6 프로필 또는 S26 유사 프로필, adb install)
- Server: k6 부하 (p95 < 300ms), /health, /debug/*
- E2E: API 시나리오 (에피소드 조회 → 채점 → 랭킹 반영)
- 문제 품질: 심판 루프 통과율 모니터링, 시드 문제 100개로 폴백

## 6. 롤백 계획

- git revert + GitHub Releases 이전 버전 복원
- Render 배포 되돌리기 (이전 커밋 재배포)
- DB 마이그레이션 down 스크립트
- 문제 생성 장애 시: 시드 문제만 서빙 (Cron 비활성화)
- OpenRouter 키 만료/장애 시: error_message_ko.json 매핑 + 알림

## 7. 성능 예산

| 지표 | 목표 |
|------|------|
| macOS 콜드 스타트 | ≤ 1.5s |
| 게임 프레임 | 60fps |
| Server API P95 | ≤ 300ms |
| 메모리 (macOS/Android) | ≤ 300MB / ≤ 250MB |
| 문제 생성 비용 | $0 (무료 모델) |

## 8. 에러코드 목록 (예정)

- E-MAC-NET-1001: 서버 연결 실패
- E-AND-NET-1001: 서버 연결 실패
- E-SRV-GEN-1001: 문제 생성 실패 (심판 루프 초과)
- E-COM-GEN-1002: 오늘의 에피소드 없음 (시드 폴백)
- E-SRV-AUTH-1001: 익명 토큰 검증 실패

## 9. 권한 목록 (Android)

- 인터넷 (INTERNET) — API 통신
- (그 외 권한 없음. 스토어 배포 없음)

## 10. 캐시 정책 (AI 비용)

- LLM 응답 캐시: 생성된 문제는 DB 저장 후 재사용 (중복 생성 방지)
- 같은 (상황, 난이도) 요청은 7일 TTL 캐시
- hit_rate_target: 0.7

## 11. 오프라인 큐 설계

- 클라이언트: 답안 제출 실패 시 로컬 큐 저장 → 재연결 시 일괄 전송
- macOS: UserDefaults/파일, Android: SharedPreferences/Room
- 충돌 해결: 서버 timestamp 우선 (LWW)