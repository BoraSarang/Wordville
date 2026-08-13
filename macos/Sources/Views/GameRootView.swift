// GameRootView — 게임 윈도우 루트 (순수 게임 화면 + DebugPanel)
import SwiftUI

struct GameRootView: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var showDebugPanel = false

    var body: some View {
        ZStack {
            GameViewRepresentable()
                .frame(width: GameScene.canvasW, height: GameScene.canvasH)
        }
        .frame(width: GameScene.canvasW, height: GameScene.canvasH)
        .onReceive(NotificationCenter.default.publisher(for: .toggleDebugPanel)) { _ in
            showDebugPanel.toggle()
        }
        .sheet(isPresented: $showDebugPanel) {
            DebugPanelView()
        }
    }
}