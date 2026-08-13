// PopoverRootView — 메뉴바 팝오버 루트: 오늘의 에피소드 / 퀵플레이 / 프로필 / 설정 / 종료
import SwiftUI

struct PopoverRootView: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var showDebugPanel = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            menuList
            Divider()
            footer
        }
        .frame(width: 360)
        .onReceive(NotificationCenter.default.publisher(for: .toggleDebugPanel)) { _ in
            showDebugPanel.toggle()
        }
        .sheet(isPresented: $showDebugPanel) {
            DebugPanelView()
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "pencil.and.list.clipboard")
                .font(.title2)
            Text("글마을 달인")
                .font(.headline)
            Spacer()
            Text("🔥 \(settings.nickname)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private var menuList: some View {
        VStack(spacing: 4) {
            MenuRow(icon: "book.fill", title: "오늘의 에피소드", subtitle: "일상 상황극 맞춤법 퀴즈") {
                DebugLogger.shared.feature("오늘의에피소드", "선택됨")
            }
            MenuRow(icon: "bolt.fill", title: "1문제 퀵플레이", subtitle: "빠르게 1문제 풀기") {
                DebugLogger.shared.feature("퀵플레이", "선택됨")
            }
            MenuRow(icon: "person.crop.circle", title: "프로필", subtitle: "닉네임 · 스트릭 · 랭킹") {
                DebugLogger.shared.feature("프로필", "선택됨")
            }
            MenuRow(icon: "gearshape.fill", title: "설정…", subtitle: "Dock 표시, 닉네임, 알림") {
                DebugLogger.shared.feature("설정", "선택됨")
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
        .padding(8)
    }

    private var footer: some View {
        HStack {
            Button("디버그 패널") {
                DebugLogger.shared.feature("DebugPanel", "메뉴로 표시됨")
                showDebugPanel = true
            }
            .font(.caption)
            Spacer()
            Button("종료") {
                MenuBarController().quit()
            }
            .font(.caption)
        }
        .padding(12)
    }
}

struct MenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 22)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}