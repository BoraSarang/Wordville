// DebugPanelWindowController — 디버그 패널 전용 창 (AGENTS.md 19장: NSWindow .floating+100)
// Cmd+Shift+D 토글 — 팝오버/게임 윈도우와 무관한 독립 창
import AppKit
import SwiftUI

final class DebugPanelWindowController: NSObject {
    private var window: NSWindow?

    func setup() {
        NotificationCenter.default.addObserver(self, selector: #selector(toggle), name: .toggleDebugPanel, object: nil)
        DebugLogger.shared.feature("디버그", "패널 윈도우 준비됨")
    }

    @objc private func toggle() {
        if let window, window.isVisible {
            window.orderOut(nil)
            DebugLogger.shared.feature("디버그", "패널 닫힘")
        } else {
            show()
        }
    }

    private func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 400),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "디버그 패널"
            window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 100)
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: DebugPanelView())
            if let screen = NSScreen.main {
                let x = (screen.visibleFrame.midX - 280).rounded()
                let y = screen.visibleFrame.maxY - 440
                window.setFrameOrigin(NSPoint(x: x, y: y))
            } else {
                window.center()
            }
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        DebugLogger.shared.feature("디버그", "패널 열림")
    }
}