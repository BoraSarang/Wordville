// MenuBarController — NSStatusItem + NSPopover 메뉴바 앱 컨트롤러
import AppKit
import SwiftUI

final class MenuBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let settings = SettingsStore.shared

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

        popover.contentSize = NSSize(width: 360, height: 520)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: PopoverRootView().environmentObject(settings))

        applyActivationPolicy()
        DebugLogger.shared.feature("메뉴바", "초기화 완료")
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        DebugLogger.shared.feature("팝오버", "표시됨")
    }

    private func closePopover() {
        popover.performClose(nil)
        DebugLogger.shared.feature("팝오버", "닫힘")
    }

    // Dock 표시 토글 (설정에서 호출) — 기본 .accessory (Dock 숨김)
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

    // Cmd+Shift+D 디버그 패널 (로컬 키 모니터 — 팝오버 포커스 중)
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

extension Notification.Name {
    static let toggleDebugPanel = Notification.Name("toggleDebugPanel")
}