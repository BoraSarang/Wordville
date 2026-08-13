// GameRootView — 게임 윈도우 루트 (순수 게임 화면)
import SwiftUI

struct GameRootView: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        ZStack {
            GameViewRepresentable()
                .frame(width: GameScene.canvasW, height: GameScene.canvasH)
        }
        .frame(width: GameScene.canvasW, height: GameScene.canvasH)
    }
}