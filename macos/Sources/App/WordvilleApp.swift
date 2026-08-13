// WordvilleApp — @main 진입점 (메뉴바 아이콘 + 게임 윈도우 하이브리드)
import SwiftUI
import CoreText

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
        registerBundledFonts()
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