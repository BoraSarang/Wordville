// GameWindowController — 게임 윈도우 (360×780, 별도 창)
// 닫힌 윈도우는 프로퍼티에서 해제(nil)하고, 다시 열 때 재생성한다.
// (닫힌 NSWindow를 보관하면 isReleasedWhenClosed 동작으로 dangling 포인터가 되어 크래시)
import AppKit
import SwiftUI

final class GameWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let settings = SettingsStore.shared

    func setup() {
        DebugLogger.shared.feature("게임윈도우", "초기화 완료")
    }

    func show() {
        if let window {
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
        window.isReleasedWhenClosed = false
        window.delegate = self
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

    // 창이 닫히면 보관된 참조 제거 (다음 show()에서 재생성)
    func windowWillClose(_ notification: Notification) {
        DebugLogger.shared.feature("게임윈도우", "닫힘 — 프로퍼티 해제")
        window = nil
    }
}

extension Notification.Name {
    static let toggleDebugPanel = Notification.Name("toggleDebugPanel")
    static let quickPlayRequest = Notification.Name("quickPlayRequest")
    static let openRankingRequest = Notification.Name("openRankingRequest")
}