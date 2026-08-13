// 오답 규칙 임베딩 (T2.4) — rule_key를 벡터화해 pgvector에 저장
// 사용처: 답안 제출 시 오답 규칙 → 임베딩 생성 → wrong_embeddings upsert
// T2.5+: 사용자 오답 규칙과 유사한 문제를 스케줄러가 우선 출제
import { config } from '../config.js';
import { logger } from '../logger.js';

export async function embedRuleKey(ruleKey: string): Promise<number[] | null> {
  logger.feature('embed.rule', '진입', { rule_key: ruleKey });
  const res = await fetch('https://openrouter.ai/api/v1/embeddings', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${config.openRouterApiKey}`,
    },
    body: JSON.stringify({
      model: 'openai/text-embedding-3-small',
      input: `한국어 맞춤법 규칙: ${ruleKey}`,
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    logger.warn('임베딩 호출 실패', { status: res.status, body: text.slice(0, 150) });
    return null;
  }
  const data = (await res.json()) as { data?: { embedding: number[] }[] };
  const emb = data.data?.[0]?.embedding;
  if (!emb) {
    logger.warn('임베딩 빈 응답');
    return null;
  }
  logger.feature('embed.rule', '완료', { dims: emb.length });
  return emb;
}

export function toVectorLiteral(emb: number[]): string {
  return '[' + emb.map((n) => n.toPrecision(6)).join(',') + ']';
}

// 제출 시 오답 규칙 임베딩 저장 (game.ts POST /answers에서 호출)
export async function recordWrongRule(userId: string, ruleKey: string): Promise<boolean> {
  const emb = await embedRuleKey(ruleKey);
  if (!emb) return false;
  const { pool } = await import('../db.js');
  await pool.query(
    `INSERT INTO wrong_embeddings (user_id, rule_key, embedding)
     VALUES ($1, $2, $3::vector)
     ON CONFLICT (user_id, rule_key)
     DO UPDATE SET wrong_count = wrong_embeddings.wrong_count + 1,
                   embedding = $3::vector,
                   last_wrong_at = now()`,
    [userId, ruleKey, toVectorLiteral(emb)],
  );
  return true;
}