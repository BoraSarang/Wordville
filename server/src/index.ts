import express from 'express';
import type { NextFunction, Request, Response } from 'express';
import { config, isDebug } from './config.js';
import { logger } from './logger.js';
import { healthRouter } from './routes/health.js';
import { debugRouter } from './routes/debug.js';
import { usersRouter } from './routes/users.js';
import { gameRouter } from './routes/game.js';

const app = express();

app.disable('x-powered-by');
app.use(express.json({ limit: '256kb' }));

// 요청 로깅 (구조화 JSON)
app.use((req: Request, _res: Response, next: NextFunction) => {
  logger.info(`API→ ${req.method} ${req.path}`);
  next();
});

// CORS (개발: 전부 허용, 배포 시 config.corsOrigins 제한)
app.use((req: Request, res: Response, next: NextFunction) => {
  const origin = req.headers.origin;
  const allow = config.corsOrigins.includes('*') ? '*' : config.corsOrigins.join(', ');
  res.setHeader('Access-Control-Allow-Origin', allow === '*' ? '*' : origin ?? '');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') {
    res.sendStatus(204);
    return;
  }
  next();
});

app.use(healthRouter);
app.use(debugRouter);
app.use(usersRouter);
app.use(gameRouter);

app.get('/', (_req, res) => {
  res.json({ ok: true, data: { service: 'wordville-server', docs: '/health' } });
});

// 404
app.use((_req: Request, res: Response) => {
  res.status(404).json({ ok: false, error: { code: 'E-SRV-GLIST-1001', message: '데이터를 불러오지 못했습니다.' } });
});

// 에러 핸들러 (에러코드 래핑 — AGENTS.md 8.5)
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  logger.error('서버 에러', { error: err.message });
  res.status(500).json({ ok: false, error: { code: 'E-SRV-GEN-1001', message: '오늘의 문제를 만들지 못했습니다. 잠시 후 다시 시도해 주세요.' } });
});

app.listen(config.port, () => {
  logger.feature('server', `시작됨 (port ${config.port}, env ${config.nodeEnv}, debug ${isDebug})`);
});