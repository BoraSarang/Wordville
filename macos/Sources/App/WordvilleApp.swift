// WordvilleApp — @main 진입점 (메뉴바 아이콘 + 게임 윈도우 하이브리드)
import SwiftUI
import CoreText
import Network

@main
struct WordvilleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        Settings {
            SettingsView(onClose: {})
                .environmentObject(settings)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuBar = MenuBarController()
    private let gameWindow = GameWindowController()
    private let debugPanel = DebugPanelWindowController()
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "wordville.network")

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerBundledFonts()
        gameWindow.setup()
        menuBar.gameWindow = gameWindow
        menuBar.setup()
        menuBar.monitorDebugHotkey()
        menuBar.applyActivationPolicy()
        debugPanel.setup()
        gameWindow.show()
        NotificationManager.shared.syncWithSetting(SettingsStore.shared.notificationsEnabled)
        startOfflineQueueSync()
        DebugLogger.shared.feature("앱", "시작됨 (메뉴바 + 게임 윈도우)")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // 오프라인 큐 자동 flush: 시작 시 + 온라인 복구 시 (DESIGN 1.2 FLUSH)
    private func startOfflineQueueSync() {
        Task {
            let pending = APIClient.shared.pendingCount()
            if pending > 0 {
                DebugLogger.shared.feature("오프라인큐", "시작 시 자동 동기화", meta: ["pending": pending])
                await APIClient.shared.flushQueue()
            }
        }
        pathMonitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                Task {
                    if APIClient.shared.pendingCount() > 0 {
                        DebugLogger.shared.feature("오프라인큐", "온라인 복구 감지 — 동기화", meta: ["pending": APIClient.shared.pendingCount()])
                        await APIClient.shared.flushQueue()
                    }
                }
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    private func registerBundledFonts() {
        guard let resourceURL = Bundle.main.resourceURL else { return }
        for name in ["NeoDunggeunmo.ttf", "Galmuri11.ttf", "Galmuri11-Bold.ttf"] {
            let url = resourceURL.appendingPathComponent(name)
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if let error = error?.takeRetainedValue() {
                DebugLogger.shared.log(.error, "폰트", "등록 실패", meta: ["font": name, "error": String(describing: error)])
            } else {
                DebugLogger.shared.log(.info, "폰트", "등록됨", meta: ["font": name])
            }
        }
    }
}