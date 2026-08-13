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
}