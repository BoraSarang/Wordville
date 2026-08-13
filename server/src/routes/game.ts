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
      my_rank: myRank.rows[0]?.rank ?? null,
      rankings: top.rows,
    },
  });
});