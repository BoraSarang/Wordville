// DebugPanelView — AGENTS.md 19장 디버그 패널 (로그 / 오프라인 큐 / 시스템)
// Cmd+Shift+D — 로그 필터, 오프라인 큐 뷰어+동기화, 프로필·서버 상태
import SwiftUI

struct DebugPanelView: View {
    @State private var logs: [String] = []
    @State private var filter: String? = nil
    @State private var timer: Timer?
    @State private var tab: Tab = .logs
    @State private var queue: [QueuedAnswer] = []
    @State private var syncing = false
    @State private var health: Bool?
    @State private var healthChecked = false
    @State private var selectedLine: String?
    @State private var copyFeedback: String?
    @State private var serverLogs: [String] = []
    @State private var serverCache: ServerCacheInfo?
    @State private var serverQueue: ServerQueueInfo?

    enum Tab: String, CaseIterable {
        case logs = "로그"
        case queue = "오프라인 큐"
        case system = "시스템"
        case server = "서버"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("디버그 패널").font(.headline)
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
                Spacer()
                Button("새로고침") { refresh() }
                Button("지우기") { DebugLogger.shared.clear(); refresh() }
            }
            switch tab {
            case .logs: logView
            case .queue: queueView
            case .system: systemView
            case .server: serverView
            }
        }
        .padding(12)
        .frame(width: 560, height: 400)
        .onAppear {
            refresh()
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in refresh() }
        }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - 로그 탭

    private var logView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ForEach(["전체", "INFO", "WARN", "ERROR", "FEATURE", "PERF", "CACHE"], id: \.self) { level in
                    Button(level) {
                        filter = (level == "전체") ? nil : level
                        selectedLine = nil
                        refresh()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(filter == level || (level == "전체" && filter == nil) ? .accentColor : .secondary)
                }
                Spacer()
                Button("전체 복사") { copyToClipboard(filteredLogs.joined(separator: "\n")) }
                Button("선택 줄 복사") { copySelectedLine() }
                    .disabled(selectedLine == nil)
                if let copyFeedback {
                    Text(copyFeedback)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(filteredLogs.enumerated()), id: \.offset) { _, line in
                        Button {
                            selectedLine = (selectedLine == line) ? nil : line
                        } label: {
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(color(for: line))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(2)
                                .background(selectedLine == line ? Color.accentColor.opacity(0.15) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        .onTapGesture(count: 2) {
                            copyToClipboard(line)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private var filteredLogs: [String] {
        guard let filter else { return logs }
        return logs.filter { $0.contains("[\(filter)]") }
    }

    private func color(for line: String) -> Color {
        if line.contains("[ERROR]") { return .red }
        if line.contains("[WARN]") { return .orange }
        if line.contains("[PERF]") || line.contains("[CACHE]") { return .purple }
        if line.contains("[FEATURE]") { return .blue }
        return .primary
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        copyFeedback = "복사됨 (\(text.count)자)"
        DebugLogger.shared.feature("디버그", "클립보드 복사", meta: ["chars": text.count])
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run { copyFeedback = nil }
        }
    }

    private func copySelectedLine() {
        guard let selectedLine else { return }
        copyToClipboard(selectedLine)
    }

    // MARK: - 오프라인 큐 탭

    private var queueView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("대기 중: \(queue.count)건")
                    .font(.callout.bold())
                Spacer()
                Button(syncing ? "동기화 중…" : "지금 동기화") {
                    flushQueue()
                }
                .disabled(syncing || queue.isEmpty)
            }
            if queue.isEmpty {
                ContentUnavailableView("대기 작업 없음", systemImage: "checkmark.circle", description: Text("모든 답안이 서버에 전송되었습니다."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(queue.enumerated()), id: \.offset) { _, item in
                            Text("Q\(item.questionId) · combo \(item.combo) · \(item.selected)")
                                .font(.system(size: 11, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
    }

    private func flushQueue() {
        syncing = true
        Task {
            await APIClient.shared.flushQueue()
            await MainActor.run {
                queue = APIClient.shared.queueItems()
                syncing = false
            }
            DebugLogger.shared.feature("디버그", "큐 동기화 완료", meta: ["remaining": queue.count])
        }
    }

    // MARK: - 시스템 탭

    private var systemView: some View {
        let settings = SettingsStore.shared
        return VStack(alignment: .leading, spacing: 10) {
            Group {
                row("프로필", settings.profile?.nickname ?? settings.nickname)
                row("UUID", "\(settings.uuid.prefix(8))…")
                row("레벨", "Lv.\(settings.level) · EXP \(settings.exp)")
                row("스트릭", "🔥\(settings.streakDays)일 · 리그 \(leagueName(settings.league))")
                row("서버 주소", settings.serverBaseURL)
                row("Dock 표시", settings.dockVisible ? "켜짐" : "꺼짐")
                row("알림", settings.notificationsEnabled ? "켜짐" : "꺼짐")
            }
            Divider()
            HStack {
                Text("서버 상태")
                    .font(.callout.bold())
                Spacer()
                if let health {
                    Label(health ? "정상 (DB up)" : "연결 불가", systemImage: health ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(health ? .green : .red)
                }
                Button("health 확인") {
                    Task {
                        let ok = await APIClient.shared.checkHealth()
                        await MainActor.run {
                            health = ok
                            healthChecked = true
                        }
                    }
                }
                .controlSize(.small)
            }
            Spacer()
        }
        .onAppear {
            Task {
                let ok = await APIClient.shared.checkHealth()
                await MainActor.run {
                    health = ok
                    healthChecked = true
                }
            }
        }
    }

    // MARK: - 서버 탭

    private var serverView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("서버 상태").font(.callout.bold())
                Spacer()
                if let serverCache {
                    Text("LLM 캐시: hit \(Int((serverCache.hit_rate ?? 0) * 100))% · \(serverCache.entries ?? 0)건")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let serverQueue {
                    Text("서버 큐: \(serverQueue.pending ?? 0)건")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("새로고침") { Task { await loadServerInfo() } }
                    .controlSize(.small)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(serverLogs.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 9, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .task { await loadServerInfo() }
    }

    private func loadServerInfo() async {
        async let logs = APIClient.shared.fetchServerLogs()
        async let cache = APIClient.shared.fetchServerCache()
        async let queue = APIClient.shared.fetchServerQueue()
        let (l, c, q) = await (logs, cache, queue)
        await MainActor.run {
            serverLogs = l
            serverCache = c
            serverQueue = q
        }
        DebugLogger.shared.feature("디버그", "서버 정보 로드", meta: ["logs": l.count])
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, design: .monospaced))
        }
    }

    private func refresh() {
        logs = DebugLogger.shared.lines()
        if tab == .queue {
            queue = APIClient.shared.queueItems()
        }
    }
}