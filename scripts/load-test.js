// load-test.js — k6 부하 테스트 (AGENTS.md 7.8)
// usage: k6 run scripts/load-test.js  (서버 기동 후)
// thresholds: p95 < 300ms, error < 1%
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    smoke: {
      executor: 'per-vu-iterations',
      vus: 5,
      iterations: 10,
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<300'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE = __ENV.SERVER_BASE || 'http://localhost:3000';

export default function () {
  const health = http.get(`${BASE}/health`);
  check(health, { 'health 200': (r) => r.status === 200 });

  const auth = http.post(`${BASE}/auth/anon`, '{}', {
    headers: { 'Content-Type': 'application/json' },
  });
  check(auth, { 'auth/anon 200': (r) => r.status === 200 });
  const uuid = auth.json('uuid');
  const h = { Authorization: `Bearer ${uuid}`, 'Content-Type': 'application/json' };

  const me = http.get(`${BASE}/users/me`, { headers: h });
  check(me, { 'users/me 200': (r) => r.status === 200 });

  const episodes = http.get(`${BASE}/episodes`, { headers: h });
  check(episodes, { 'episodes 200': (r) => r.status === 200 });

  const quick = http.get(`${BASE}/episodes/quick`, { headers: h });
  check(quick, { 'episodes/quick 200': (r) => r.status === 200 });

  const review = http.get(`${BASE}/episodes/review`, { headers: h });
  check(review, { 'episodes/review 200': (r) => r.status === 200 });

  const ranking = http.get(`${BASE}/rankings/weekly`, { headers: h });
  check(ranking, { 'rankings/weekly 200': (r) => r.status === 200 });

  const debug = http.get(`${BASE}/debug/logs`);
  check(debug, { 'debug/logs 200': (r) => r.status === 200 });
}
