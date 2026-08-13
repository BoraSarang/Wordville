// GameWindowController — 게임 윈도우 (360×780, 별도 창)
import AppKit
import SwiftUI

final class GameWindowController: NSObject {
    private var window: NSWindow?
    private let settings = SettingsStore.shared

    func setup() {
        DebugLogger.shared.feature("게임윈도우", "초기화 완료")
    }

    func show() {
        if let window {
            // 닫힌 윈도우도 재사용 (재생성 시 use-after-free 방지)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: GameScene.canvasW, height: GameScene.canvasH),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "글마을 달인"
        window.contentViewController = NSHostingController(rootView: GameRootView().environmentObject(settings))
        if let screen = NSScreen.main {
            let x = (screen.visibleFrame.midX - window.frame.width / 2).rounded()
            let y = screen.visibleFrame.maxY - window.frame.height - 40
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        self.window = window
        DebugLogger.shared.feature("게임윈도우", "표시됨", meta: ["w": Int(GameScene.canvasW), "h": Int(GameScene.canvasH)])
    }

    func isVisible() -> Bool {
        window?.isVisible ?? false
    }
}

extension Notification.Name {
    static let toggleDebugPanel = Notification.Name("toggleDebugPanel")
    static let quickPlayRequest = Notification.Name("quickPlayRequest")
    static let openRankingRequest = Notification.Name("openRankingRequest")
}