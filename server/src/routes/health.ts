import { Router } from 'express';
import { checkDb } from '../db.js';
import { logger } from '../logger.js';

export const healthRouter = Router();

healthRouter.get('/health', async (_req, res) => {
  logger.feature('health', '진입');
  const started = Date.now();
  const db = await checkDb();
  const latency = Date.now() - started;

  const body = {
    ok: db.ok,
    service: 'wordville-server',
    version: '0.1.0',
    db: db.ok ? 'up' : `down (${db.error})`,
    latency_ms: latency,
  };
  logger.feature('health', '완료', { ok: db.ok, latency_ms: latency });
  res.status(db.ok ? 200 : 503).json({ ok: db.ok, data: body });
});