// Google Gemini API 래퍼 — gemini-3.6-flash (1순위 모델)
// 엔드포인트: https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
// 응답 캐시: zen.ts와 동일 패턴 (인메모리 LRU, TTL 7일)
import { config } from '../config.js';
import { logger } from '../logger.js';
import type { ChatMessage, ChatOptions } from './zen.js';

interface CacheEntry {
  value: string;
  expiresAt: number;
}

const cache = new Map<string, CacheEntry>();
let cacheHits = 0;
let cacheMisses = 0;
const GEMINI_ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models';
export const DEFAULT_MODEL = 'gemini-3.1-flash-lite';

export function cacheStats() {
  const total = cacheHits + cacheMisses;
  return { entries: cache.size, hitRate: total > 0 ? cacheHits / total : 0 };
}

function cacheKey(model: string, promptVersion: string, messages: ChatMessage[]): string {
  return `${model}|${promptVersion}|${messages.map((m) => m.content).join('||')}`;
}

function getCached(key: string): string | null {
  const entry = cache.get(key);
  if (!entry) return null;
  if (entry.expiresAt < Date.now()) {
    cache.delete(key);
    return null;
  }
  return entry.value;
}

function setCached(key: string, value: string) {
  if (cache.size >= 200) {
    const oldest = cache.keys().next().value;
    if (oldest) cache.delete(oldest);
  }
  cache.set(key, { value, expiresAt: Date.now() + 7 * 24 * 3600 * 1000 });
}

export async function chatCompletion(
  messages: ChatMessage[],
  opts: ChatOptions = {},
): Promise<string> {
  const apiKey = config.geminiApiKey;
  if (!apiKey) throw new Error('E-SRV-GEN-1003: GEMINI_API_KEY가 설정되지 않았습니다.');

  const model = opts.model ?? DEFAULT_MODEL;
  const promptVersion = opts.promptVersion ?? 'chat_v0.1';
  const key = cacheKey(model, promptVersion, messages);

  const cached = getCached(key);
  if (cached !== null) {
    cacheHits++;
    logger.info('[CACHE] hit=true cost_saved=0.0', { model, prompt_version: promptVersion, cache_key: key.slice(0, 32) });
    return cached;
  }
  cacheMisses++;

  logger.feature('gemini', '진입', { model, prompt_version: promptVersion, messages: messages.length });

  const systemText = messages.filter((m) => m.role === 'system').map((m) => m.content).join('\n');
  const contents = messages
    .filter((m) => m.role !== 'system')
    .map((m) => ({
      role: m.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: m.content }],
    }));

  const body: Record<string, unknown> = {
    contents,
    generationConfig: {
      temperature: opts.temperature ?? 0.2,
      maxOutputTokens: opts.maxTokens ?? 4096,
      responseMimeType: 'application/json',
    },
  };
  if (systemText) {
    body.systemInstruction = { parts: [{ text: systemText }] };
  }

  // 503(고수요)/429(속도제한) 일시 오류는 최대 3회 재시도 (5s → 10s → 15s 백오프)
  const RETRYABLE = new Set([429, 500, 502, 503]);
  let res: Response | undefined;
  let lastText = '';
  for (let attempt = 0; attempt < 3; attempt++) {
    if (attempt > 0) {
      const delay = 5000 * Math.pow(2, attempt - 1);
      logger.info('Gemini 재시도 대기', { attempt, delay_ms: delay });
      await new Promise((r) => setTimeout(r, delay));
    }
    res = await fetch(`${GEMINI_ENDPOINT}/${model}:generateContent?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (res.ok || !RETRYABLE.has(res.status)) break;
    lastText = await res.text();
    logger.warn('Gemini 일시 오류 — 재시도', { attempt: attempt + 1, status: res.status });
  }

  if (!res) throw new Error('E-SRV-GEN-1002: LLM 호출 실패 (fetch 응답 없음)');
  if (!res.ok) {
    const text = lastText || (await res.text());
    logger.error('Gemini 호출 실패', { status: res.status, body: text.slice(0, 300) });
    throw new Error(`E-SRV-GEN-1002: LLM 호출 실패 (${res.status})`);
  }

  const data = (await res.json()) as {
    candidates?: { content?: { parts?: { text?: string }[] } }[];
    usageMetadata?: { promptTokenCount?: number; candidatesTokenCount?: number };
    error?: { message?: string };
  };

  if (data.error) {
    logger.error('Gemini 응답 오류', { message: data.error.message });
    throw new Error(`E-SRV-GEN-1002: ${data.error.message}`);
  }

  const content = data.candidates?.[0]?.content?.parts?.map((p) => p.text ?? '').join('') ?? '';
  if (!content) {
    logger.error('Gemini 빈 응답', { usage: data.usageMetadata });
    throw new Error('E-SRV-GEN-1002: LLM 응답이 비어 있습니다.');
  }

  setCached(key, content);
  logger.feature('gemini', '완료', {
    model,
    prompt_version: promptVersion,
    tokens: `${data.usageMetadata?.promptTokenCount ?? 0}/${data.usageMetadata?.candidatesTokenCount ?? 0}`,
  });
  return content;
}
