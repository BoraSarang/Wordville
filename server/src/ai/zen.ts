// OpenCode Zen API 래퍼 — deepseek-v4-flash-free / mimo-v2.5-free (완전 무료)
// 엔드포인트: https://opencode.ai/zen/v1/chat/completions (OpenAI 호환)
// 응답 캐시: 인메모리 LRU (AGENTS.md 8.13 — prompt_version별, TTL 7일)
import { config } from '../config.js';
import { logger } from '../logger.js';

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface ChatOptions {
  model?: string;
  temperature?: number;
  maxTokens?: number;
  promptVersion?: string;
}

interface CacheEntry {
  value: string;
  expiresAt: number;
}

const cache = new Map<string, CacheEntry>();
const ZEN_ENDPOINT = 'https://opencode.ai/zen/v1/chat/completions';
export const DEFAULT_MODEL = 'deepseek-v4-flash-free';

function cacheKey(model: string, promptVersion: string, messages: ChatMessage[]): string {
  return `${model}|${promptVersion}|${messages.map((m) => m.content).join('||')}`;
}

export function cacheStats() {
  return { entries: cache.size, hitRate: 0 };
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
  const model = opts.model ?? DEFAULT_MODEL;
  const promptVersion = opts.promptVersion ?? 'chat_v0.1';
  const key = cacheKey(model, promptVersion, messages);

  const cached = getCached(key);
  if (cached !== null) {
    logger.info('[CACHE] hit=true cost_saved=0.0', { model, prompt_version: promptVersion, cache_key: key.slice(0, 32) });
    return cached;
  }

  logger.feature('zen', '진입', { model, prompt_version: promptVersion, messages: messages.length });

  const MAX_RETRIES = 3;
  const RETRY_DELAYS = [10_000, 30_000, 60_000];

  let res: Response | null = null;
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    res = await fetch(ZEN_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${config.zenApiKey}`,
        'HTTP-Referer': 'https://github.com/BoraSarang/Wordville',
        'X-Title': 'Wordville',
      },
      body: JSON.stringify({
        model,
        messages,
        temperature: opts.temperature ?? 0.2,
        max_tokens: opts.maxTokens ?? 4096,
        response_format: { type: 'json_object' },
      }),
    });

    if (res.status !== 429 || attempt === MAX_RETRIES) break;
    logger.warn('Zen 429 (FreeUsageLimitError) — 재시도 대기', { attempt: attempt + 1, delay_ms: RETRY_DELAYS[attempt] });
    await new Promise((r) => setTimeout(r, RETRY_DELAYS[attempt]));
  }

  if (!res || !res.ok) {
    const text = res ? await res.text() : 'no response';
    logger.error('Zen 호출 실패', { status: res?.status ?? 0, body: text.slice(0, 300) });
    throw new Error(`E-SRV-GEN-1002: LLM 호출 실패 (${res?.status ?? 0})`);
  }

  const data = (await res.json()) as {
    choices?: { message?: { content?: string } }[];
    usage?: { prompt_tokens?: number; completion_tokens?: number };
  };
  const content = data.choices?.[0]?.message?.content ?? '';
  if (!content) {
    logger.error('Zen 빈 응답', { usage: data.usage });
    throw new Error('E-SRV-GEN-1002: LLM 응답이 비어 있습니다.');
  }

  setCached(key, content);
  logger.feature('zen', '완료', {
    model,
    prompt_version: promptVersion,
    tokens: `${data.usage?.prompt_tokens ?? 0}/${data.usage?.completion_tokens ?? 0}`,
  });
  return content;
}