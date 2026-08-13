import 'dotenv/config';

export type DeployTarget = 'local' | 'render';

export const config = {
  // 배포 대상 선택: DEPLOY_TARGET=local|render (기본: NODE_ENV가 production이면 render, 아니면 local)
  deployTarget: (process.env.DEPLOY_TARGET ?? (process.env.NODE_ENV === 'production' ? 'render' : 'local')) as DeployTarget,
  port: Number(process.env.PORT ?? 3000),
  nodeEnv: process.env.NODE_ENV ?? 'development',
  databaseUrl: process.env.DATABASE_URL ?? '',
  zenApiKey: process.env.ZEN_API_KEY ?? '',
  geminiApiKey: process.env.GEMINI_API_KEY ?? '',
  openRouterApiKey: process.env.OPENROUTER_API_KEY ?? '',
  debugLogs: process.env.DEBUG_LOGS === 'true',
  corsOrigins: (process.env.CORS_ORIGINS ?? '*').split(','),
  jwtSecret: process.env.JWT_SECRET ?? 'dev-secret-change-me',
};

// 디버그 모드: 로컬에서만 활성 (render 배포 시 무조건 비활성)
export const isDebug = config.deployTarget === 'local' && config.debugLogs;