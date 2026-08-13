# PLAN v0.3 — common (게임화 보너스 + 문서 정비)

> 작성: 2026-08-13 | 플랫폼: macos + server (Android는 v0.3 마무리 후 착수)

## 1. 개요
- v0.2.1까지의 실제 구현(선택 화면/아카이브/복습/랭킹/아이콘/크래시 수정)을 문서에 반영
- PRD 4장 게임화 중 남은 항목: 5콤보 보너스 + 골든패스 (데일리 미션은 Android 후)
- 마무리 후 Android 포팅(T4.x) 착수

## 2. 결정 사항 (사용자 확인 완료)
| 항목 | 결정 |
|------|------|
| 5콤보 보너스 | 단순 보너스: "🔥 5콤보!" 이펙트 + 보너스 EXP +10 (인벤토리 없음) |
| 골든패스 | streak_days ≥ 7일 때 오늘 첫 정답 EXP 2배 + 배지 표시 (스키마 변경 없음, 파생 규칙) |
| 데일리 미션 | 제외 (Android 포팅 후) |

## 3. 구현 단계
| T | 내용 | platform | 검증 |
|---|------|----------|------|
| T3.5 | 5콤보 보너스: 서버 `/answers` 공식 `10+min((combo-1)*2,10)+(combo≥5?10:0)`, 클라 combo==5 시 spawnComboBanner + EXP 팝업 | macos+server | curl combo=5 → exp_gained=28 |
| T3.6 | 골든패스: 서버 오늘 첫 정답 && newStreak≥7 → expGained×2 (응답 golden_pass), `/users/me` 파생 필드, 클라 선택 화면/팝오버 배지 + 클리어 토스트 | macos+server | streak 7일 시뮬 + 첫 정답 → 2배 |
| T6.2 | v0.3 CHANGELOG + TODO 갱신 | common | — |

## 4. 테스트 계획
- 서버: curl (검증봇 계정) — combo=5 제출 exp_gained 확인 / streak=7 세팅 후 첫 정답 2배 확인 / 응답 golden_pass
- macOS: 5연속 정답 → "🔥 5콤보!" 이펙트 + EXP 팝업 / streak≥7 사용자 프로필에 👑 배지
- 실기: 사용자 퀵플레이 5연속 정답

## 5. 롤백
- 서버: game.ts 채점 공식 git revert → 재빌드/재시작
- macOS: GameScene 이펙트 제거, 프로필 배지 제거 → 재빌드/재배포

## 6. 이후 (v0.3 마무리 후)
- Android 포팅: PLAN_v0.3_android.md 신규 + T4.1~T4.4
- Render Cron (T2.3): 매일 00:00 KST 문제 생성 자동화