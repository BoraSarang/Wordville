// GameModels — 서버 API 응답과 동일한 Codable 구조 (DESIGN.md 1.3)
import Foundation

struct Episode: Codable {
    let id: Int
    let episode_date: String
    let category: String
    let title: String
    let scene_order: [SceneOrder]
}

struct SceneOrder: Codable {
    let scene_index: Int
    let background: String
    let character: String
    let emotion: String
}

struct Question: Codable {
    let id: Int
    let scene_index: Int
    let narrative: String
    let choices: [Choice]
    let explanation: String?

    init(id: Int, scene_index: Int, narrative: String, choices: [Choice], explanation: String? = nil) {
        self.id = id
        self.scene_index = scene_index
        self.narrative = narrative
        self.choices = choices
        self.explanation = explanation
    }
}

struct Choice: Codable {
    let text: String
    let isCorrect: Bool
}

struct AnswerResult: Codable {
    let correct: Bool
    let correct_index: Int
    let explanation: String
    let exp_gained: Int
    let streak_days: Int
}

struct APIResponse<T: Codable>: Codable {
    let ok: Bool
    let data: T?
    let error: APIErrorBody?
}

struct APIErrorBody: Codable {
    let code: String
    let message: String
}

struct AuthUser: Codable {
    let id: String
    let nickname: String
    let avatar_url: String?
    let exp: Int?
    let streak_days: Int?
    let last_played: String?
    let league: String?
    let level: Int?
}

struct AuthResponse: Codable {
    let token: String
    let refresh_token: String?
    let user: AuthUser
}

struct UserStats: Codable {
    let correct: Int?
    let wrong: Int?
    let wrong_top: [WrongRule]?
}

struct WrongRule: Codable {
    let rule_key: String?
    let wrong_count: Int?
}

struct WeeklyRanking: Codable {
    let week_key: String?
    let my_rank: Int?
    let rankings: [RankingEntry]
}

struct RankingEntry: Codable {
    let id: String
    let nickname: String
    let league: String?
    let score: Int?
}

struct QuickQuestion: Codable {
    let id: Int
    let scene_index: Int
    let narrative: String
    let choices: [Choice]
    let explanation: String?
    let episode_title: String?
}

struct QuestionsResponse: Codable {
    let episode_id: Int
    let questions: [Question]
}