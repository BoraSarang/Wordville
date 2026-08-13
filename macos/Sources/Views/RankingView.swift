// RankingView — 주간 랭킹 시트 (내 순위 + Top 50)
import SwiftUI

struct RankingView: View {
    @EnvironmentObject var settings: SettingsStore
    let onClose: () -> Void
    @State private var ranking: WeeklyRanking?
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let errorMessage {
                ContentUnavailableView("랭킹을 불러오지 못했습니다", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
            } else if loading {
                ProgressView("로딩 중…")
                    .frame(maxHeight: .infinity)
            } else if let ranking, ranking.rankings.isEmpty {
                ContentUnavailableView("아직 순위가 없습니다", systemImage: "trophy", description: Text("주간 점수를 쌓아 랭킹에 올라보세요!"))
            } else if let ranking {
                List {
                    if let myRank = ranking.my_rank {
                        Section {
                            HStack {
                                Text("\(myRank)위")
                                    .font(.headline).monospacedDigit()
                                    .frame(width: 44, alignment: .leading)
                                Text(settings.profile?.nickname ?? settings.nickname)
                                    .font(.headline)
                                Spacer()
                                LeagueBadge(league: settings.league)
                                Text("나")
                                    .font(.caption2).bold()
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor, in: Capsule())
                            }
                        }
                    }
                    Section("Top \(ranking.rankings.count)") {
                        ForEach(Array(ranking.rankings.enumerated()), id: \.element.id) { index, entry in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(index < 3 ? .orange : .secondary)
                                    .frame(width: 44, alignment: .leading)
                                Text(entry.nickname)
                                    .lineLimit(1)
                                Spacer()
                                LeagueBadge(league: entry.league ?? "bronze")
                                Text("\(entry.score ?? 0)점")
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 420, height: 460)
        .task {
            await load()
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "trophy.fill")
                .foregroundStyle(.orange)
            Text("주간 랭킹")
                .font(.headline)
            Spacer()
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    private func load() async {
        do {
            let data = try await APIClient.shared.fetchWeeklyRanking()
            await MainActor.run {
                ranking = data
                loading = false
            }
            DebugLogger.shared.feature("랭킹", "로드 완료", meta: ["myRank": data.my_rank ?? -1, "count": data.rankings.count])
        } catch {
            await MainActor.run {
                errorMessage = "네트워크 연결을 확인해 주세요."
                loading = false
            }
            DebugLogger.shared.log(.warn, "랭킹", "로드 실패", meta: ["error": String(describing: error)])
        }
    }
}