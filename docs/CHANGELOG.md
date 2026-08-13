# CHANGELOG — Wordville

## [v0.2.0] — 2026-08-13 (MVP 기능 완성 — 시드 110문항 + 개인화 + 비주얼)

### Added [server]
- 시드 문제 110문항 확보 (22 에피소드, 8/1~8/22) — Gemini 3.1-flash-lite 생성 + 심판 루프 (T2.3)
- Gemini 임베딩 전환: gemini-embedding-2 (384차원) — OpenRouter 크레딧 의존 제거 (T2.4)
- 퀵플레이 개인화: 자주 틀리는 유형 우선 출제 + 2회 이상 정답 유형 제외 (DESIGN 2.4)
- LLM 체인 v0.4: gemini-3.1-flash-lite 1순위 (3.6-flash 일일 쿼터 소진 대응, 503/429 자동 재시도 3회)
- /debug/cache 실제 통계 (gemini+zen+openrouter LRU 통합)

### Added [macos]
- 오프라인 큐 자동 flush: 앱 시작 시 + 온라인 복구 감지 (NWPathMonitor) (T3.3)
- 일일 리마인더 알림: 매일 00:00 KST 반복 (NotificationManager, 설정 토글 연동)
- 디버그 패널 서버 탭: /debug/logs + /debug/cache + /debug/queue 조회
- 설정 화면 통계 표시: 정답/오답 수 + 자주 틀리는 유형
- Kenney Roguelike 스프라이트 (CC0): 캐릭터/몬스터 셀 2종 + idle 바운스 애니메이션
- 비주얼 v0.2: 정답 EXP 팝업 + 오답 화면 흔들림 + 몬스터 등장

### Fixed
- Gemini 503(고수요)/429(쿼터) 시 재시도 3회 + Zen 폴백 체인 복원

## [v0.1.0] — 2026-08-13 (MVP 개발 시작)

### Added [common]
- 프로젝트 초기화: 저장소 구조, .gitignore, GitHub 원격 연결 (T0.1)
- 문서 세트: PLAN / TODO / PRD / DESIGN / AI_MODELS.json / CHANGELOG (T0.2)
- 게임 컨셉 확정: 소설형 상황극 + 문장형 맞춤법 문제 (360×780 캔버스, 레트로 파스텔 픽셀)
- AI 모델 확정: openrouter/deepseek/deepseek-v4-flash-free (무료, vision_support=false)

### Planned
- server: Render(Node.js) + Neon(pgvector) API + 문제 자동 생성 파이프라인 (T1.x, T2.x)
- macos: 메뉴바 앱(SpriteKit, 360×780) (T3.x)
- android: libGDX 앱 (T4.x)
- web: GitHub 랜딩 페이지 (T5.x)