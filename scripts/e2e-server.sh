#!/bin/bash
# e2e-server.sh — Wordville 서버 API E2E 스모크 (TC-E2E-SRV-001)
#   health → 익명인증 → 내 정보 → 오늘 에피소드 → 문제 → 채점 → 랭킹 → 복습 → 퀵 → debug
# usage: ./scripts/e2e-server.sh  (실패 시 exit 1, 각 단계 로그 출력)
set -euo pipefail

BASE="${SERVER_BASE:-http://localhost:${SERVER_PORT:-3000}}"
PASS=0; FAIL=0

ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
bad() { FAIL=$((FAIL+1)); echo "  ❌ $1 ($2)"; }

step() {
  local name="$1" result="$2" expect="$3"
  if [ "$result" = "$expect" ]; then ok "$name"; else bad "$name" "got=$result want=$expect"; fi
}

echo "[e2e-server] $BASE"

# 1. health
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/health")
step "GET /health" "$code" "200"

# 2. 익명 인증
AUTH=$(curl -s -X POST "$BASE/auth/anon")
TOKEN=$(echo "$AUTH" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('token',''))" 2>/dev/null || true)
[ -n "$TOKEN" ] && ok "POST /auth/anon (token=${TOKEN:0:20}…)" || bad "POST /auth/anon" "token 없음"
H="Authorization: Bearer $TOKEN"

# 3. 내 정보
code=$(curl -s -o /dev/null -w '%{http_code}' -H "$H" "$BASE/users/me")
step "GET /users/me" "$code" "200"

# 4. 오늘 에피소드
EP=$(curl -s -H "$H" "$BASE/episodes/today")
EPID=$(echo "$EP" | python3 -c "import sys,json; d=json.load(sys.stdin); d=d.get('data',d); print(d.get('id',''))" 2>/dev/null || true)
[ -n "$EPID" ] && ok "GET /episodes/today (id=$EPID)" || bad "GET /episodes/today" "episode 없음"

# 5. 문제 로드
Q=$(curl -s -H "$H" "$BASE/episodes/$EPID/questions")
QID=$(echo "$Q" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data',{}); qs=d.get('questions',[]); print(qs[0]['id'] if qs else '')" 2>/dev/null || true)
[ -n "$QID" ] && ok "GET /episodes/$EPID/questions (첫 문제=$QID)" || bad "GET questions" "문제 없음"

# 6. 채점 (첫 문제 정답 — choices의 isCorrect로 정답 확인 후 제출)
ANS=$(echo "$Q" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data',{}); qs=d.get('questions',[]); print(next((c['text'] for c in qs[0].get('choices',[]) if c.get('isCorrect')), '') if qs else '')" 2>/dev/null || true)
GRADE=$(curl -s -X POST -H "$H" -H 'Content-Type: application/json' \
  -d "{\"question_id\":$QID,\"selected\":\"$ANS\",\"combo\":1}" "$BASE/answers")
EARNED=$(echo "$GRADE" | python3 -c "import sys,json; d=json.load(sys.stdin); d=d.get('data',d); print(d.get('exp_gained',''))" 2>/dev/null || true)
[ -n "$EARNED" ] && ok "POST /answers (exp_gained=$EARNED)" || bad "POST /answers" "채점 응답 없음"

# 7. 랭킹
code=$(curl -s -o /dev/null -w '%{http_code}' -H "$H" "$BASE/rankings/weekly")
step "GET /rankings/weekly" "$code" "200"

# 8. 복습/퀵
code=$(curl -s -o /dev/null -w '%{http_code}' -H "$H" "$BASE/episodes/review")
step "GET /episodes/review" "$code" "200"
code=$(curl -s -o /dev/null -w '%{http_code}' -H "$H" "$BASE/episodes/quick")
step "GET /episodes/quick" "$code" "200"

# 9. debug
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/debug/logs")
step "GET /debug/logs" "$code" "200"

echo ""
echo "[e2e-server] 결과: ${PASS} 통과 / ${FAIL} 실패"
[ "$FAIL" -eq 0 ] || exit 1