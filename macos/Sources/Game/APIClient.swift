// APIClient — 서버 연동 (auth/anon, episodes, answers) + 오프라인 큐
import Foundation

enum APIError: Error {
    case network
    case server(code: String, message: String)
}

struct QueuedAnswer: Codable {
    let questionId: Int
    let selected: String
    let combo: Int
}

final class APIClient {
    static let shared = APIClient()
    private let defaults = UserDefaults.standard
    private let queueKey = "offlineAnswerQueue"

    private var serverURL: String { SettingsStore.shared.serverBaseURL }
    private var token: String? { defaults.string(forKey: "authToken") }

    private func setToken(_ token: String) {
        defaults.set(token, forKey: "authToken")
        DebugLogger.shared.feature("APIClient", "토큰 저장됨")
    }

    // MARK: - 요청

    private func request<T: Codable>(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        authed: Bool = true
    ) async throws -> T {
        guard let url = URL(string: serverURL + path) else { throw APIError.network }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 10
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authed, let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.network
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.network }
        guard http.statusCode == 200 else {
            let apiError = try? JSONDecoder().decode(APIResponse<EmptyData>.self, from: data)
            throw APIError.server(code: apiError?.error?.code ?? "E-COM-NET-0001", message: apiError?.error?.message ?? "서버 오류")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - 인증

    func ensureAuth() async throws -> AuthUser {
        if let token, !token.isEmpty {
            do {
                let me: APIResponse<AuthUser> = try await request("/users/me")
                if let user = me.data { return user }
            } catch {
                DebugLogger.shared.log(.warn, "APIClient", "기존 토큰 무효 — 재인증", meta: ["error": String(describing: error)])
            }
        }
        let r: APIResponse<AuthResponse> = try await request("/auth/anon", method: "POST", authed: false)
        guard let data = r.data else { throw APIError.network }
        setToken(data.token)
        DebugLogger.shared.feature("APIClient", "익명 인증 완료", meta: ["user": data.user.id.prefix(8)])
        return data.user
    }

    func fetchProfile() async throws -> AuthUser {
        let r: APIResponse<AuthUser> = try await request("/users/me")
        guard let data = r.data else { throw APIError.network }
        return data
    }

    func updateNickname(_ nickname: String) async throws {
        let _: APIResponse<EmptyData> = try await request("/users/me", method: "PATCH", body: ["nickname": nickname])
        DebugLogger.shared.feature("APIClient", "닉네임 동기화 완료", meta: ["nickname": nickname])
    }

    func fetchStats() async throws -> UserStats {
        let r: APIResponse<UserStats> = try await request("/users/me/stats")
        guard let data = r.data else { throw APIError.network }
        return data
    }

    func fetchWeeklyRanking() async throws -> WeeklyRanking {
        let r: APIResponse<WeeklyRanking> = try await request("/rankings/weekly")
        guard let data = r.data else { throw APIError.network }
        DebugLogger.shared.feature("APIClient", "주간 랭킹 로드", meta: ["top": data.rankings.count, "myRank": data.my_rank ?? -1])
        return data
    }

    func fetchQuickQuestion() async throws -> QuickQuestion {
        let r: APIResponse<QuickQuestion> = try await request("/episodes/quick")
        guard let data = r.data else { throw APIError.network }
        DebugLogger.shared.feature("APIClient", "퀵플레이 문제 로드", meta: ["id": data.id])
        return data
    }

    func fetchEpisodeList() async throws -> [EpisodeSummary] {
        let r: APIResponse<[EpisodeSummary]> = try await request("/episodes")
        guard let data = r.data else { throw APIError.network }
        DebugLogger.shared.feature("APIClient", "에피소드 목록 로드", meta: ["count": data.count])
        return data
    }

    func fetchReviewQuestions() async throws -> ReviewEpisode {
        let r: APIResponse<ReviewEpisode> = try await request("/episodes/review")
        guard let data = r.data else { throw APIError.network }
        DebugLogger.shared.feature("APIClient", "복습 문제 로드", meta: ["count": data.questions.count])
        return data
    }

    // MARK: - 게임 데이터

    func fetchTodayEpisode() async throws -> Episode {
        let r: APIResponse<Episode> = try await request("/episodes/today")
        guard let data = r.data else { throw APIError.network }
        DebugLogger.shared.feature("APIClient", "오늘 에피소드", meta: ["id": data.id, "title": data.title])
        return data
    }

    func fetchQuestions(episodeId: Int) async throws -> [Question] {
        let r: APIResponse<QuestionsResponse> = try await request("/episodes/\(episodeId)/questions")
        guard let data = r.data else { throw APIError.network }
        DebugLogger.shared.feature("APIClient", "문제 로드", meta: ["count": data.questions.count])
        return data.questions
    }

    func submitAnswer(questionId: Int, selected: String, combo: Int) async throws -> AnswerResult {
        let r: APIResponse<AnswerResult> = try await request(
            "/answers",
            method: "POST",
            body: ["question_id": questionId, "selected": selected, "combo": combo]
        )
        guard let data = r.data else { throw APIError.network }
        DebugLogger.shared.feature("APIClient", "답안 제출", meta: ["correct": data.correct, "exp": data.exp_gained])
        return data
    }

    // MARK: - 오프라인 큐

    func enqueueAnswer(questionId: Int, selected: String, combo: Int) {
        var queue = loadQueue()
        queue.append(QueuedAnswer(questionId: questionId, selected: selected, combo: combo))
        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: queueKey)
        }
        DebugLogger.shared.log(.warn, "오프라인큐", "답안 저장됨", meta: ["pending": queue.count])
    }

    func pendingCount() -> Int {
        loadQueue().count
    }

    func queueItems() -> [QueuedAnswer] {
        loadQueue()
    }

    func checkHealth() async -> Bool {
        do {
            let r: APIResponse<HealthData> = try await request("/health", authed: false)
            DebugLogger.shared.feature("APIClient", "health 체크", meta: ["db": r.data?.db ?? "?", "latency_ms": r.data?.latency_ms ?? -1])
            return r.data?.db == "up"
        } catch {
            DebugLogger.shared.log(.warn, "APIClient", "health 실패", meta: ["error": String(describing: error)])
            return false
        }
    }

    // MARK: - 서버 디버그 (DEBUG 모드 전용)

    func fetchServerLogs() async -> [String] {
        do {
            let r: APIResponse<ServerLogs> = try await request("/debug/logs")
            return r.data?.logs ?? []
        } catch {
            DebugLogger.shared.log(.warn, "APIClient", "서버 로그 조회 실패", meta: ["error": String(describing: error)])
            return []
        }
    }

    func fetchServerCache() async -> ServerCacheInfo? {
        do {
            let r: APIResponse<ServerCacheInfo> = try await request("/debug/cache")
            return r.data
        } catch {
            DebugLogger.shared.log(.warn, "APIClient", "서버 캐시 조회 실패", meta: ["error": String(describing: error)])
            return nil
        }
    }

    func fetchServerQueue() async -> ServerQueueInfo? {
        do {
            let r: APIResponse<ServerQueueInfo> = try await request("/debug/queue")
            return r.data
        } catch {
            DebugLogger.shared.log(.warn, "APIClient", "서버 큐 조회 실패", meta: ["error": String(describing: error)])
            return nil
        }
    }

    private func loadQueue() -> [QueuedAnswer] {
        guard let data = defaults.data(forKey: queueKey),
              let queue = try? JSONDecoder().decode([QueuedAnswer].self, from: data) else { return [] }
        return queue
    }

    func flushQueue() async {
        var queue = loadQueue()
        guard !queue.isEmpty else { return }
        var remaining: [QueuedAnswer] = []
        for item in queue {
            do {
                _ = try await submitAnswer(questionId: item.questionId, selected: item.selected, combo: item.combo)
                DebugLogger.shared.feature("오프라인큐", "동기화 성공", meta: ["qid": item.questionId])
            } catch {
                remaining.append(item)
                break
            }
        }
        if let data = try? JSONEncoder().encode(remaining) {
            defaults.set(data, forKey: queueKey)
        }
    }
}

struct EmptyData: Codable {}

struct HealthData: Codable {
    let ok: Bool?
    let service: String?
    let version: String?
    let db: String?
    let latency_ms: Int?
}

struct ServerLogs: Codable {
    let logs: [String]?
}

struct ServerCacheInfo: Codable {
    let hit_rate: Double?
    let entries: Int?
    let note: String?
}

struct ServerQueueInfo: Codable {
    let pending: Int?
    let note: String?
}