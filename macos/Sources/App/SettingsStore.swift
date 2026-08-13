// SettingsStore — UserDefaults 로컬 저장 (uuid, 닉네임, Dock 표시, 알림)
import Foundation

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var uuid: String {
        didSet { UserDefaults.standard.set(uuid, forKey: "uuid") }
    }
    @Published var nickname: String {
        didSet { UserDefaults.standard.set(nickname, forKey: "nickname") }
    }
    @Published var dockVisible: Bool {
        didSet { UserDefaults.standard.set(dockVisible, forKey: "dockVisible") }
    }
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var serverBaseURL: String {
        didSet { UserDefaults.standard.set(serverBaseURL, forKey: "serverBaseURL") }
    }
    @Published var profile: AuthUser?
    @Published var stats: UserStats?

    var level: Int { profile?.level ?? 1 }
    var exp: Int { profile?.exp ?? 0 }
    var streakDays: Int { profile?.streak_days ?? 0 }
    var league: String { profile?.league ?? "bronze" }
    var goldenPass: Bool { (profile?.streak_days ?? 0) >= 7 }

    private init() {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: "uuid") {
            uuid = existing
        } else {
            let newUUID = UUID().uuidString.lowercased()
            defaults.set(newUUID, forKey: "uuid")
            uuid = newUUID
        }
        nickname = defaults.string(forKey: "nickname") ?? "글마을 주민"
        dockVisible = defaults.object(forKey: "dockVisible") as? Bool ?? true
        notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        serverBaseURL = defaults.string(forKey: "serverBaseURL") ?? "http://localhost:3000"
        DebugLogger.shared.feature("SettingsStore", "로드됨", meta: ["uuid": uuid.prefix(8), "dock": dockVisible])
    }

    func refreshProfile() async {
        do {
            let user = try await APIClient.shared.fetchProfile()
            await MainActor.run {
                profile = user
                if !user.nickname.isEmpty, user.nickname != "글마을 주민" {
                    nickname = user.nickname
                }
            }
            DebugLogger.shared.feature("SettingsStore", "프로필 갱신", meta: ["nickname": user.nickname, "level": user.level ?? 1, "streak": user.streak_days ?? 0])
        } catch {
            DebugLogger.shared.log(.warn, "SettingsStore", "프로필 로드 실패", meta: ["error": String(describing: error)])
        }
        await refreshStats()
    }

    func refreshStats() async {
        do {
            let stats = try await APIClient.shared.fetchStats()
            await MainActor.run { self.stats = stats }
            DebugLogger.shared.feature("SettingsStore", "통계 갱신", meta: ["correct": stats.correct ?? 0, "wrong": stats.wrong ?? 0])
        } catch {
            DebugLogger.shared.log(.warn, "SettingsStore", "통계 로드 실패", meta: ["error": String(describing: error)])
        }
    }
}