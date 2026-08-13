// 문제 생성 파이프라인 (T2.1) — 생성 → 심판 루프 (최대 2회 재생성) → DB 저장
// 사용법: npm run generate:questions -- [category] [date]
import { pool } from '../db.js';
import { chatWithFallback } from './llm.js';
import { buildGeneratePrompt, buildJudgePrompt, GENERATE_PROMPT_VERSION, JUDGE_PROMPT_VERSION } from './prompts.js';
import { logger } from '../logger.js';

const CATEGORIES = ['kitchen', 'office', 'trip'];

interface GeneratedQuestion {
  scene_index: number;
  narrative: string;
  choices: { text: string; isCorrect: boolean }[];
  explanation: string;
  rule_key: string;
  difficulty: number;
}

interface GeneratedEpisode {
  category: string;
  title: string;
  scene_order: { scene_index: number; background: string; character: string; emotion: string }[];
  questions: GeneratedQuestion[];
}

interface JudgeResult {
  judge_score: number;
  reasons: string[];
  is_valid: boolean;
}

function validateEpisode(raw: unknown): raw is GeneratedEpisode {
  const ep = raw as GeneratedEpisode;
  if (!ep || typeof ep !== 'object') return false;
  if (typeof ep.title !== 'string' || ep.title.length < 4 || ep.title.length > 30) return false;
  if (!Array.isArray(ep.questions) || ep.questions.length !== 5) return false;
  if (!Array.isArray(ep.scene_order) || ep.scene_order.length !== 5) return false;
  const ruleKeys = new Set<string>();
  for (const q of ep.questions) {
    if (typeof q.narrative !== 'string' || q.narrative.length < 20) return false;
    if (!Array.isArray(q.choices) || q.choices.length < 2 || q.choices.length > 5) return false;
    const correctCount = q.choices.filter((c) => c.isCorrect === true).length;
    if (correctCount !== 1) return false;
    if (typeof q.explanation !== 'string' || q.explanation.length < 10) return false;
    if (typeof q.rule_key !== 'string' || q.rule_key.length < 2) return false;
    if (ruleKeys.has(q.rule_key)) return false;
    ruleKeys.add(q.rule_key);
  }
  return true;
}

async function parseJson<T>(raw: string): Promise<T | null> {
  try {
    return JSON.parse(raw) as T;
  } catch {
    const match = raw.match(/\{[\s\S]*\}/);
    if (!match) return null;
    try {
      return JSON.parse(match[0]) as T;
    } catch {
      return null;
    }
  }
}

async function judge(category: string, episode: GeneratedEpisode): Promise<JudgeResult> {
  const { system, user } = buildJudgePrompt(category, JSON.stringify(episode));
  const raw = await chatWithFallback(
    [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
    { temperature: 0.0, maxTokens: 1024, promptVersion: JUDGE_PROMPT_VERSION },
  );
  const result = await parseJson<JudgeResult>(raw);
  if (!result || typeof result.judge_score !== 'number') {
    return { judge_score: 0, reasons: ['심판 응답 파싱 실패'], is_valid: false };
  }
  return result;
}

async function generateOnce(category: string, date: string): Promise<GeneratedEpisode | null> {
  const { system, user } = buildGeneratePrompt(category, date);
  const raw = await chatWithFallback(
    [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
    { temperature: 0.6, maxTokens: 2048, promptVersion: GENERATE_PROMPT_VERSION },
  );
  const ep = await parseJson<GeneratedEpisode>(raw);
  if (!validateEpisode(ep)) {
    logger.warn('생성 결과 스키마 검증 실패');
    return null;
  }
  return ep;
}

export async function generateDailyEpisode(category: string, date: string): Promise<GeneratedEpisode | null> {
  logger.feature('generate.questions', '진입', { category, date });
  let best: GeneratedEpisode | null = null;
  let bestScore = 0;

  for (let attempt = 0; attempt < 3; attempt++) {
    const ep = await generateOnce(category, date);
    if (!ep) continue;
    const verdict = await judge(category, ep);
    logger.feature('generate.judge', '완료', { attempt, score: verdict.judge_score, valid: verdict.is_valid });
    if (verdict.is_valid && verdict.judge_score >= 7) {
      logger.feature('generate.questions', '완료', { attempt, score: verdict.judge_score, regenerations: attempt });
      return ep;
    }
    if (verdict.judge_score > bestScore) {
      best = ep;
      bestScore = verdict.judge_score;
    }
  }
  logger.warn('심판 통과 실패 — 최고 점수 문제로 폴백', { bestScore });
  return best;
}

export async function saveEpisode(ep: GeneratedEpisode, date: string, judgeScore: number): Promise<number | null> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const exists = await client.query('SELECT id FROM episodes WHERE episode_date = $1', [date]);
    if (exists.rowCount && exists.rowCount > 0) {
      logger.warn('해당 날짜 에피소드 이미 존재, 스킵', { date });
      await client.query('ROLLBACK');
      return null;
    }
    const ins = await client.query(
      `INSERT INTO episodes (episode_date, category, title, scene_order, created_by)
       VALUES ($1, $2, $3, $4, 'ai') RETURNING id`,
      [date, ep.category, ep.title, JSON.stringify(ep.scene_order)],
    );
    const episodeId = ins.rows[0].id;
    for (const q of ep.questions) {
      await client.query(
        `INSERT INTO questions (episode_id, scene_index, narrative, choices, explanation, rule_key, difficulty, judge_score)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [episodeId, q.scene_index, q.narrative, JSON.stringify(q.choices), q.explanation, q.rule_key, q.difficulty, judgeScore],
      );
    }
    await client.query('COMMIT');
    logger.feature('generate.save', '완료', { episodeId, questions: ep.questions.length });
    return episodeId;
  } catch (err) {
    await client.query('ROLLBACK');
    logger.error('에피소드 저장 실패', { error: err instanceof Error ? err.message : String(err) });
    return null;
  } finally {
    client.release();
  }
}

async function main() {
  const argCategory = process.argv[2];
  const argDate = process.argv[3] ?? new Date().toISOString().slice(0, 10);
  const category = argCategory && CATEGORIES.includes(argCategory) ? argCategory : CATEGORIES[0];
  const ep = await generateDailyEpisode(category, argDate);
  if (!ep) {
    logger.error('문제 생성 실패 — 폴백(시드 문제) 사용 필요');
    process.exit(1);
  }
  const id = await saveEpisode(ep, argDate, 10);
  logger.feature('generate.main', '완료', { episodeId: id, title: ep.title });
  await pool.end();
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((err) => {
    logger.error('생성 파이프라인 실패', { error: err instanceof Error ? err.message : String(err) });
    process.exit(1);
  });
}

export { main as runGenerateMain };