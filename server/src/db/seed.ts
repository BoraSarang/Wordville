// 시드 데이터 — 스키마 검증용 기본 에피소드 1개 (5문항)
// T2.3에서 AI 생성 문제 + 시드 100개로 확장
// usage: npm run seed
import { pool } from '../db.js';
import { logger } from '../logger.js';

interface SeedQuestion {
  scene_index: number;
  narrative: string;
  choices: { text: string; isCorrect: boolean }[];
  explanation: string;
  rule_key: string;
  difficulty: number;
}

interface SeedEpisode {
  episode_date: string;
  category: string;
  title: string;
  scene_order: { scene_index: number; background: string; character: string; emotion: string }[];
  questions: SeedQuestion[];
}

const EPISODES: SeedEpisode[] = [
  {
    episode_date: '2026-08-13',
    category: 'kitchen',
    title: '부엌의 첫 아침',
    scene_order: [
      { scene_index: 0, background: 'kitchen', character: 'villager', emotion: 'idle' },
      { scene_index: 1, background: 'kitchen', character: 'villager', emotion: 'happy' },
      { scene_index: 2, background: 'kitchen', character: 'villager', emotion: 'idle' },
      { scene_index: 3, background: 'kitchen', character: 'villager', emotion: 'surprised' },
      { scene_index: 4, background: 'kitchen', character: 'villager', emotion: 'happy' },
    ],
    questions: [
      {
        scene_index: 0,
        narrative: '아침에 눈을 뜬 주인공. 오늘은 무엇을 해야 할지 생각한다. "오늘이며칠일까?" 방금 한 생각을 올바르게 적은 문장은?',
        choices: [
          { text: '오늘이며칠일까?', isCorrect: false },
          { text: '오늘이 며칠일까?', isCorrect: true },
          { text: '오늘이 몇일일까?', isCorrect: false },
          { text: '오늘이 머칠일까?', isCorrect: false },
        ],
        explanation: '며칠만 올바른 표기입니다. "몇 일"이나 "머칠"은 틀린 표기예요.',
        rule_key: '며칠_몇일',
        difficulty: 1,
      },
      {
        scene_index: 1,
        narrative: '부엌에서 냉장고를 열어보니 우유가 다 떨어져 있었다. "우유를 사러 가야겠다." 그런데 잠깐, 다 먹은 우유는 어디에 버려야 할까? 올바른 문장을 고르세요.',
        choices: [
          { text: '우유팩은 분리수거함에 버려야 돼요.', isCorrect: true },
          { text: '우유팩은 분리수거함에 버려야 되요.', isCorrect: false },
          { text: '우유팩은 분리수거함에 버려야 되여.', isCorrect: false },
          { text: '우유팩은 분리수거함에 버려야 돼여.', isCorrect: false },
        ],
        explanation: '"돼"는 "되어"의 준말로 "버려야 돼요"가 올바른 표기입니다.',
        rule_key: '되_돼',
        difficulty: 1,
      },
      {
        scene_index: 2,
        narrative: '주인공이 시장에 가려고 한다. 지갑을 챙겼는지 확인하며 중얼거린다. 올바른 문장은?',
        choices: [
          { text: '지갑을 안 챙겼네?', isCorrect: true },
          { text: '지갑을 않 챙겼네?', isCorrect: false },
          { text: '지갑을 안챙겼네?', isCorrect: false },
          { text: '지갑을 않챙겼네?', isCorrect: false },
        ],
        explanation: '"안"은 부정 부사로 "안 챙겼네"처럼 띄어 쓰는 것이 맞습니다.',
        rule_key: '안_않',
        difficulty: 2,
      },
      {
        scene_index: 3,
        narrative: '시장에서 포도를 샀다. 계산대에서 가격을 보고 놀랐다. 올바른 문장을 고르세요.',
        choices: [
          { text: '와, 포도가 이렇게 비싸네요!', isCorrect: true },
          { text: '와, 포도가 이렇게 비싸내요!', isCorrect: false },
          { text: '와, 포도가 이렇게 비싸네여!', isCorrect: false },
          { text: '와, 포도가 이렇게 비싸내여!', isCorrect: false },
        ],
        explanation: '"-네요"가 올바른 어미 표현입니다. "-내요"는 틀린 표기예요.',
        rule_key: '네요_내요',
        difficulty: 2,
      },
      {
        scene_index: 4,
        narrative: '집에 돌아와 간단한 저녁을 만들었다. 오늘의 요리를 마무리하며 드는 생각. 올바른 문장은?',
        choices: [
          { text: '오늘은 고생한 나에게 상을 줘야겠다.', isCorrect: true },
          { text: '오늘은 고생한 나에게 상을 줘야겟다.', isCorrect: false },
          { text: '오늘은 고생한 나에게 상을 줘야겠다!', isCorrect: true },
          { text: '오늘은 고생한 나에게 상을 주어야겟다.', isCorrect: false },
        ],
        explanation: '"주어야겠다"의 준말은 "줘야겠다"입니다. 감탄사 표기도 어울리면 허용돼요.',
        rule_key: '겠_겟',
        difficulty: 3,
      },
    ],
  },
];

async function main() {
  const count = await pool.query('SELECT COUNT(*)::int AS c FROM episodes');
  if (count.rows[0].c > 0) {
    logger.warn('시드 스킵 — 에피소드가 이미 존재');
    await pool.end();
    return;
  }

  for (const ep of EPISODES) {
    const ins = await pool.query(
      `INSERT INTO episodes (episode_date, category, title, scene_order, created_by)
       VALUES ($1, $2, $3, $4, 'seed') RETURNING id`,
      [ep.episode_date, ep.category, ep.title, JSON.stringify(ep.scene_order)],
    );
    const episodeId = ins.rows[0].id;
    for (const q of ep.questions) {
      await pool.query(
        `INSERT INTO questions (episode_id, scene_index, narrative, choices, explanation, rule_key, difficulty, judge_score)
         VALUES ($1, $2, $3, $4, $5, $6, $7, 10)`,
        [episodeId, q.scene_index, q.narrative, JSON.stringify(q.choices), q.explanation, q.rule_key, q.difficulty],
      );
    }
    logger.feature('seed', `에피소드 생성 "${ep.title}" (${ep.questions.length}문항)`);
  }
  await pool.end();
}

main().catch((err) => {
  logger.error('seed 실패', { error: err instanceof Error ? err.message : String(err) });
  process.exit(1);
});