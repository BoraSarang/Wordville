# PLAN v0.3 — Android 포팅 (libGDX)

> 작성: 2026-08-13 | 플랫폼: android | 기반: macOS v0.3 동일 게임 로직 (360×780, 상태 머신 동일)

## 1. 개요
- macOS(SpriteKit)로 검증된 Wordville v0.3을 Android(libGDX)로 포팅
- 서버 API는 이미 공용 (REST + 익명 UUID) — 그대로 사용
- 에셋/폰트: Kenney 스프라이트 + 둥근모꼴/갈무리 TTF 재사용 (FreeType)
- APK 빌드 + 에뮬레이터(Genymotion/AVD) 테스트 후 배포

## 2. 결정 사항
- libGDX 단일 Android 모듈 (core/lwjgl 분리 없음 — macOS는 Swift라 공유 불가)
- Scene2D UI + FitViewport(360, 780) — macOS 캔버스와 동일
- 네트워크: OkHttp + kotlinx.serialization (동기 블로킹 + 코루틴)
- 로컬 저장: SharedPreferences (uuid, 닉네임, 서버 주소, 오프라인 큐 JSON)
- 스프라이트: gdx-freetype (TTF) + kenney PNG (SpriteBatch/TextureRegion)
- 상태 머신: macOS GameState 그대로 이식 (splash/selection/archive/ranking/scene/question/resultCorrect/resultWrong/clear)

## 3. 구현 단계
| T | 내용 | 검증 |
|---|------|------|
| T4.1 | Gradle 프로젝트 골격 + AndroidLauncher + libGDX 스테이지/뷰포트 + splash/선택 화면 | 에뮬레이터 실행 |
| T4.2 | API 연동 (auth/episodes/answers/quick/review/rankings) + SharedPreferences + 오프라인 큐 | curl 동일 응답 디코딩 |
| T4.3 | 게임 루프 이식: 지문 타이핑/문제/결과/몬스터/콤보/골든패스 + 에셋·폰트 | macOS와 동일 시나리오 |
| T4.4 | APK 빌드 + 에뮬레이터 테스트 + 배포 | release APK 생성 |

## 4. 환경
- JDK 17 (brew openjdk@17, Android Gradle Plugin 8.x)
- Android SDK: ~/Library/Android/sdk (platforms/build-tools 존재)
- Gradle 9.6.1 (wrapper로 고정 예정 — AGP 호환 버전 확인 필요)

## 5. 롤백
- Gradle 프로젝트는 격리 폴더(android/) — macOS/서버 영향 없음, 삭제 시 복구 자유
- 서버 변경 없음 (기존 API 재사용)

## 6. 이후
- Render Cron (T2.3) / 데일리 미션 / T5 랜딩·Releases