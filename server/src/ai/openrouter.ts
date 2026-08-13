// OpenRouter API 래퍼 — :free 무료 모델 전용 (최종 폴백)
// 엔드포인트: https://openrouter.ai/api/v1/chat/completions
import { config } from '../config.js';
import { logger } from '../logger.js';
import type { ChatMessage, ChatOptions } from './zen.js';

interface CacheEntry {
  value: string;
  expiresAt: number;
}

const cache = new Map<string, CacheEntry>();
export const FREE_FALLBACK_MODEL = 'openai/gpt-oss-20b:free';

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
  if (cache.size >= 100) {
    const oldest = cache.keys().next().value;
    if (oldest) cache.delete(oldest);
  }
  cache.set(key, { value, expiresAt: Date.now() + 7 * 24 * 3600 * 1000 });
}

export async function chatCompletionFree(
  messages: ChatMessage[],
  opts: ChatOptions = {},
): Promise<string> {
  const model = opts.model ?? FREE_FALLBACK_MODEL;
  const promptVersion = opts.promptVersion ?? 'chat_v0.1';
  const key = cacheKey(model, promptVersion, messages);

  const cached = getCached(key);
  if (cached !== null) {
    logger.info('[CACHE] hit=true (openrouter-free)', { model, prompt_version: promptVersion });
    return cached;
  }

  logger.feature('openrouter.free', '진입', { model, prompt_version: promptVersion });

  const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${config.openRouterApiKey}`,
      'HTTP-Referer': 'https://github.com/BoraSarang/Wordville',
      'X-Title': 'Wordville',
    },
    body: JSON.stringify({
      model,
      messages,
      temperature: opts.temperature ?? 0.2,
      max_tokens: opts.maxTokens ?? 8192,
      response_format: { type: 'json_object' },
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    logger.error('OpenRouter(:free) 호출 실패', { status: res.status, body: text.slice(0, 200) });
    throw new Error(`E-SRV-GEN-1002: LLM 호출 실패 (${res.status})`);
  }

  const data = (await res.json()) as {
    choices?: { message?: { content?: string } }[];
    usage?: { prompt_tokens?: number; completion_tokens?: number };
  };
  const content = data.choices?.[0]?.message?.content ?? '';
  if (!content) {
    logger.error('OpenRouter(:free) 빈 응답', { usage: data.usage });
    throw new Error('E-SRV-GEN-1002: LLM 응답이 비어 있습니다.');
  }

  setCached(key, content);
  logger.feature('openrouter.free', '완료', {
    model,
    prompt_version: promptVersion,
    tokens: `${data.usage?.prompt_tokens ?? 0}/${data.usage?.completion_tokens ?? 0}`,
  });
  return content;
}