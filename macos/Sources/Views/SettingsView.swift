// SettingsView — 설정: Dock 표시 토글, 닉네임, 알림, 서버 주소
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var nicknameInput = ""

    var body: some View {
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
                    }
            }

            Section("프로필") {
                TextField("닉네임 (1~20자)", text: $nicknameInput)
                    .onAppear { nicknameInput = settings.nickname }
                    .onSubmit {
                        let trimmed = nicknameInput.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, trimmed.count <= 20 else {
                            DebugLogger.shared.log(.warn, "설정", "닉네임 길이 오류", meta: ["입력": nicknameInput.count])
                            return
                        }
                        settings.nickname = trimmed
                        DebugLogger.shared.feature("설정", "닉네임 저장됨", meta: ["nickname": trimmed])
                    }
                Text("ID: \(settings.uuid.prefix(8))…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .frame(width: 420, height: 320)
    }
}