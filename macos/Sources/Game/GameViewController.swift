// GameViewController — SKView 컨테이너 (360×780 고정 캔버스)
import AppKit
import SpriteKit

final class GameViewController: NSViewController {
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: GameScene.canvasW, height: GameScene.canvasH))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        DebugLogger.shared.feature("게임", "GameViewController 표시됨")

        let skView = SKView(frame: view.bounds)
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false
        view.addSubview(skView)

        let scene = GameScene(size: CGSize(width: GameScene.canvasW, height: GameScene.canvasH))
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
    }
}