// PopoverRootView — 메뉴바 팝오버 메뉴 (오늘의 에피소드 / 설정… / 종료)
import SwiftUI

struct PopoverRootView: View {
    @EnvironmentObject var settings: SettingsStore
    @ObservedObject var menuBar: MenuBarController
    @State private var showSettings = false
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
        }
        .sheet(isPresented: $showDebugPanel) {
            DebugPanelView()
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "pencil.and.list.clipboard.fill")
                .font(.title2)
                .foregroundStyle(.brown)
            VStack(alignment: .leading, spacing: 2) {
                Text("글마을 달인")
                    .font(.headline)
                Text(settings.nickname)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
    }

    private var menuList: some View {
        VStack(spacing: 2) {
            MenuRow(icon: "book.fill", title: "오늘의 에피소드", subtitle: "일상 상황극 맞춤법 퀴즈") {
                DebugLogger.shared.feature("오늘의에피소드", "선택됨")
                menuBar.openGame()
            }
            MenuRow(icon: "gearshape.fill", title: "설정…", subtitle: "Dock 표시 / 닉네임 / 알림") {
                DebugLogger.shared.feature("설정", "팝오버에서 열림")
                showSettings = true
            }
        }
        .padding(8)
    }

    private var footer: some View {
        HStack {
            Text("v0.1.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("종료") {
                DebugLogger.shared.feature("메뉴바", "종료 버튼")
                menuBar.quit()
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
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.brown)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}