import { Router } from 'express';
import { pool } from '../db.js';
import { authMiddleware, refreshToken, signToken } from '../auth.js';
import { logger } from '../logger.js';
import type { AuthedRequest } from '../auth.js';

export const usersRouter = Router();

// 아바타 URL (DiceBear — seed = user_id)
function avatarUrl(userId: string): string {
  return `https://api.dicebear.com/9.x/lorelei/svg?seed=${userId}`;
}

// POST /auth/anon — 익명 UUID 발급 + JWT
usersRouter.post('/auth/anon', async (_req, res) => {
  logger.feature('auth.anon', '진입');
  const r = await pool.query(
    `INSERT INTO users (nickname) VALUES ('글마을 주민') RETURNING id, nickname`,
  );
  const user = r.rows[0];
  logger.feature('auth.anon', '완료', { userId: user.id });
  res.json({
    ok: true,
    data: {
      token: signToken(user.id),
      refresh_token: refreshToken(user.id),
      user: { id: user.id, nickname: user.nickname, avatar_url: avatarUrl(user.id) },
    },
  });
});

// GET /users/me — 프로필
usersRouter.get('/users/me', authMiddleware, async (req, res) => {
  const { userId } = req as AuthedRequest;
  logger.feature('users.me', '진입', { userId });
  const r = await pool.query(
    `SELECT id, nickname, exp, streak_days, last_played, league, created_at FROM users WHERE id = $1`,
    [userId],
  );
  if (r.rowCount === 0) {
    res.status(404).json({ ok: false, error: { code: 'E-SRV-AUTH-1001', message: '로그인 정보를 확인할 수 없습니다. 다시 시작해 주세요.' } });
    return;
  }
  const u = r.rows[0];
  logger.feature('users.me', '완료');
  res.json({
    ok: true,
    data: { ...u, avatar_url: avatarUrl(u.id), level: Math.floor(Math.sqrt(u.exp / 10)) + 1 },
  });
});

// PATCH /users/me — 닉네임 변경
usersRouter.patch('/users/me', authMiddleware, async (req, res) => {
  const { userId } = req as AuthedRequest;
  const nickname: unknown = req.body?.nickname;
  if (typeof nickname !== 'string' || nickname.trim().length === 0 || nickname.length > 20) {
    res.status(400).json({ ok: false, error: { code: 'E-SRV-VALID-1001', message: '닉네임은 1~20자로 입력해 주세요.' } });
    return;
  }
  logger.feature('users.me.patch', '진입', { nickname });
  const r = await pool.query(`UPDATE users SET nickname = $1 WHERE id = $2 RETURNING id, nickname`, [
    nickname.trim(),
    userId,
  ]);
  if (r.rowCount === 0) {
    res.status(404).json({ ok: false, error: { code: 'E-SRV-AUTH-1001', message: '로그인 정보를 확인할 수 없습니다. 다시 시작해 주세요.' } });
    return;
  }
  logger.feature('users.me.patch', '완료');
  res.json({ ok: true, data: r.rows[0] });
});