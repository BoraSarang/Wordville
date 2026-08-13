// WordvilleApp — @main 진입점 (메뉴바 아이콘 + 게임 윈도우 하이브리드)
import SwiftUI

@main
struct WordvilleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuBar = MenuBarController()
    private let gameWindow = GameWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        gameWindow.setup()
        menuBar.gameWindow = gameWindow
        menuBar.setup()
        menuBar.monitorDebugHotkey()
        menuBar.applyActivationPolicy()
        gameWindow.show()
        DebugLogger.shared.feature("앱", "시작됨 (메뉴바 + 게임 윈도우)")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}