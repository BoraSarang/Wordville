// 익명 인증 미들웨어 — JWT(Bearer) 검증 (AGENTS.md 8.12: JWT 만료 30일, /auth/refresh)
import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { config } from './config.js';
import { logger } from './logger.js';

export interface AuthedRequest extends Request {
  userId: string;
}

export function signToken(userId: string): string {
  return jwt.sign({ sub: userId }, config.jwtSecret, { expiresIn: '30d' });
}

export function refreshToken(userId: string): string {
  return jwt.sign({ sub: userId }, config.jwtSecret, { expiresIn: '30d' });
}

export function authMiddleware(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    res.status(401).json({ ok: false, error: { code: 'E-SRV-AUTH-1001', message: '로그인 정보를 확인할 수 없습니다. 다시 시작해 주세요.' } });
    return;
  }
  try {
    const payload = jwt.verify(header.slice(7), config.jwtSecret) as { sub: string };
    (req as AuthedRequest).userId = payload.sub;
    next();
  } catch {
    logger.warn('JWT 검증 실패');
    res.status(401).json({ ok: false, error: { code: 'E-SRV-AUTH-1001', message: '로그인 정보를 확인할 수 없습니다. 다시 시작해 주세요.' } });
  }
}