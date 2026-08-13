# CHANGELOG — Wordville

## [v0.3.0] — 2026-08-13 (게임화 보너스 + Android 포팅)

### Added [android]
- libGDX 포팅 골격: 상태 머신 9종 (splash/selection/archive/ranking/scene/question/result/clear) 1:1 이식
- FitViewport(360×780) y-up 카메라 + 갈무리11/둥근모꼴 FreeType 폰트 + 코드 도형 캐릭터/몬스터
- API 클라이언트 (OkHttp + kotlinx.serialization): auth/episodes/quick/review/rankings/answers + 오프라인 큐(SharedPreferences JSON)
- 터치 입력 (InputProcessor), 뒤로가기 → 선택 화면, Genymotion 호스트 주소(10.0.3.2)
- 네이티브: gdx-platform/gdx-freetype-platform natives → jniLibs 자동 추출 (arm64/armv7/x86/x86_64)
- Genymotion 실기 검증: 선택/에피소드/문제/결과/복습/랭킹(myRank=3)/아카이브(22개)/퀵플레이 전 화면 동작 확인, EXP 콤보 공식 (10/12) 정확

### Added [macos]
- 5콤보 보너스: "🔥 5콤보! 보너스 +10 EXP" 배너 (스케일 팝 애니메이션)
- 골든패스 배지: 선택 화면 + 팝오버 헤더 "👑골든패스", 클리어 화면 안내 문구
- EXP 공식 일치: 10 + 콤보 증분(최대 10) + 5콤보 보너스 10

### Added [server]
- /answers: 5콤보 보너스 (+10) + 골든패스 (streak≥7 & 오늘 첫 정답 → EXP 2배, 응답 golden_pass)
- /users/me: golden_pass 파생 필드

### Added [common]
- 도구/표준 정비 (T0.3, T6.1): build_and_run.sh 디스패처 정비 (패키지명 수정, JAVA_HOME/ANDROID_HOME 자동 감지, pre-hook = env-expiry + gitleaks, a11y 연동), a11y-dump.sh 3종 세트 (macos/android/server — .a11y.txt + .storage.json + .perf.json), e2e-server.sh API 스모크 10/10 통과, screenshot.sh, load-test.js (k6)
- Android 한글 폰트 수정: FreeType characters에 전체 한글(U+AC00~D7A3) 명시 + 런처 아이콘 (벡터)

### Fixed
- (없음)

## [v0.2.1] — 2026-08-13 (게임 선택 화면 + 아카이브/복습 + 게임 내 랭킹)

### Added [macos]
- 스플래시 화면(1.2s) + 게임 선택 화면 (오늘의 에피소드/퀵플레이/과거 에피소드/오답 복습/주간 랭킹)
- 과거 에피소드 아카이브: 페이지 6개 목록(날짜·제목·✅완료), ▲▼ 이동, 다시 도전
- 주간 랭킹 게임 내 화면: Top 10 + 내 순위 배너 (순위/이름/점수)
- 팝오버 메뉴 "게임 열기 (메인 화면)" 항목
- 앱 아이콘: 픽셀 아트(책+연필+'글') AppIcon.icns + 수동 Info.plist 전환
- 중복 실행 방지 (NSRunningApplication 번들 ID)
- Dock 아이콘 클릭 시 게임 윈도우 재표시 (applicationShouldHandleReopen)

### Added [server]
- GET /episodes: 에피소드 목록 (KST 날짜, played 포함)
- GET /episodes/review: 오답 복습 5문제 (오답 rule_key 우선)
- /episodes 날짜 KST 변환 (to_char UTC→Asia/Seoul)

### Fixed
- Dock 클릭 크래시: 닫힌 NSWindow dangling 포인터 → windowWillClose에서 프로퍼티 해제 + 재생성
- 주간 랭킹 팝오버 가로 잘림 (420 고정 → 360 유연)
- 랭킹 행 리그 배지 제거 (순위/이름/점수만)
- 랭킹 팝오버 알림 순환 제거

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