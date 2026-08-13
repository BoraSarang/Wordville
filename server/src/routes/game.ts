import { Router } from 'express';
import { pool } from '../db.js';
import { authMiddleware } from '../auth.js';
import { logger } from '../logger.js';
import { recordWrongRule } from '../ai/embed.js';
import type { AuthedRequest } from '../auth.js';

export const gameRouter = Router();

const WEEK_KEY = (d: Date = new Date()): string => {
  const day = (d.getDay() + 6) % 7;
  const monday = new Date(d);
  monday.setDate(d.getDate() - day);
  return monday.toISOString().slice(0, 10);
};

const LEAGUES: Record<string, { min: number; max: number }> = {
  bronze: { min: 0, max: 99 },
  silver: { min: 100, max: 299 },
  gold: { min: 300, max: 599 },
  diamond: { min: 600, max: Infinity },
};

function leagueOf(exp: number): string {
  for (const [name, range] of Object.entries(LEAGUES)) {
    if (exp >= range.min && exp < range.max) return name;
  }
  return 'bronze';
}

// GET /episodes — 에피소드 아카이브 목록 (날짜 내림차순 + 플레이 여부)
gameRouter.get('/episodes', authMiddleware, async (req, res) => {
  const { userId } = req as AuthedRequest;
  logger.feature('episodes.list', '진입', { userId });
  const r = await pool.query(
    `SELECT e.id, to_char(e.episode_date AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Seoul', 'YYYY-MM-DD') AS episode_date, e.category, e.title,
            EXISTS(SELECT 1 FROM questions q JOIN answers a ON a.question_id = q.id
                   WHERE q.episode_id = e.id AND a.user_id = $1 AND a.is_correct) AS played
     FROM episodes e ORDER BY e.episode_date DESC LIMIT 60`,
    [userId],
  );
  logger.feature('episodes.list', '완료', { count: r.rowCount });
  res.json({
    ok: true,
    data: r.rows.map((row: any) => ({ ...row, id: Number(row.id), played: Boolean(row.played) })),
  });
});

// GET /episodes/review — 오답 복습 (틀린 유형 문제 우선 5개, 부족분 랜덤)
gameRouter.get('/episodes/review', authMiddleware, async (req, res) => {
  const { userId } = req as AuthedRequest;
  logger.feature('episodes.review', '진입', { userId });
  const wrong = await pool.query(
    `SELECT rule_key FROM wrong_embeddings
     WHERE user_id = $1 ORDER BY wrong_count DESC, last_wrong_at DESC LIMIT 5`,
    [userId],
  );
  const keys = wrong.rows.map((r: any) => r.rule_key);
  let rows: any[] = [];
  if (keys.length > 0) {
    const r = await pool.query(
      `SELECT q.id, q.scene_index, q.narrative, q.choices, q.explanation
       FROM questions q WHERE q.rule_key = ANY($1) ORDER BY random() LIMIT 5`,
      [keys],
    );
    rows = r.rows;
  }
  if (rows.length < 5) {
    const r = await pool.query(
      `SELECT q.id, q.scene_index, q.narrative, q.choices, q.explanation
       FROM questions q ORDER BY random() LIMIT $1`,
      [5 - rows.length],
    );
    rows = [...rows, ...r.rows];
  }
  logger.feature('episodes.review', '완료', { count: rows.length, wrong_keys: keys });
  res.json({
    ok: true,
    data: {
      title: '오답 복습',
      questions: rows.map((q: any) => ({ ...q, id: Number(q.id) })),
    },
  });
});

// GET /episodes/today — 오늘의 에피소드 (문제 미포함)
gameRouter.get('/episodes/today', authMiddleware, async (_req, res) => {
  logger.feature('episodes.today', '진입');
  const today = new Date().toISOString().slice(0, 10);
  const r = await pool.query(
    `SELECT id, episode_date, category, title, scene_order
     FROM episodes WHERE episode_date = $1 LIMIT 1`,
    [today],
  );
  if (r.rowCount === 0) {
    res.status(404).json({ ok: false, error: { code: 'E-SRV-GEN-1001', message: '오늘의 문제를 만들지 못했습니다. 잠시 후 다시 시도해 주세요.' } });
    return;
  }
  logger.feature('episodes.today', '완료', { episodeId: r.rows[0].id });
  const episode = r.rows[0];
  res.json({ ok: true, data: { ...episode, id: Number(episode.id) } });
});

// GET /episodes/:id/questions — 에피소드 문제 목록
gameRouter.get('/episodes/:id/questions', authMiddleware, async (req, res) => {
  const episodeId = req.params.id;
  logger.feature('episodes.questions', '진입', { episodeId });
  const r = await pool.query(
    `SELECT id, scene_index, narrative, choices, explanation FROM questions
     WHERE episode_id = $1 ORDER BY scene_index`,
    [episodeId],
  );
  if (r.rowCount === 0) {
    res.status(404).json({ ok: false, error: { code: 'E-SRV-GLIST-1001', message: '데이터를 불러오지 못했습니다.' } });
    return;
  }
  logger.feature('episodes.questions', '완료', { count: r.rowCount });
  res.json({
    ok: true,
    data: { episode_id: Number(episodeId), questions: r.rows.map((q: any) => ({ ...q, id: Number(q.id) })) },
  });
});

// GET /episodes/quick — 퀵플레이 1문제 (개인화: 오답 유형 우선, 2회+ 정답 유형 제외 — DESIGN 2.4)
gameRouter.get('/episodes/quick', authMiddleware, async (req, res) => {
  const { userId } = req as AuthedRequest;
  logger.feature('episodes.quick', '진입', { userId });
  // 1) 자주 틀리는 rule_key Top3 (DESIGN 2.4-1,2)
  const wrong = await pool.query(
    `SELECT rule_key FROM wrong_embeddings
     WHERE user_id = $1 ORDER BY wrong_count DESC, last_wrong_at DESC LIMIT 3`,
    [userId],
  );
  const wrongKeys = wrong.rows.map((r: any) => r.rule_key);
  // 2) 2회 이상 정답인 rule_key 제외 (DESIGN 2.4-3)
  let excluded: string[] = [];
  if (wrongKeys.length > 0) {
    const ok = await pool.query(
      `SELECT q.rule_key, COUNT(*) FILTER (WHERE a.is_correct)::int AS correct_count
       FROM questions q JOIN answers a ON a.question_id = q.id
       WHERE a.user_id = $1 AND q.rule_key = ANY($2)
       GROUP BY q.rule_key HAVING COUNT(*) FILTER (WHERE a.is_correct) >= 2`,
      [userId, wrongKeys],
    );
    excluded = ok.rows.map((r: any) => r.rule_key);
  }
  const targets = wrongKeys.filter((k: string) => !excluded.includes(k));

  let q: any;
  if (targets.length > 0) {
    const r = await pool.query(
      `SELECT q.id, q.scene_index, q.narrative, q.choices, q.explanation, q.rule_key, e.title AS episode_title
       FROM questions q JOIN episodes e ON e.id = q.episode_id
       WHERE q.rule_key = ANY($1)
       ORDER BY random() LIMIT 1`,
      [targets],
    );
    if (r.rowCount! > 0) {
      q = r.rows[0];
      logger.feature('episodes.quick', '개인화 매칭', { rule_key: q.rule_key, targets });
    }
  }
  if (!q) {
    const r = await pool.query(
      `SELECT q.id, q.scene_index, q.narrative, q.choices, q.explanation, q.rule_key, e.title AS episode_title
       FROM questions q JOIN episodes e ON e.id = q.episode_id
       ORDER BY random() LIMIT 1`,
    );
    q = r.rows[0];
    logger.feature('episodes.quick', '랜덤 폴백');
  }
  if (!q) {
    res.status(404).json({ ok: false, error: { code: 'E-SRV-GEN-1001', message: '문제를 만들지 못했습니다. 잠시 후 다시 시도해 주세요.' } });
    return;
  }
  logger.feature('episodes.quick', '완료', { questionId: q.id, rule_key: q.rule_key });
  res.json({ ok: true, data: { ...q, id: Number(q.id) } });
});

// POST /answers — 답안 제출 + 채점 + EXP/스트릭/오답 기록
gameRouter.post('/answers', authMiddleware, async (req, res) => {
  const { userId } = req as AuthedRequest;
  const questionId: unknown = req.body?.question_id;
  const selected: unknown = req.body?.selected;
  const combo: unknown = req.body?.combo;

  if (!Number.isInteger(questionId) || typeof selected !== 'string' || !Number.isInteger(combo)) {
    res.status(400).json({ ok: false, error: { code: 'E-SRV-VALID-1001', message: '입력값을 확인해 주세요.' } });
    return;
  }

  logger.feature('answers.submit', '진입', { userId, questionId, combo });

  const q = await pool.query(
    `SELECT q.id, q.episode_id, q.rule_key, q.explanation, q.choices
     FROM questions q WHERE q.id = $1`,
    [questionId],
  );
  if (q.rowCount === 0) {
    res.status(404).json({ ok: false, error: { code: 'E-SRV-GLIST-1001', message: '데이터를 불러오지 못했습니다.' } });
    return;
  }
  const question = q.rows[0];
  const choices: { text: string; isCorrect: boolean }[] = question.choices;
  const choice = choices.find((c) => c.text === selected);
  const isCorrect = choice?.isCorrect === true;

  await pool.query(
    `INSERT INTO answers (user_id, question_id, is_correct, selected) VALUES ($1, $2, $3, $4)`,
    [userId, questionId, isCorrect, selected],
  );

  let expGained = 0;
  let newStreak = 0;

  if (isCorrect) {
    expGained = 10 + Math.min((Number(combo) - 1) * 2, 10);
    const today = new Date().toISOString().slice(0, 10);
    const u = await pool.query(
      `UPDATE users
       SET exp = exp + $1,
           streak_days = CASE
             WHEN last_played = CURRENT_DATE THEN streak_days
             WHEN last_played = CURRENT_DATE - 1 THEN streak_days + 1
             ELSE 1 END,
           last_played = CURRENT_DATE,
           league = $2
       WHERE id = $3 RETURNING exp, streak_days, league`,
      [expGained, leagueOf(0), userId],
    );
    const fresh = await pool.query(`SELECT exp FROM users WHERE id = $1`, [userId]);
    const exp = fresh.rows[0].exp;
    await pool.query(`UPDATE users SET league = $1 WHERE id = $2`, [leagueOf(exp), userId]);
    newStreak = u.rows[0].streak_days;

    // 주간 랭킹 집계
    await pool.query(
      `INSERT INTO weekly_rankings (week_key, user_id, score)
       VALUES ($1, $2, $3)
       ON CONFLICT (week_key, user_id) DO UPDATE SET score = weekly_rankings.score + $3`,
      [WEEK_KEY(), userId, expGained],
    );
  } else {
    // 오답 기억 (임베딩 저장 — 실패해도 채점에는 영향 없음)
    await recordWrongRule(userId, question.rule_key).catch(() => undefined);
  }

  logger.feature('answers.submit', '완료', { isCorrect, expGained, streak: newStreak });
  res.json({
    ok: true,
    data: {
      correct: isCorrect,
      correct_index: choices.findIndex((c) => c.isCorrect),
      explanation: question.explanation,
      exp_gained: expGained,
      streak_days: newStreak,
    },
  });
});

// GET /users/me/stats — 통계 (총 정답/오답, 오답 규칙 Top5)
gameRouter.get('/users/me/stats', authMiddleware, async (req, res) => {
  const { userId } = req as AuthedRequest;
  logger.feature('users.stats', '진입', { userId });
  const totals = await pool.query(
    `SELECT COUNT(*) FILTER (WHERE is_correct)::int AS correct,
            COUNT(*) FILTER (WHERE NOT is_correct)::int AS wrong
     FROM answers WHERE user_id = $1`,
    [userId],
  );
  const wrongTop = await pool.query(
    `SELECT w.rule_key, w.wrong_count
     FROM wrong_embeddings w WHERE w.user_id = $1
     ORDER BY w.wrong_count DESC LIMIT 5`,
    [userId],
  );
  logger.feature('users.stats', '완료');
  res.json({ ok: true, data: { ...totals.rows[0], wrong_top: wrongTop.rows } });
});

// GET /rankings/weekly — 주간 랭킹 (Top 50 + 내 순위)
gameRouter.get('/rankings/weekly', authMiddleware, async (req, res) => {
  const { userId } = req as AuthedRequest;
  logger.feature('rankings.weekly', '진입');
  const weekKey = WEEK_KEY();
  const top = await pool.query(
    `SELECT u.id, u.nickname, u.league, r.score
     FROM weekly_rankings r JOIN users u ON u.id = r.user_id
     WHERE r.week_key = $1 ORDER BY r.score DESC LIMIT 50`,
    [weekKey],
  );
  const myRank = await pool.query(
    `SELECT rank FROM (
       SELECT user_id, RANK() OVER (ORDER BY score DESC) AS rank
       FROM weekly_rankings WHERE week_key = $1
     ) t WHERE user_id = $2`,
    [weekKey, userId],
  );
  logger.feature('rankings.weekly', '완료', { topCount: top.rowCount });
  res.json({
    ok: true,
    data: {
      week_key: weekKey,
      my_rank: myRank.rows[0]?.rank != null ? Number(myRank.rows[0].rank) : null,
      rankings: top.rows.map((r: any) => ({ ...r, score: Number(r.score) })),
    },
  });
});