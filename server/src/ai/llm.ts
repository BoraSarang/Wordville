// LLM 폴백 체인 (v0.4: Gemini 3.1-lite 1순위 → Zen 무료 → OpenRouter :free)
// 1) gemini:gemini-3.1-flash-lite (1순위 — 사용자 키, 무료 티어)
// 2) zen:deepseek-v4-flash-free   (무료, 빠름)
// 3) zen:mimo-v2.5-free           (무료 대체)
// 4) openrouter:gpt-oss-20b:free  (최종 폴백 — 무료)
import { chatCompletion as geminiChat } from './gemini.js';
import { chatCompletion as zenChat } from './zen.js';
import { chatCompletionFree as openrouterFree } from './openrouter.js';
import { logger } from '../logger.js';
import type { ChatMessage, ChatOptions } from './zen.js';

interface ChainStep {
  name: string;
  call: (m: ChatMessage[], o: ChatOptions) => Promise<string>;
  model: string;
}

const CHAIN: ChainStep[] = [
  { name: 'gemini:gemini-3.1-flash-lite', call: geminiChat, model: 'gemini-3.1-flash-lite' },
  { name: 'zen:deepseek-v4-flash-free', call: zenChat, model: 'deepseek-v4-flash-free' },
  { name: 'zen:mimo-v2.5-free', call: zenChat, model: 'mimo-v2.5-free' },
  { name: 'openrouter:openai/gpt-oss-20b:free', call: openrouterFree, model: 'openai/gpt-oss-20b:free' },
];

export async function chatWithFallback(messages: ChatMessage[], opts: ChatOptions = {}): Promise<string> {
  let lastError: unknown = null;
  for (const step of CHAIN) {
    try {
      return await step.call(messages, { ...opts, model: step.model });
    } catch (err) {
      lastError = err;
      logger.warn('LLM 폴백 전환', {
        step: step.name,
        error: err instanceof Error ? err.message.slice(0, 120) : String(err),
      });
    }
  }
  throw lastError ?? new Error('E-SRV-GEN-1002: 모든 LLM 폴백 실패');
}

export const chainNames = CHAIN.map((s) => s.name);