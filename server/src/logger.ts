// 구조화 JSON 로거 (AGENTS.md 19장 — Server는 구조화 JSON 로거 사용)
// 형식: {"ts":"2026-08-13T..","level":"INFO","feature":"...","message":"..."}

type Level = 'INFO' | 'WARN' | 'ERROR';

interface LogEntry {
  ts: string;
  level: Level;
  feature?: string;
  message: string;
  meta?: Record<string, unknown>;
}

// 최근 500줄 인메모리 링버퍼 (GET /debug/logs용)
class LogBuffer {
  private buf: string[] = [];
  private max: number;

  constructor(max = 500) {
    this.max = max;
  }

  push(line: string) {
    this.buf.push(line);
    if (this.buf.length > this.max) this.buf.shift();
  }

  list(): string[] {
    return [...this.buf];
  }
}

export const logBuffer = new LogBuffer();

function write(level: Level, feature: string | undefined, message: string, meta?: Record<string, unknown>) {
  const entry: LogEntry = {
    ts: new Date().toISOString(),
    level,
    ...(feature ? { feature } : {}),
    message,
    ...(meta ? { meta } : {}),
  };
  const line = JSON.stringify(entry);
  logBuffer.push(line);
  if (level === 'ERROR') {
    console.error(line);
  } else {
    console.log(line);
  }
}

// 신규 기능 로그 의무화 (AGENTS.md 19.1): [INFO] [FEATURE] <기능명> 진입/완료
export const logger = {
  info: (message: string, meta?: Record<string, unknown>) => write('INFO', undefined, message, meta),
  warn: (message: string, meta?: Record<string, unknown>) => write('WARN', undefined, message, meta),
  error: (message: string, meta?: Record<string, unknown>) => write('ERROR', undefined, message, meta),
  feature: (feature: string, message: string, meta?: Record<string, unknown>) => write('INFO', feature, message, meta),
};