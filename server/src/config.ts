import 'dotenv/config';

export const config = {
  port: Number(process.env.PORT ?? 3000),
  nodeEnv: process.env.NODE_ENV ?? 'development',
  databaseUrl: process.env.DATABASE_URL ?? '',
  openRouterApiKey: process.env.OPENROUTER_API_KEY ?? '',
  debugLogs: process.env.DEBUG_LOGS !== 'false',
  corsOrigins: (process.env.CORS_ORIGINS ?? '*').split(','),
  jwtSecret: process.env.JWT_SECRET ?? 'dev-secret-change-me',
};

export const isDebug = config.nodeEnv === 'development' || config.debugLogs;