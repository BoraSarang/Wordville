// GameScene — SpriteKit 게임 루프 (DESIGN.md 1.2 상태 머신)
// BOOT → TITLE → SCENE(지문) → QUESTION → RESULT_CORRECT/WRONG → SCENE / EPISODE_CLEAR
// 팔레트 (DESIGN.md 1.4): 크림 #FFF6E9 / 연두 #A8D672 / 복숭아 #FFB48A / 하늘 #8EC9F5 / 갈색 #5B4636
import SpriteKit

enum GameState {
    case title, scene, question, resultCorrect, resultWrong, clear
}

final class GameScene: SKScene {
    static let canvasW: CGFloat = 360
    static let canvasH: CGFloat = 780

    private var state: GameState = .title
    private var sceneIndex = 0
    private var questions: [Question] = []
    private var correctCount = 0
    private var totalExp = 0
    private var combo = 0
    private var episodeTitle = ""

    // 노드
    private var dialogLabel: SKLabelNode!
    private var dialogBox: SKShapeNode!
    private var characterNode: SKNode!
    private var questionLayer: SKNode!
    private var choiceButtons: [SKShapeNode] = []
    private var progressLabel: SKLabelNode!

    // 타이핑
    private var fullText = ""
    private var typedCount = 0
    private var typing = false
    private var currentQuestion: Question?

    private let palette = (
        cream: SKColor(hex: 0xFFF6E9),
        green: SKColor(hex: 0xA8D672),
        peach: SKColor(hex: 0xFFB48A),
        sky: SKColor(hex: 0x8EC9F5),
        brown: SKColor(hex: 0x5B4636)
    )

    override func didMove(to view: SKView) {
        backgroundColor = palette.cream
        size = CGSize(width: Self.canvasW, height: Self.canvasH)
        questions = GameData.demoQuestions
        episodeTitle = GameData.demoEpisode.title
        buildBackground()
        showTitle()
        DebugLogger.shared.feature("게임", "씬 로드 — title", meta: ["questions": questions.count])
        Task { await loadRemoteEpisode() }
    }

    // MARK: - 서버 연동

    private func loadRemoteEpisode() async {
        do {
            _ = try await APIClient.shared.ensureAuth()
            let episode = try await APIClient.shared.fetchTodayEpisode()
            let remoteQuestions = try await APIClient.shared.fetchQuestions(episodeId: episode.id)
            await MainActor.run {
                questions = remoteQuestions
                episodeTitle = episode.title
                correctCount = 0
                totalExp = 0
                combo = 0
                DebugLogger.shared.feature("게임", "서버 에피소드 로드됨", meta: ["title": episode.title, "questions": remoteQuestions.count])
                if state == .title {
                    clearLayers()
                    showTitle()
                }
            }
        } catch {
            DebugLogger.shared.log(.warn, "게임", "서버 로드 실패 — 데모 데이터 사용", meta: ["error": String(describing: error)])
        }
    }

    // MARK: - 배경

    private func buildBackground() {
        let floor = SKSpriteNode(color: palette.green, size: CGSize(width: Self.canvasW, height: 120))
        floor.position = CGPoint(x: Self.canvasW / 2, y: 0)
        floor.zPosition = -2
        addChild(floor)

        let wall = SKSpriteNode(color: palette.cream, size: CGSize(width: Self.canvasW, height: 780))
        wall.position = CGPoint(x: Self.canvasW / 2, y: 660)
        wall.zPosition = -3
        addChild(wall)
    }

    // MARK: - 공통 노드

    private func makeButton(width: CGFloat, height: CGFloat, color: SKColor, name: String) -> SKShapeNode {
        let rect = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 8)
        rect.fillColor = color
        rect.strokeColor = palette.brown
        rect.lineWidth = 3
        rect.name = name
        return rect
    }

    private func makeLabel(_ text: String, size: CGFloat, color: SKColor = .black) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = "AppleSDGothicNeo-Bold"
        label.fontSize = size
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = 320
        label.lineBreakMode = .byWordWrapping
        return label
    }

    private func clearLayers() {
        removeAllChildren()
        buildBackground()
        characterNode = nil
        questionLayer = nil
        choiceButtons.removeAll()
    }

    // MARK: - TITLE

    private func showTitle() {
        state = .title
        clearLayers()
        let title = makeLabel("글마을 달인", size: 34, color: palette.brown)
        title.position = CGPoint(x: Self.canvasW / 2, y: 620)
        addChild(title)

        let sub = makeLabel("오늘의 에피소드: \(episodeTitle)", size: 16, color: palette.brown)
        sub.position = CGPoint(x: Self.canvasW / 2, y: 560)
        addChild(sub)

        let start = makeButton(width: 220, height: 64, color: palette.green, name: "start")
        start.position = CGPoint(x: Self.canvasW / 2, y: 440)
        addChild(start)
        let startLabel = makeLabel("에피소드 시작", size: 22, color: .white)
        startLabel.position = start.position
        addChild(startLabel)
    }

    private func makeCancelButton() {
        let cancel = makeButton(width: 34, height: 34, color: SKColor.white.withAlphaComponent(0.85), name: "cancel")
        cancel.position = CGPoint(x: 28, y: 750)
        addChild(cancel)
        let cancelLabel = SKLabelNode(text: "✕")
        cancelLabel.fontName = "AppleSDGothicNeo-Bold"
        cancelLabel.fontSize = 16
        cancelLabel.fontColor = palette.brown
        cancelLabel.verticalAlignmentMode = .center
        cancelLabel.position = cancel.position
        addChild(cancelLabel)
    }

    // MARK: - SCENE (지문 타이핑)

    private func showScene(_ index: Int) {
        state = .scene
        DebugLogger.shared.feature("게임", "scene 진입", meta: ["index": index, "total": questions.count])
        sceneIndex = index
        let question = questions[index]
        clearLayers()

        // 캐릭터 (복숭아 픽셀풍, 화면 중앙 — 크게)
        characterNode = makeCharacter()
        characterNode.setScale(1.4)
        characterNode.position = CGPoint(x: Self.canvasW / 2, y: 470)
        addChild(characterNode)

        // 고민 연출
        let think = makeLabel("🤔", size: 34, color: .black)
        think.position = CGPoint(x: Self.canvasW / 2 + 40, y: 560)
        addChild(think)

        // 읽기 안내
        let hint = makeLabel("지문을 잘 읽어보세요!", size: 15, color: palette.brown)
        hint.position = CGPoint(x: Self.canvasW / 2, y: 350)
        addChild(hint)

        // 대화창
        dialogBox = SKShapeNode(rectOf: CGSize(width: 320, height: 140), cornerRadius: 12)
        dialogBox.fillColor = .white
        dialogBox.strokeColor = palette.brown
        dialogBox.lineWidth = 3
        dialogBox.position = CGPoint(x: Self.canvasW / 2, y: 220)
        addChild(dialogBox)

        dialogLabel = makeLabel("", size: 17, color: .black)
        dialogLabel.position = CGPoint(x: Self.canvasW / 2, y: 230)
        addChild(dialogLabel)

        progressLabel = makeLabel("\(index + 1) / \(questions.count)", size: 14, color: palette.brown)
        progressLabel.position = CGPoint(x: Self.canvasW / 2, y: 745)
        addChild(progressLabel)
        makeCancelButton()

        // 다음 버튼
        let next = makeButton(width: 120, height: 48, color: palette.sky, name: "next")
        next.position = CGPoint(x: Self.canvasW / 2, y: 80)
        addChild(next)
        let nextLabel = makeLabel("▸ 다음", size: 18, color: .white)
        nextLabel.position = next.position
        addChild(nextLabel)

        startTyping(question.narrative)
    }

    private func makeCharacter() -> SKNode {
        let node = SKNode()
        let body = SKSpriteNode(color: palette.peach, size: CGSize(width: 72, height: 90))
        body.position = CGPoint(x: 0, y: 0)
        node.addChild(body)
        let eye = SKSpriteNode(color: .black, size: CGSize(width: 8, height: 8))
        eye.position = CGPoint(x: 12, y: 22)
        node.addChild(eye)
        let mouth = SKSpriteNode(color: .black, size: CGSize(width: 16, height: 4))
        mouth.position = CGPoint(x: 12, y: 8)
        node.addChild(mouth)
        return node
    }

    private func startTyping(_ text: String) {
        fullText = text
        typedCount = 0
        typing = true
        dialogLabel.text = ""
    }

    private func updateTyping() {
        guard typing else { return }
        typedCount += 1
        dialogLabel.text = String(fullText.prefix(typedCount))
        if typedCount >= fullText.count {
            typing = false
        }
    }

    // MARK: - QUESTION

    private func showQuestion() {
        state = .question
        DebugLogger.shared.feature("게임", "question 진입", meta: ["scene": sceneIndex])
        guard let question = questions[safe: sceneIndex] else { return }
        currentQuestion = question
        clearLayers()

        progressLabel = makeLabel("문제 \(sceneIndex + 1) / \(questions.count)", size: 14, color: palette.brown)
        progressLabel.position = CGPoint(x: Self.canvasW / 2, y: 745)
        addChild(progressLabel)
        makeCancelButton()

        // 문제 배너
        let banner = makeButton(width: 200, height: 40, color: palette.brown, name: "")
        banner.position = CGPoint(x: Self.canvasW / 2, y: 700)
        addChild(banner)
        let bannerLabel = makeLabel("문제 출제!", size: 18, color: .white)
        bannerLabel.position = banner.position
        addChild(bannerLabel)

        // 지문 박스
        let textBox = SKShapeNode(rectOf: CGSize(width: 330, height: 190), cornerRadius: 10)
        textBox.fillColor = .white
        textBox.strokeColor = palette.brown
        textBox.lineWidth = 3
        textBox.position = CGPoint(x: Self.canvasW / 2, y: 520)
        addChild(textBox)

        let textLabel = makeLabel(question.narrative, size: 16, color: .black)
        textLabel.position = CGPoint(x: Self.canvasW / 2, y: 530)
        addChild(textLabel)

        // 선택지 4개 (A~D)
        choiceButtons.removeAll()
        for (i, choice) in question.choices.enumerated() {
            let y = 384 - CGFloat(i) * 72
            let btn = makeButton(width: 310, height: 62, color: palette.cream, name: "choice_\(i)")
            btn.position = CGPoint(x: Self.canvasW / 2, y: y)
            addChild(btn)
            choiceButtons.append(btn)

            let prefix = SKLabelNode(text: ["A", "B", "C", "D"][i])
            prefix.fontName = "AppleSDGothicNeo-Bold"
            prefix.fontSize = 20
            prefix.fontColor = palette.brown
            prefix.verticalAlignmentMode = .center
            prefix.position = CGPoint(x: Self.canvasW / 2 - 130, y: y)
            addChild(prefix)

            let choiceLabel = makeLabel(choice.text, size: 14, color: .black)
            choiceLabel.position = CGPoint(x: Self.canvasW / 2 + 10, y: y)
            choiceLabel.horizontalAlignmentMode = .center
            choiceLabel.preferredMaxLayoutWidth = 240
            addChild(choiceLabel)
        }

        // 캐릭터 (문제 화면 하단)
        let char = makeCharacter()
        char.position = CGPoint(x: Self.canvasW / 2, y: 90)
        addChild(char)
    }

    // MARK: - RESULT

    private func showResult(correct: Bool, explanation: String, expGained: Int) {
        state = correct ? .resultCorrect : .resultWrong
        DebugLogger.shared.feature("게임", correct ? "정답" : "오답", meta: ["exp": expGained, "scene": sceneIndex])
        clearLayers()

        let resultColor: SKColor = correct ? palette.green : SKColor(hex: 0xF28B82)
        makeCancelButton()

        let banner = makeButton(width: 260, height: 64, color: resultColor, name: "")
        banner.position = CGPoint(x: Self.canvasW / 2, y: 610)
        addChild(banner)
        let resultLabel = makeLabel(correct ? "정답! EXP +\(expGained)" : "오답… 다시 도전!", size: 20, color: .white)
        resultLabel.position = banner.position
        addChild(resultLabel)

        // 정답 선택지 텍스트
        if let question = currentQuestion, let correctChoice = question.choices.first(where: { $0.isCorrect }) {
            let ansLabel = makeLabel(correct ? "정답: \(correctChoice.text)" : "다시 풀어볼까요?", size: 16, color: palette.brown)
            ansLabel.position = CGPoint(x: Self.canvasW / 2, y: 520)
            addChild(ansLabel)
        }

        // 설명 박스
        let explBox = SKShapeNode(rectOf: CGSize(width: 330, height: 100), cornerRadius: 10)
        explBox.fillColor = .white
        explBox.strokeColor = palette.brown
        explBox.lineWidth = 3
        explBox.position = CGPoint(x: Self.canvasW / 2, y: 430)
        addChild(explBox)
        let explLabel = makeLabel(explanation, size: 14, color: .black)
        explLabel.position = CGPoint(x: Self.canvasW / 2, y: 435)
        addChild(explLabel)

        // 캐릭터 (기쁨/슬픔)
        let char = makeCharacter()
        char.position = CGPoint(x: Self.canvasW / 2, y: 170)
        addChild(char)
        let mood = makeLabel(correct ? "🎉" : "😢", size: 30, color: .black)
        mood.position = CGPoint(x: Self.canvasW / 2, y: 265)
        addChild(mood)

        let actionLabel = makeLabel(correct ? "다음 장면으로 →" : "같은 문제 다시 풀기", size: 18, color: palette.brown)
        let next = makeButton(width: 240, height: 56, color: palette.sky, name: correct ? "next_scene" : "retry")
        next.position = CGPoint(x: Self.canvasW / 2, y: 320)
        addChild(next)
        actionLabel.position = next.position
        addChild(actionLabel)
    }

    // MARK: - CLEAR

    private func showClear() {
        state = .clear
        DebugLogger.shared.feature("게임", "에피소드 클리어", meta: ["correct": correctCount, "exp": totalExp])
        clearLayers()

        let title = makeLabel("에피소드 클리어!", size: 30, color: palette.brown)
        title.position = CGPoint(x: Self.canvasW / 2, y: 600)
        addChild(title)

        let stats = makeLabel("\(correctCount)문제 정답 · EXP +\(totalExp)", size: 18, color: .black)
        stats.position = CGPoint(x: Self.canvasW / 2, y: 520)
        addChild(stats)

        let again = makeButton(width: 220, height: 56, color: palette.green, name: "restart")
        again.position = CGPoint(x: Self.canvasW / 2, y: 400)
        addChild(again)
        let againLabel = makeLabel("다시 시작", size: 18, color: .white)
        againLabel.position = again.position
        addChild(againLabel)
    }

    // MARK: - 입력

    override func mouseDown(with event: NSEvent) {
        let location = convertPoint(fromView: event.locationInWindow)
        let hitNodes = nodes(at: location)
        guard let node = hitNodes.first(where: { $0.name != nil }), let name = node.name else {
            DebugLogger.shared.log(.warn, "게임", "클릭 무시 (노드 없음)", meta: ["x": Int(location.x), "y": Int(location.y)])
            return
        }

        if name == "cancel" {
            DebugLogger.shared.feature("게임", "취소됨 (타이틀로 복귀)", meta: ["state": String(describing: state)])
            showTitle()
            return
        }

        switch state {
        case .title:
            if name == "start" {
                DebugLogger.shared.feature("게임", "에피소드 시작됨")
                showScene(0)
            }
        case .scene:
            if name == "next" {
                if typing {
                    typedCount = fullText.count
                    dialogLabel.text = fullText
                    typing = false
                } else {
                    showQuestion()
                }
            }
        case .question:
            if name.hasPrefix("choice_"), let idx = Int(name.dropFirst(7)), let q = currentQuestion {
                handleAnswer(idx, question: q)
            }
        case .resultCorrect:
            if name == "next_scene" {
                let nextIndex = sceneIndex + 1
                if nextIndex < questions.count {
                    showScene(nextIndex)
                } else {
                    showClear()
                }
            }
        case .resultWrong:
            if name == "retry" {
                showQuestion()
            }
        case .clear:
            if name == "restart" {
                correctCount = 0
                totalExp = 0
                combo = 0
                showTitle()
            }
        }
    }

    private func handleAnswer(_ index: Int, question: Question) {
        guard let choice = question.choices[safe: index] else { return }
        let explanation = question.explanation ?? question.narrative
        if choice.isCorrect {
            correctCount += 1
            combo += 1
            let exp = 10 + min((combo - 1) * 2, 10)
            totalExp += exp
            DebugLogger.shared.feature("게임", "콤보", meta: ["combo": combo, "exp": exp])
            showResult(correct: true, explanation: explanation, expGained: exp)
        } else {
            combo = 0
            showResult(correct: false, explanation: explanation, expGained: 0)
        }
        Task {
            do {
                _ = try await APIClient.shared.submitAnswer(
                    questionId: question.id,
                    selected: choice.text,
                    combo: max(combo, 1)
                )
            } catch {
                DebugLogger.shared.log(.warn, "게임", "답안 제출 실패 — 오프라인 큐", meta: ["error": String(describing: error)])
                APIClient.shared.enqueueAnswer(questionId: question.id, selected: choice.text, combo: max(combo, 1))
            }
        }
    }

    // MARK: - 루프

    override func update(_ currentTime: TimeInterval) {
        if state == .scene && typing {
            updateTyping()
        }
    }
}

extension SKColor {
    convenience init(hex: Int) {
        let r = (hex >> 16) & 0xFF
        let g = (hex >> 8) & 0xFF
        let b = hex & 0xFF
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}