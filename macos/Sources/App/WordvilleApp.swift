// WordvilleApp — @main 진입점 (메뉴바 전용 앱)
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar.setup()
        menuBar.monitorDebugHotkey()
        // 첫 실행 시 Dock 표시 여부: dockVisible 기본값 false → 숨김 상태 유지
    }
}