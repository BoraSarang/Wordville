// 마이그레이션 (AGENTS.md 20.3: up/down 분리)
// usage: npm run migrate -- up|down
import { pool } from '../db.js';
import { logger } from '../logger.js';

const UP = `
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nickname      TEXT NOT NULL DEFAULT '글마을 주민',
  exp           INT NOT NULL DEFAULT 0,
  streak_days   INT NOT NULL DEFAULT 0,
  last_played   DATE,
  league        TEXT NOT NULL DEFAULT 'bronze',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS episodes (
  id            BIGSERIAL PRIMARY KEY,
  episode_date  DATE NOT NULL UNIQUE,
  category      TEXT NOT NULL,
  title         TEXT NOT NULL,
  scene_order   JSONB NOT NULL,
  created_by    TEXT NOT NULL DEFAULT 'ai',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS questions (
  id            BIGSERIAL PRIMARY KEY,
  episode_id    BIGINT REFERENCES episodes(id) ON DELETE CASCADE,
  scene_index   INT NOT NULL,
  narrative     TEXT NOT NULL,
  choices       JSONB NOT NULL,
  explanation   TEXT NOT NULL,
  rule_key      TEXT NOT NULL,
  difficulty    INT NOT NULL DEFAULT 1,
  judge_score   INT NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_questions_episode ON questions(episode_id, scene_index);

CREATE TABLE IF NOT EXISTS answers (
  id            BIGSERIAL PRIMARY KEY,
  user_id       UUID REFERENCES users(id) ON DELETE CASCADE,
  question_id   BIGINT REFERENCES questions(id) ON DELETE CASCADE,
  is_correct    BOOLEAN NOT NULL,
  selected      TEXT NOT NULL,
  answered_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_answers_user ON answers(user_id, answered_at);

CREATE TABLE IF NOT EXISTS wrong_embeddings (
  user_id       UUID REFERENCES users(id) ON DELETE CASCADE,
  rule_key      TEXT NOT NULL,
  embedding     vector(384) NOT NULL,
  wrong_count   INT NOT NULL DEFAULT 1,
  last_wrong_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, rule_key)
);

CREATE TABLE IF NOT EXISTS weekly_rankings (
  week_key      TEXT NOT NULL,
  user_id       UUID REFERENCES users(id) ON DELETE CASCADE,
  score         INT NOT NULL DEFAULT 0,
  PRIMARY KEY (week_key, user_id)
);
`;

const DOWN = `
DROP TABLE IF EXISTS weekly_rankings;
DROP TABLE IF EXISTS wrong_embeddings;
DROP TABLE IF EXISTS answers;
DROP TABLE IF EXISTS questions;
DROP TABLE IF EXISTS episodes;
DROP TABLE IF EXISTS users;
`;

const mode = process.argv[2] ?? 'up';

async function main() {
  if (mode === 'up') {
    await pool.query(UP);
    logger.feature('migrate', 'up 완료 — 스키마 생성');
  } else if (mode === 'down') {
    await pool.query(DOWN);
    logger.feature('migrate', 'down 완료 — 스키마 제거');
  } else {
    logger.error('migrate: up|down 지정 필요');
    process.exit(1);
  }
  const r = await pool.query(
    "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename",
  );
  logger.info('현재 테이블', { tables: r.rows.map((x) => x.tablename) });
  await pool.end();
}

main().catch((err) => {
  logger.error('migrate 실패', { error: err instanceof Error ? err.message : String(err) });
  process.exit(1);
});