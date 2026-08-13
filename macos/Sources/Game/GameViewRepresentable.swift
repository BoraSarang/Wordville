// GameViewRepresentable — SwiftUI에서 SKView 임베딩
import SwiftUI

struct GameViewRepresentable: NSViewControllerRepresentable {
    func makeNSViewController(context: Context) -> GameViewController {
        GameViewController()
    }

    func updateNSViewController(_ nsViewController: GameViewController, context: Context) {}
}