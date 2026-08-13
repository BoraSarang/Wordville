import { Router } from 'express';
import { isDebug } from '../config.js';
import { logBuffer, logger } from '../logger.js';
import { cacheStats as geminiCacheStats } from '../ai/gemini.js';
import { cacheStats as zenCacheStats } from '../ai/zen.js';
import { cacheStats as openrouterCacheStats } from '../ai/openrouter.js';
import type { Request, Response, NextFunction } from 'express';

// 디버그 패널 라우트 (DEBUG 모드에서만 활성)
export const debugRouter = Router();

debugRouter.use((req: Request, res: Response, next: NextFunction) => {
  if (!isDebug) {
    res.status(403).json({ ok: false, error: { code: 'E-SRV-PERM-1001', message: '디버그 모드가 아닙니다.' } });
    return;
  }
  next();
});

debugRouter.get('/debug/logs', (_req, res) => {
  logger.feature('debug.logs', '진입/완료');
  res.json({ ok: true, data: { logs: logBuffer.list() } });
});

// LLM 응답 캐시 통계 (gemini + zen + openrouter 통합 — AGENTS 8.13)
debugRouter.get('/debug/cache', (_req, res) => {
  const g = geminiCacheStats();
  const z = zenCacheStats();
  const o = openrouterCacheStats();
  const entries = g.entries + z.entries + o.entries;
  const hits = (g.entries * g.hitRate + z.entries * z.hitRate + o.entries * o.hitRate) / Math.max(entries, 1);
  logger.feature('debug.cache', '진입/완료', { entries, hit_rate: hits });
  res.json({ ok: true, data: { hit_rate: Math.round(hits * 100) / 100, entries, note: 'gemini+zen+openrouter 인메모리 LRU (TTL 7일)' } });
});

// 오프라인 큐 상태 (클라이언트 큐 통계 집계 API — v0.1은 서버 큐 없음)
debugRouter.get('/debug/queue', (_req, res) => {
  logger.feature('debug.queue', '진입/완료');
  res.json({ ok: true, data: { pending: 0, note: '클라이언트 오프라인 큐는 T4.x에서 동기화' } });
});