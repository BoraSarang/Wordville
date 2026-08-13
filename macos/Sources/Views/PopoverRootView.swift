// PopoverRootView — 메뉴바 팝오버 (메뉴/설정/랭킹 내부 화면 전환 — 항상 메뉴바 아래 상단 정렬)
import SwiftUI

enum PopoverScreen {
    case main, settings, ranking
}

struct PopoverRootView: View {
    @EnvironmentObject var settings: SettingsStore
    @ObservedObject var menuBar: MenuBarController
    @State private var screen: PopoverScreen = .main

    var body: some View {
        VStack(spacing: 0) {
            switch screen {
            case .main:
                header
                Divider()
                menuList
                Divider()
                footer
            case .settings:
                SettingsView {
                    screen = .main
                }
                .environmentObject(settings)
            case .ranking:
                RankingView {
                    screen = .main
                }
                .environmentObject(settings)
            }
        }
        .frame(width: 360)
        .onChange(of: screen) { _, newScreen in
            switch newScreen {
            case .main: menuBar.setPopoverHeight(380)
            case .settings: menuBar.setPopoverHeight(460)
            case .ranking: menuBar.setPopoverHeight(500)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRankingRequest)) { _ in
            screen = .ranking
        }
        .task { await settings.refreshProfile() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AsyncImage(url: settings.profile?.avatar_url.flatMap { URL(string: $0) }) { image in
                image.resizable().interpolation(.none)
            } placeholder: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title)
                    .foregroundStyle(.brown)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.profile?.nickname ?? settings.nickname)
                    .font(.headline)
                Text("Lv.\(settings.level) · 🔥\(settings.streakDays)일 · EXP \(settings.exp)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            LeagueBadge(league: settings.league)
        }
        .padding(14)
    }

    private var menuList: some View {
        VStack(spacing: 2) {
            MenuRow(icon: "bolt.fill", title: "1문제 퀵플레이", subtitle: "랜덤 문제 바로 도전") {
                DebugLogger.shared.feature("퀵플레이", "팝오버에서 선택됨")
                menuBar.openQuickPlay()
            }
            MenuRow(icon: "book.fill", title: "오늘의 에피소드", subtitle: "일상 상황극 맞춤법 퀴즈") {
                DebugLogger.shared.feature("오늘의에피소드", "선택됨")
                menuBar.openGame()
            }
            MenuRow(icon: "trophy.fill", title: "주간 랭킹", subtitle: "리그 순위 확인") {
                DebugLogger.shared.feature("랭킹", "팝오버에서 열림")
                screen = .ranking
            }
            MenuRow(icon: "gearshape.fill", title: "설정…", subtitle: "Dock 표시 / 닉네임 / 알림") {
                DebugLogger.shared.feature("설정", "팝오버에서 열림")
                screen = .settings
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

struct LeagueBadge: View {
    let league: String

    private var color: Color {
        switch league {
        case "silver": return .gray
        case "gold": return .orange
        case "diamond": return .blue
        default: return Color(red: 0.55, green: 0.36, blue: 0.16)
        }
    }

    var body: some View {
        Text(leagueName(league))
            .font(.caption2).bold()
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
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
