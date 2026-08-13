// 문제 생성 스케줄러 (T2.2) — 매일 00:00 KST + 시작 시 오늘 미생성분 보정
import cron from 'node-cron';
import { pool } from '../db.js';
import { logger } from '../logger.js';
import { generateDailyEpisode, saveEpisode } from '../ai/generateQuestions.js';

const CATEGORY_ROTATION = ['kitchen', 'office', 'trip'];
const TIMEZONE = 'Asia/Seoul';

function kstToday(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: TIMEZONE, year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());
}

export async function ensureTodayEpisode(): Promise<boolean> {
  const today = kstToday();
  logger.feature('scheduler', '진입', { date: today });
  const exists = await pool.query('SELECT id FROM episodes WHERE episode_date = $1', [today]);
  if (exists.rowCount && exists.rowCount > 0) {
    logger.feature('scheduler', '완료 — 이미 존재', { episodeId: exists.rows[0].id });
    return true;
  }
  const dayOfWeek = new Date().getDay();
  const category = CATEGORY_ROTATION[dayOfWeek % CATEGORY_ROTATION.length];
  const ep = await generateDailyEpisode(category, today);
  if (!ep) {
    logger.error('오늘 문제 생성 실패 — 폴백(시드) 필요');
    return false;
  }
  const id = await saveEpisode(ep, today, 10);
  logger.feature('scheduler', '완료', { episodeId: id, category });
  return id !== null;
}

let running = false;

export function startScheduler() {
  // 매일 00:00 KST
  cron.schedule(
    '0 0 * * *',
    async () => {
      if (running) return;
      running = true;
      try {
        await ensureTodayEpisode();
      } finally {
        running = false;
      }
    },
    { timezone: TIMEZONE },
  );
  logger.feature('scheduler', '크론 등록 — 매일 00:00 KST');
}

// 서버 시작 시 당일 에피소드 보정 (비동기, 블로킹 없음)
export function startCatchUp() {
  setTimeout(async () => {
    try {
      await ensureTodayEpisode();
    } catch (err) {
      logger.error('시작 시 보정 실패', { error: err instanceof Error ? err.message : String(err) });
    }
  }, 2000);
}