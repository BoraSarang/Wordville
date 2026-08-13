// SettingsView — 설정: 닉네임(서버 동기화), 알림, 서버 주소
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    let onClose: () -> Void
    @State private var nicknameInput = ""
    @State private var nicknameMessage: String?
    @State private var nicknameSaving = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("설정").font(.headline)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            Form {
            Section("일반") {
                Toggle("Dock에 아이콘 표시", isOn: $settings.dockVisible)
                    .onChange(of: settings.dockVisible) { _, newValue in
                        DebugLogger.shared.feature("설정", "Dock 토글 변경됨", meta: ["visible": newValue])
                        MenuBarController().applyActivationPolicy()
                    }
                Toggle("매일 알림 (00:00 KST)", isOn: $settings.notificationsEnabled)
                    .onChange(of: settings.notificationsEnabled) { _, newValue in
                        DebugLogger.shared.feature("설정", "알림 토글 변경됨", meta: ["enabled": newValue])
                        NotificationManager.shared.syncWithSetting(newValue)
                    }
            }

            Section("프로필") {
                HStack {
                    TextField("닉네임 (1~20자)", text: $nicknameInput)
                        .onAppear { nicknameInput = settings.nickname }
                        .onSubmit { saveNickname() }
                    if nicknameSaving {
                        ProgressView().controlSize(.small)
                    }
                }
                if let nicknameMessage {
                    Text(nicknameMessage)
                        .font(.caption)
                        .foregroundStyle(nicknameMessage.hasPrefix("저장") ? .green : .red)
                }
                Text("ID: \(settings.uuid.prefix(8))… · Lv.\(settings.level) · EXP \(settings.exp) · 🔥\(settings.streakDays)일")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let stats = settings.stats {
                    Text("정답 \(stats.correct ?? 0) · 오답 \(stats.wrong ?? 0) · 자주 틀리는 유형: \(stats.wrong_top?.first?.rule_key ?? "-")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("서버") {
                TextField("서버 주소", text: $settings.serverBaseURL)
                    .font(.caption)
                    .onSubmit {
                        DebugLogger.shared.feature("설정", "서버 주소 변경", meta: ["url": settings.serverBaseURL])
                    }
            }

            Section {
                HStack {
                    Spacer()
                    Text("글마을 달인 v0.1.0")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360, height: 420)
        }
    }

    private func saveNickname() {
        let trimmed = nicknameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 20 else {
            nicknameMessage = "닉네임은 1~20자로 입력해 주세요."
            DebugLogger.shared.log(.warn, "설정", "닉네임 길이 오류", meta: ["입력": nicknameInput.count])
            return
        }
        nicknameSaving = true
        Task {
            do {
                try await APIClient.shared.updateNickname(trimmed)
                await MainActor.run {
                    settings.nickname = trimmed
                    nicknameMessage = "저장되었습니다."
                    nicknameSaving = false
                    Task { await settings.refreshProfile() }
                }
                DebugLogger.shared.feature("설정", "닉네임 저장됨", meta: ["nickname": trimmed])
            } catch let APIError.server(code, message) {
                await MainActor.run {
                    nicknameMessage = message
                    nicknameSaving = false
                }
                DebugLogger.shared.log(.error, "설정", "닉네임 저장 실패", meta: ["code": code, "message": message])
            } catch {
                await MainActor.run {
                    nicknameMessage = "서버에 연결할 수 없습니다."
                    nicknameSaving = false
                }
                DebugLogger.shared.log(.error, "설정", "닉네임 저장 실패", meta: ["error": String(describing: error)])
            }
        }
    }
}