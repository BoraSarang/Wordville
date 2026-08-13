// GameData — 로컬 데모 데이터 (서버 연동 전 사용, 서버 시드와 동일 스키마)
// T3.3에서 APIClient로 교체
import Foundation

enum GameData {
    static let demoEpisode = Episode(
        id: 1,
        episode_date: "2026-08-13",
        category: "kitchen",
        title: "부엌의 첫 아침",
        scene_order: (0..<5).map { SceneOrder(scene_index: $0, background: "kitchen", character: "villager", emotion: $0 % 2 == 0 ? "idle" : "happy") }
    )

    static let demoQuestions: [Question] = [
        Question(
            id: 1,
            scene_index: 0,
            narrative: "아침에 눈을 뜬 주인공. 오늘이며칠일까?\n방금 한 생각을 올바르게 적은 문장은?",
            choices: [
                Choice(text: "오늘이며칠일까?", isCorrect: false),
                Choice(text: "오늘이 며칠일까?", isCorrect: true),
                Choice(text: "오늘이 몇일일까?", isCorrect: false),
                Choice(text: "오늘이 머칠일까?", isCorrect: false),
            ]
        ),
        Question(
            id: 2,
            scene_index: 1,
            narrative: "부엌에서 냉장고를 열어보니 우유가 다 떨어져 있었다.\n올바른 문장을 고르세요.",
            choices: [
                Choice(text: "우유팩은 분리수거함에 버려야 돼요.", isCorrect: true),
                Choice(text: "우유팩은 분리수거함에 버려야 되요.", isCorrect: false),
                Choice(text: "우유팩은 분리수거함에 버려야 되여.", isCorrect: false),
                Choice(text: "우유팩은 분리수거함에 버려야 돼여.", isCorrect: false),
            ]
        ),
        Question(
            id: 3,
            scene_index: 2,
            narrative: "주인공이 시장에 가려고 한다. 지갑을 챙겼는지 확인하며 중얼거린다.\n올바른 문장은?",
            choices: [
                Choice(text: "지갑을 안 챙겼네?", isCorrect: true),
                Choice(text: "지갑을 않 챙겼네?", isCorrect: false),
                Choice(text: "지갑을 안챙겼네?", isCorrect: false),
                Choice(text: "지갑을 않챙겼네?", isCorrect: false),
            ]
        ),
        Question(
            id: 4,
            scene_index: 3,
            narrative: "시장에서 포도를 샀다. 계산대에서 가격을 보고 놀랐다.\n올바른 문장을 고르세요.",
            choices: [
                Choice(text: "와, 포도가 이렇게 비싸네요!", isCorrect: true),
                Choice(text: "와, 포도가 이렇게 비싸내요!", isCorrect: false),
                Choice(text: "와, 포도가 이렇게 비싸네여!", isCorrect: false),
                Choice(text: "와, 포도가 이렇게 비싸내여!", isCorrect: false),
            ]
        ),
        Question(
            id: 5,
            scene_index: 4,
            narrative: "집에 돌아와 간단한 저녁을 만들었다.\n오늘의 요리를 마무리하며 드는 생각. 올바른 문장은?",
            choices: [
                Choice(text: "오늘은 고생한 나에게 상을 줘야겠다.", isCorrect: true),
                Choice(text: "오늘은 고생한 나에게 상을 줘야겟다.", isCorrect: false),
                Choice(text: "오늘은 고생한 나에게 상을 주어야겟다.", isCorrect: false),
                Choice(text: "오늘은 고생한 나에게 상을 줘야겠다!", isCorrect: true),
            ]
        ),
    ]
}