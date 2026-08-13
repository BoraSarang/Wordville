// DebugPanelView — Cmd+Shift+D 디버그 패널 (AGENTS.md 19장)
import SwiftUI

struct DebugPanelView: View {
    @State private var logs: [String] = []
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("디버그 패널").font(.headline)
                Spacer()
                Button("새로고침") { refresh() }
                Button("지우기") { DebugLogger.shared.clear(); refresh() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(logs.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .padding(12)
        .frame(width: 560, height: 360)
        .onAppear {
            refresh()
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in refresh() }
        }
        .onDisappear { timer?.invalidate() }
    }

    private func refresh() {
        logs = DebugLogger.shared.lines()
    }
}