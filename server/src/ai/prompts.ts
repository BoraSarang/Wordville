// 문제 생성 + 심판 프롬프트 (AI_MODELS.json prompt_version 연동)
// 언어 규칙: 프롬프트는 한국어, 생성 결과 JSON은 스키마 엄격 준수

export const GENERATE_PROMPT_VERSION = 'gen_v0.1';
export const JUDGE_PROMPT_VERSION = 'judge_v0.1';

const CATEGORY_NAMES: Record<string, string> = {
  kitchen: '부엌',
  office: '회사',
  trip: '여행',
};

export function buildGeneratePrompt(category: string, today: string): { system: string; user: string } {
  return {
    system:
      '당신은 한국어 맞춤법 퀴즈 게임 "글마을 달인"의 문제 출제자입니다. ' +
      '한국어 원어민 초등학생~성인 모두가 즐길 수 있는 일상 상황극 기반 문장형 문제를 만듭니다. ' +
      '반드시 유효한 JSON만 출력하세요. 마크다운, 코드블록, 설명 금지. ' +
      '아래 JSON 스키마를 정확히 준수하세요.',
    user: `오늘 날짜: ${today}
카테고리: ${CATEGORY_NAMES[category] ?? category}

다음 JSON 스키마로 에피소드 1개(문제 5문항)를 생성하세요:
{
  "category": "${category}",
  "title": "에피소드 제목 (8~15자, 일상 상황)",
  "scene_order": [{"scene_index": 0, "background": "kitchen|office|trip 중 1", "character": "villager", "emotion": "idle|happy|surprised|sad 중 1"}],
  "questions": [
    {
      "scene_index": 0,
      "narrative": "상황극 서사 + 질문 (50~90자, 한국어 문장, 말줄임표 사용 금지)",
      "choices": [{"text": "보기1", "isCorrect": false}, {"text": "보기2", "isCorrect": true}, {"text": "보기3", "isCorrect": false}, {"text": "보기4", "isCorrect": false}],
      "explanation": "정답 해설 (30~60자, 교정 이유 포함)",
      "rule_key": "맞춤법 규칙 식별자 (예: 되_돼, 며칠_몇일, 안_않, 네요_내요, 줄임말, 띄어쓰기)",
      "difficulty": 1|2|3
    }
  ]
}

요구사항:
- questions는 반드시 5개, scene_index는 0~4 순서
- 각 문제는 4지선다, 정답은 정확히 1개 (isCorrect: true 1개)
- 문제는 한국어 원어민도 헷갈리는 실용적인 맞춤법/문법/띄어쓰기 규칙
- narrative는 자연스러운 일상 대화/독백, 문장형 (단어 단답형 금지)
- 보기는 서로 비슷한 길이, 오답은 실제 한국어 사용자가 흔히 하는 오류
- rule_key는 5개 문제가 서로 다른 규칙이어야 함`,
  };
}

export function buildJudgePrompt(category: string, candidateJson: string): { system: string; user: string } {
  return {
    system:
      '당신은 한국어 맞춤법 퀴즈 품질 심판관입니다. 출제된 문제 묶음을 검토하고 점수를 매깁니다. ' +
      '반드시 유효한 JSON만 출력하세요. 마크다운, 코드블록 금지.',
    user: `카테고리: ${category}

검토할 문제 JSON:
${candidateJson}

다음 JSON 스키마로 판정하세요:
{"judge_score": 0~10, "reasons": ["..."], "is_valid": true|false}

평가 기준 (각 0~2점, 총 10점):
1. 정답이 명확하고 논쟁 여지가 없어야 함 (2점)
2. narrative가 자연스러운 일상 상황이어야 함 (2점)
3. 5문항이 서로 다른 맞춤법 규칙이어야 함 (2점)
4. 오답 보기가 현실적인 오류여야 함 (2점)
5. explanation이 정확하고 이해하기 쉬워야 함 (2점)

judge_score 7점 이상이면 is_valid: true.`,
  };
}