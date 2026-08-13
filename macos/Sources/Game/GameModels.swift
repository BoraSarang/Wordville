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
    let error: APIError?
}

struct APIError: Codable {
    let code: String
    let message: String
}