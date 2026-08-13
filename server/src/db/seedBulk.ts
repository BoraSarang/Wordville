// 시드 문제 벌크 생성 (T2.3) — 과거 날짜로 100문항 확보 (에피소드 20개 x 5문항)
// 이미 존재하는 날짜는 자동 스킵. 폴백용 시드 풀 구성.
// usage: npm run seed:bulk
import { pool } from '../db.js';
import { logger } from '../logger.js';
import { generateDailyEpisode, saveEpisode } from '../ai/generateQuestions.js';

const CATEGORY_ROTATION = ['kitchen', 'office', 'trip'];
const START_DAY = 1; // 2026-08-01
const DAYS = 22; // 8/1 ~ 8/22

async function main() {
  let created = 0;
  let skipped = 0;
  let failed = 0;
  for (let i = 0; i < DAYS; i++) {
    const d = new Date(2026, 7, START_DAY + i);
    const date = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    const category = CATEGORY_ROTATION[i % CATEGORY_ROTATION.length];
    try {
      const ep = await generateDailyEpisode(category, date);
      if (!ep) {
        failed++;
        continue;
      }
      const id = await saveEpisode(ep, date, 10);
      if (id === null) skipped++;
      else created++;
      logger.feature('seed.bulk', '에피소드 1개 완료', { date, title: ep.title, id });
    } catch (err) {
      failed++;
      logger.error('벌크 생성 실패', { date, error: err instanceof Error ? err.message : String(err) });
    }
  }
  const total = await pool.query('SELECT COUNT(*)::int AS c FROM questions');
  logger.feature('seed.bulk', '완료', { created, skipped, failed, total_questions: total.rows[0].c });
  await pool.end();
}

main().catch((err) => {
  logger.error('seed.bulk 실패', { error: err instanceof Error ? err.message : String(err) });
  process.exit(1);
});