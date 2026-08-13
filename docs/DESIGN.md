# DESIGN — Wordville 기술 설계

> 버전: v0.1 | 날짜: 2026-08-13 | 플랫폼별 섹션: macos / android / server

---

## 1. 공통 (Common)

### 1.1 게임 캔버스 규약
- **캔버스: 360×780 고정** (갤럭시 S26: 6.3", 2340×1080 FHD+, density 3x → 360×780dp)
- macOS도 동일 캔버스 360×780 렌더링 (Retina 2x 자동)
- 타일: 16px → 가로 22.5칸 / 세로 48.75칸
- 뷰포트: FitViewport (비율 유지, 여백은 배경색)

### 1.2 게임 상태 머신 (양 플랫폼 공통 로직)
```
BOOT → TITLE → EPISODE_SELECT → SCENE(지문 타이핑) → QUESTION(문제 패널)
     → RESULT_CORRECT(축하+EXP) → SCENE(다음 장면) / EPISODE_CLEAR
     → RESULT_WRONG(몬스터+재도전) → QUESTION(같은 문제)
     → (오프라인 시) QUEUE 저장 → 온라인 복구 시 FLUSH
```
- 디버그 로그: 각 전이 시 `[INFO] [FEATURE] <상태> 진입/완료` 필수 (AGENTS.md 19.1)

### 1.3 API 규약 (REST)
| 엔드포인트 | 메서드 | 설명 |
|-----------|--------|------|
| /health | GET | 헬스체크 |
| /auth/anon | POST | 익명 UUID 발급 |
| /users/me | GET/PATCH | 프로필(닉네임, 아바타) |
| /episodes/today | GET | 오늘의 에피소드 (문제 미포함) |
| /episodes/:id/questions | GET | 에피소드 문제 목록 |
| /answers | POST | 답안 제출 + 채점 (EXP/콤보/오답 기록) |
| /users/me/stats | GET | EXP/레벨/스트릭/오답 유형 |
| /rankings/weekly | GET | 주간 랭킹 + 리그 |
| /debug/logs, /debug/cache, /debug/queue | GET | 디버그 패널 (DEBUG 모드만) |

응답: `{ ok, data?, error?: { code, message } }`
에러코드: E-{PLATFORM}-{CAT}-{NUM4} + error_message_ko.json 매핑

### 1.4 디자인 스타일 (레트로 파스텔 픽셀)
- 팔레트: 크림 #FFF6E9 / 연두 #A8D672 / 복숭아 #FFB48A / 하늘 #8EC9F5 / 갈색 테두리 #5B4636
- 상황극: 배경 타일 스크롤 + 캐릭터(대기/걷기/기쁨/슬픔 프레임) + 하단 대화창 (타이핑, ▸ 진행)
- 문제 패널: 상단 "문제 출제!" 배너 → 지문 박스 → A~D 선택지 (픽셀 버튼)
- 정답: 초록 하이라이트 + 캐릭터 박수 + "EXP +10" 팝업
- 오답: 빨강 + 화면 흔들림 + 오답 몬스터 등장 → "다시 도전" 버튼
- 폰트: 갈무리 11 (픽셀 UI) / 둥근모꼴 (지문·선택지)

### 1.5 오프라인 큐
- 답안 제출 실패 시 로컬 큐 (macOS: 파일/UserDefaults, Android: SharedPreferences)
- 재연결 시 일괄 POST /answers (LWW: 서버 timestamp 우선)

---

## 2. Server (Render + Neon)

### 2.1 스택
- Node.js + Express (TypeScript), pg(pool) + pgvector, node-cron
- Render Cron: 매일 00:00 KST 문제 생성 잡

### 2.2 DB 스키마 (Neon PostgreSQL + pgvector)

```sql
CREATE EXTENSION IF NOT EXISTS vector;

-- 사용자
CREATE TABLE users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nickname      TEXT NOT NULL DEFAULT '글마을 주민',
  exp           INT NOT NULL DEFAULT 0,
  streak_days   INT NOT NULL DEFAULT 0,
  last_played   DATE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 상황극 에피소드 (하루 1개)
CREATE TABLE episodes (
  id            BIGSERIAL PRIMARY KEY,
  episode_date  DATE NOT NULL UNIQUE,       -- 2026-08-13
  category      TEXT NOT NULL,              -- home/office/travel/kitchen
  title         TEXT NOT NULL,
  scene_order   JSONB NOT NULL,             -- 장면 시퀀스 (지문/배경/캐릭터 상태)
  created_by    TEXT NOT NULL DEFAULT 'ai', -- ai | seed
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 문제
CREATE TABLE questions (
  id            BIGSERIAL PRIMARY KEY,
  episode_id    BIGINT REFERENCES episodes(id),
  scene_index   INT NOT NULL,               -- 장면 순서
  narrative     TEXT NOT NULL,              -- 문제 지문 (상황극 문장)
  choices       JSONB NOT NULL,             -- [{ text, isCorrect }] 2~4개
  explanation   TEXT NOT NULL,              -- 해설
  rule_key      TEXT NOT NULL,              -- 되_돼 / 띄어쓰기 / 이에요_예요 ...
  difficulty    INT NOT NULL DEFAULT 1,     -- 1~3
  judge_score   INT NOT NULL DEFAULT 0,     -- 심판 검증 점수
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 답안 기록
CREATE TABLE answers (
  id            BIGSERIAL PRIMARY KEY,
  user_id       UUID REFERENCES users(id),
  question_id   BIGINT REFERENCES questions(id),
  is_correct    BOOLEAN NOT NULL,
  selected      TEXT NOT NULL,
  answered_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 오답 유형 임베딩 (pgvector — 개인화 기억)
CREATE TABLE wrong_embeddings (
  user_id       UUID REFERENCES users(id),
  rule_key      TEXT NOT NULL,
  embedding     vector(384) NOT NULL,       -- rule_key 설명 임베딩
  wrong_count   INT NOT NULL DEFAULT 1,
  last_wrong_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, rule_key)
);

-- 랭킹 (주간)
CREATE TABLE weekly_rankings (
  week_key      TEXT NOT NULL,              -- 2026-W33
  user_id       UUID REFERENCES users(id),
  score         INT NOT NULL DEFAULT 0,
  league        TEXT NOT NULL DEFAULT 'bronze', -- bronze/silver/gold/platinum/diamond
  PRIMARY KEY (week_key, user_id)
);
```

### 2.3 문제 생성 파이프라인
1. Cron 00:00 KST → 카테고리(회사/여행/부엌/일상) 로테이션 결정
2. LLM 프롬프트: "오늘의 에피소드 스토리 + 문장형 문제 5개" → JSON 구조화 출력 (choices 3~4개, rule_key, explanation)
3. 심판 프롬프트 (temperature 0.0): 정답 명확성 / 난이도 / 선택지 헷갈림 점수 (0~10)
4. 판정: judge_score ≥ 7 통과, 미달 시 재생성 (최대 2회) → 실패 시 시드 문제 폴백
5. DB 저장 (episodes + questions)
6. 동일 날짜 재실행 방지: episode_date UNIQUE, 있으면 스킵

### 2.4 문제 선별 (개인화)
1. 사용자 wrong_embeddings 조회 (pgvector 코사인 유사도)
2. 틀린 rule_key 우선 순위 부여
3. answers에서 2회 이상 정답인 rule_key 제외
4. 난이도: 레벨 기반 (EXP에 비례)

### 2.5 채점/EXP
- 정답: +10 × 콤보 배율 (연속 정답 시 ×2, ×3...)
- 오답: EXP 없음 + wrong_embeddings upsert
- 스트릭: 오늘 1문제 이상 정답 시 +1, 놓치면 리셋
- 리그: 주간 점수 → 상위 20% 승급, 하위 20% 강등

### 2.6 디버그 패널 (Server)
- /debug/logs: 구조화 JSON 로그 (최근 500줄)
- /debug/cache: LLM 응답 캐시 통계 (hit rate)
- /debug/queue: 오프라인 큐 상태

---

## 3. macOS 앱 (Swift + SpriteKit)

### 3.1 앱 형태
- 메뉴바 전용 앱: NSStatusItem + NSPopover
  - 메뉴: 오늘의 에피소드 / 1문제 퀵플레이 / 프로필(닉네임·스트릭) / 설정… / 종료
- 설정 창 (SwiftUI): Dock 표시 토글 (`NSApp.setActivationPolicy`), 닉네임, 알림 토글
- 기본: `.accessory` (Dock 숨김) + 메뉴바 아이콘

### 3.2 화면 구성
- SpriteKit `SKView` 360×780 고정 윈도우 (또는 팝오버 내 게임)
- GameScene: 타일 맵 + 캐릭터 + 대화창 + 문제 패널 (상태 머신 1.2)
- DebugPanel: Cmd+Shift+D → 로그 오버레이

### 3.3 네트워크/저장
- URLSession + JSON 디코딩 (API 1.3)
- 로컬 저장: UserDefaults (uuid, 닉네임, 오프라인 큐)
- 에셋: Kenney CC0 팩 번들, 폰트 (갈무리 11, 둥근모꼴) 번들

### 3.4 디버그 로거
- DebugLogger (AGENTS.md 19장): [INFO]/[WARN]/[ERROR] + [FEATURE] + [PERF]
- Cmd+Shift+D로 패널 표시

---

## 4. Android 앱 (Kotlin + libGDX)

### 4.1 구조
- libGDX `FitViewport(360f, 780f)` — 스케일링 자동
- AndroidLauncher: `AndroidApplication` (immersive, 60fps)
- 씬/상태 머신: macOS와 동일 로직 이식 (1.2)
- UI: libGDX Scene2D (터치 입력)
- 로컬 저장: SharedPreferences (uuid, 닉네임, 오프라인 큐)
- 네트워크: OkHttp + kotlinx.serialization
- DebugPanel: 5탭 또는 adb 로그

### 4.2 에셋
- 동일 Kenney CC0 에셋 리소스 (res/raw 또는 assets)
- 폰트: 갈무리 11 / 둥근모꼴 TTF

---

## 5. GitHub 랜딩 (web)

- 정적 페이지: 게임 소개, 스크린샷, 특징, 다운로드 버튼
  - macOS: GitHub Releases .app.zip
  - Android: GitHub Releases .apk
- DiceBear 아바타 미리보기
- docs/ 링크 (PRD)

---

## 6. 보안

- OpenRouter API 키: server/.env 전용 (커밋 금지, env-expiry-check.sh로 만료 체크)
- 익명 토큰: UUID → 서버 JWT (만료 30일, 갱신 엔드포인트)
- Rate Limit: 100 req/min (익명 토큰 기준), /health 예외
- 로그에 키/토큰 마스킹