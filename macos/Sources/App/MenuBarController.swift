// MenuBarController — NSStatusItem 메뉴바 아이콘 + 팝오버 메뉴
// 메뉴: 오늘의 에피소드(게임 윈도우 열기) / 설정…(Dock 토글 포함) / 종료
import AppKit
import SwiftUI

final class MenuBarController: NSObject, ObservableObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let settings = SettingsStore.shared
    weak var gameWindow: GameWindowController?

    func setup() {
        DebugLogger.shared.feature("메뉴바", "초기화 시작")
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "pencil.and.list.clipboard", accessibilityDescription: "Wordville")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }
        statusItem = item

        popover.contentSize = NSSize(width: 360, height: 380)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView(menuBar: self).environmentObject(settings)
        )
        DebugLogger.shared.feature("메뉴바", "초기화 완료")
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    // 팝오버 내부 화면 높이 변경 (메뉴/설정/랭킹 전환 시)
    func setPopoverHeight(_ height: CGFloat) {
        popover.contentSize = NSSize(width: 360, height: height)
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        DebugLogger.shared.feature("팝오버", "표시됨")
    }

    // 게임 윈도우 열기 (팝오버 메뉴에서 호출)
    func openGame() {
        popover.performClose(nil)
        DebugLogger.shared.feature("메뉴바", "게임 윈도우 열기")
        gameWindow?.show()
    }

    // 1문제 퀵플레이 (팝오버 메뉴에서 호출)
    func openQuickPlay() {
        popover.performClose(nil)
        DebugLogger.shared.feature("메뉴바", "퀵플레이 열기")
        gameWindow?.show()
        NotificationCenter.default.post(name: .quickPlayRequest, object: nil)
    }

    // Dock 표시 토글 (설정에서 호출) — 기본 .regular (Dock + 메뉴바 동시 사용)
    func applyActivationPolicy() {
        let visible = settings.dockVisible
        NSApp.setActivationPolicy(visible ? .regular : .accessory)
        if visible {
            NSApp.activate(ignoringOtherApps: true)
        }
        DebugLogger.shared.feature("Dock토글", visible ? "표시" : "숨김", meta: ["policy": visible ? "regular" : "accessory"])
    }

    func quit() {
        DebugLogger.shared.feature("앱", "종료")
        NSApp.terminate(nil)
    }

    // Cmd+Shift+D 디버그 패널 (팝오버/게임 윈도우 포커스 중)
    func monitorDebugHotkey() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains([.command, .shift]),
                  event.charactersIgnoringModifiers?.lowercased() == "d" else { return event }
            self?.toggleDebugPanel()
            return nil
        }
    }

    private func toggleDebugPanel() {
        DebugLogger.shared.feature("DebugPanel", "Cmd+Shift+D 토글")
        NotificationCenter.default.post(name: .toggleDebugPanel, object: nil)
    }
}