// WordvilleGame — libGDX 게임 루프 (macOS GameScene.swift 1:1 이식)
// SPLASH → SELECTION → ARCHIVE / RANKING / SCENE(지문) → QUESTION → RESULT_CORRECT/WRONG → SCENE / CLEAR
// 캔버스 360x780, 카메라 y-up (SpriteKit 좌표계 동일)
package com.borasarang.wordville

import com.badlogic.gdx.Game
import com.badlogic.gdx.Gdx
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.OrthographicCamera
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.graphics.g2d.BitmapFont
import com.badlogic.gdx.graphics.g2d.GlyphLayout
import com.badlogic.gdx.graphics.g2d.SpriteBatch
import com.badlogic.gdx.graphics.g2d.freetype.FreeTypeFontGenerator
import com.badlogic.gdx.graphics.glutils.ShapeRenderer
import com.badlogic.gdx.math.MathUtils
import com.badlogic.gdx.math.Vector2
import com.badlogic.gdx.utils.viewport.FitViewport

enum class GameState { SPLASH, SELECTION, ARCHIVE, RANKING, SCENE, QUESTION, RESULT_CORRECT, RESULT_WRONG, CLEAR }

class WordvilleGame : Game(), com.badlogic.gdx.InputProcessor {
    companion object {
        const val CANVAS_W = 360f
        const val CANVAS_H = 780f
        const val SERVER_URL = "http://10.0.2.2:3000"
    }

    // 상태
    var state = GameState.SPLASH
    private var sceneIndex = 0
    private var questions: List<Question> = emptyList()
    private var correctCount = 0
    private var totalExp = 0
    private var combo = 0
    private var episodeTitle = ""
    private var quickPlay = false

    // 아카이브 / 랭킹
    private var archiveList: List<EpisodeSummary> = emptyList()
    private var archivePage = 0
    private var rankingData: WeeklyRanking? = null
    private var archiveError = false
    private val archivePageSize = 6

    // 렌더
    private lateinit var viewport: FitViewport
    private lateinit var camera: OrthographicCamera
    private lateinit var batch: SpriteBatch
    private lateinit var shape: ShapeRenderer
    private lateinit var white: Texture
    private lateinit var store: SettingsStore

    // 타이핑
    private var fullText = ""
    private var typedCount = 0
    private var typing = false
    private var currentQuestion: Question? = null

    // 위젯 (macOS addChild 순서 = 추가 순서)
    private data class Box(val name: String, val x: Float, val y: Float, val w: Float, val h: Float, val fill: Color, val z: Float = 0f)
    private data class Label(val name: String, val text: String, val size: Int, val font: FontKind, val color: Color, val x: Float, val y: Float, val maxW: Float = 0f, val z: Float = 0f)

    private val boxes = mutableListOf<Box>()
    private val labels = mutableListOf<Label>()

    private enum class FontKind(val file: String) { UI("fonts/Galmuri11-Bold.ttf"), BODY("fonts/NeoDunggeunmo.ttf") }
    private val fontCache = HashMap<Pair<FontKind, Int>, BitmapFont>()
    private val layout = GlyphLayout()

    override fun create() {
        store = SettingsStoreHolder.store
        camera = OrthographicCamera()
        camera.setToOrtho(false, CANVAS_W, CANVAS_H)
        viewport = FitViewport(CANVAS_W, CANVAS_H, camera)
        batch = SpriteBatch()
        shape = ShapeRenderer()
        white = Texture(com.badlogic.gdx.graphics.Pixmap(1, 1, com.badlogic.gdx.graphics.Pixmap.Format.RGBA8888).apply {
            setColor(Color.WHITE); fill()
        })
        Gdx.input.setCatchKey(com.badlogic.gdx.Input.Keys.BACK, true)
        Gdx.input.setInputProcessor(this)

        DebugLogger.feature("게임", "씬 로드 — splash")
        showSplash()
        Thread {
            try {
                ApiClient.ensureAuth()
                ApiClient.flushQueue()
            } catch (e: Exception) {
                DebugLogger.log("warn", "게임", "프로필 로드 실패", mapOf("error" to (e.message ?: "")))
            }
            Gdx.app.postRunnable {
                if (state == GameState.SPLASH) showSelection()
            }
        }.start()
    }

    // MARK: - 공통

    private fun font(kind: FontKind, size: Int): BitmapFont {
        return fontCache.getOrPut(kind to size) {
            val gen = FreeTypeFontGenerator(Gdx.files.internal(kind.file))
            val param = FreeTypeFontGenerator.FreeTypeFontParameter().apply {
                this.size = size
                color = Color.WHITE
                // 한글 전체(U+AC00~U+D7A3) + 특수기호 — DEFAULT_CHARS는 ASCII+라틴뿐이라 필수
                val symbols = "·★☆✓▲▼▸…X?!…—·’‘“”[]()"
                val korean = StringBuilder()
                for (c in 0xAC00..0xD7A3) korean.append(c.toChar())
                characters = FreeTypeFontGenerator.DEFAULT_CHARS + korean.toString() + symbols
            }
            gen.generateFont(param).apply { gen.dispose() }
        }
    }

    private fun clearWidgets() {
        boxes.clear()
        labels.clear()
    }

    private fun box(name: String, x: Float, y: Float, w: Float, h: Float, fill: Color, z: Float = 0f) {
        boxes.add(Box(name, x, y, w, h, fill, z))
    }

    private fun label(name: String, text: String, size: Int, font: FontKind, color: Color, x: Float, y: Float, maxW: Float = 0f, z: Float = 0f) {
        labels.add(Label(name, text, size, font, color, x, y, maxW, z))
    }

    // macOS makeLabel 기본: size, color=black, font=UI
    private fun lbl(text: String, size: Int, color: Color = Color.BLACK, font: FontKind = FontKind.UI, x: Float = CANVAS_W / 2, y: Float = 0f, maxW: Float = 0f, z: Float = 0f): Label {
        return Label("", text, size, font, color, x, y, maxW, z)
    }

    // 배경 (floor + wall)
    private fun buildBackground() {
        box("", CANVAS_W / 2, 0f, CANVAS_W, 120f, Palette.green, z = -10f)
        box("", CANVAS_W / 2, 660f, CANVAS_W, 780f, Palette.cream, z = -11f)
    }

    private fun makeButton(name: String, x: Float, y: Float, w: Float, h: Float, color: Color, z: Float = 0f) {
        box(name, x, y, w, h, color, z)
    }

    private fun makeMenuButton(name: String, color: Color, title: String, subtitle: String, y: Float) {
        makeButton(name, CANVAS_W / 2, y, 280f, 62f, color)
        label("", title, 19, FontKind.UI, Color.WHITE, CANVAS_W / 2, y + 10)
        label("", subtitle, 11, FontKind.BODY, Color(1f, 1f, 1f, 0.9f), CANVAS_W / 2, y - 14)
    }

    private fun makeCancelButton() {
        makeButton("cancel", 28f, 750f, 34f, 34f, Color(1f, 1f, 1f, 0.85f))
        label("", "X", 16, FontKind.UI, Palette.brown, 28f, 750f)
    }

    // MARK: - SPLASH

    private fun showSplash() {
        state = GameState.SPLASH
        clearWidgets()
        buildBackground()
        box("", CANVAS_W / 2, 500f, 64f, 64f, Palette.brown) // 📖 → 책 사각형
        label("", "글", 32, FontKind.UI, Palette.cream, CANVAS_W / 2, 500f)
        label("", "글마을 달인", 36, FontKind.UI, Palette.brown, CANVAS_W / 2, 400f)
        label("", "매일 오는 맞춤법 여행", 16, FontKind.BODY, Palette.brown, CANVAS_W / 2, 350f)
        label("", "불러오는 중…", 13, FontKind.BODY, Color(0.357f, 0.275f, 0.212f, 0.6f), CANVAS_W / 2, 280f)
        DebugLogger.feature("게임", "스플래시 표시됨")
    }

    // MARK: - SELECTION

    private fun showSelection() {
        state = GameState.SELECTION
        clearWidgets()
        buildBackground()
        label("", "글마을 달인", 30, FontKind.UI, Palette.brown, CANVAS_W / 2, 660f)
        val badgeText = "Lv.${store.level} · ★${store.streakDays}일 연속 · EXP ${store.exp}" + (if (store.goldenPass) " · ★골든패스" else "")
        label("", badgeText, 14, FontKind.BODY, Palette.brown, CANVAS_W / 2, 610f)
        makeMenuButton("episode_today", Palette.green, "오늘의 에피소드", "오늘의 스토리 5문제 · EXP + 스트릭", 540f)
        makeMenuButton("quickplay", Palette.sky, "퀵플레이", "1문제 · 틀린 유형 우선 출제", 450f)
        makeMenuButton("archive", Palette.peach, "과거 에피소드", "지난 스토리 다시 보기", 360f)
        makeMenuButton("review", Palette.tan, "오답 복습", "몬스터 사냥 · 틀린 유형만", 270f)
        makeMenuButton("ranking", Palette.gold, "주간 랭킹", "리그 순위 확인", 180f)
        DebugLogger.feature("게임", "선택 화면 표시됨")
        val probe = GlyphLayout(font(FontKind.BODY, 16), "가나다")
        DebugLogger.log("INFO", "폰트", "한글 glyph width=" + probe.width + " pages=" + font(FontKind.BODY, 16).regions.size)
    }

    // MARK: - RANKING

    private fun loadRanking(onDone: () -> Unit) {
        DebugLogger.feature("게임", "랭킹 로드 시작")
        Thread {
            try {
                ApiClient.ensureAuth()
                val data = ApiClient.fetchWeeklyRanking()
                Gdx.app.postRunnable {
                    rankingData = data
                    showRanking()
                    onDone()
                }
            } catch (e: Exception) {
                DebugLogger.log("warn", "게임", "랭킹 로드 실패", mapOf("error" to (e.message ?: "")))
                Gdx.app.postRunnable {
                    state = GameState.RANKING
                    clearWidgets()
                    buildBackground()
                    makeCancelButton()
                    label("", "랭킹을 불러오지 못했어요", 18, FontKind.UI, Palette.brown, CANVAS_W / 2, 460f)
                    label("", "네트워크 연결을 확인해 주세요", 13, FontKind.BODY, Color(0.357f, 0.275f, 0.212f, 0.7f), CANVAS_W / 2, 420f)
                    makeMenuButton("rank_retry", Palette.peach, "다시 시도", "", 330f)
                    onDone()
                }
            }
        }.start()
    }

    private fun showRanking() {
        state = GameState.RANKING
        clearWidgets()
        buildBackground()
        makeCancelButton()
        label("", "주간 랭킹", 26, FontKind.UI, Palette.brown, CANVAS_W / 2, 700f)

        val data = rankingData ?: return
        if (data.my_rank != null) {
            makeButton("rank_self", CANVAS_W / 2, 630f, 300f, 46f, Palette.sky)
            label("", "내 순위 ${data.my_rank}위 · ${store.profile?.nickname ?: store.nickname}", 15, FontKind.UI, Color.WHITE, CANVAS_W / 2, 630f)
        }

        val top = data.rankings.take(10)
        top.forEachIndexed { index, entry ->
            val rowY = 575f - index * 42f
            makeButton("rank_row_$index", CANVAS_W / 2, rowY, 300f, 36f, Color(1f, 1f, 1f, 0.6f))
            val rankColor = if (index < 3) Palette.orange else Palette.brown
            label("", "${index + 1}", 15, FontKind.UI, rankColor, 62f, rowY)
            label("", entry.nickname, 13, FontKind.BODY, Palette.brown, 92f, rowY, maxW = 130f)
            label("", "${entry.score ?: 0}점", 12, FontKind.BODY, Palette.brown, 298f, rowY)
        }
        DebugLogger.feature("게임", "랭킹 화면 표시됨", mapOf("myRank" to (data.my_rank ?: -1), "rows" to top.size))
    }

    // MARK: - ARCHIVE

    private fun loadArchive(onDone: () -> Unit) {
        Thread {
            try {
                ApiClient.ensureAuth()
                val list = ApiClient.fetchEpisodeList()
                Gdx.app.postRunnable {
                    archiveList = list
                    archiveError = false
                    archivePage = 0
                    showArchive()
                    onDone()
                }
            } catch (e: Exception) {
                DebugLogger.log("warn", "게임", "아카이브 로드 실패", mapOf("error" to (e.message ?: "")))
                Gdx.app.postRunnable {
                    archiveError = true
                    showArchive()
                    onDone()
                }
            }
        }.start()
    }

    private fun showArchive() {
        state = GameState.ARCHIVE
        clearWidgets()
        buildBackground()
        makeCancelButton()
        label("", "과거 에피소드", 22, FontKind.UI, Palette.brown, CANVAS_W / 2, 700f)

        if (archiveList.isEmpty()) {
            label("", if (archiveError) "불러오지 못했습니다. 다시 시도해 주세요." else "불러오는 중…", 15, FontKind.BODY, Palette.brown, CANVAS_W / 2, 420f)
            if (archiveError) {
                makeButton("archive_retry", CANVAS_W / 2, 360f, 160f, 44f, Palette.sky)
                label("", "다시 시도", 16, FontKind.UI, Color.WHITE, CANVAS_W / 2, 360f)
            }
            return
        }

        val totalPages = MathUtils.ceil(archiveList.size.toFloat() / archivePageSize)
        label("", "${archivePage + 1} / $totalPages", 13, FontKind.BODY, Palette.brown, CANVAS_W / 2, 655f)

        val startIdx = archivePage * archivePageSize
        val pageItems = archiveList.subList(startIdx, minOf(startIdx + archivePageSize, archiveList.size))
        pageItems.forEachIndexed { i, ep ->
            val y = 580f - i * 78f
            makeButton("ep_${ep.id}", CANVAS_W / 2, y, 300f, 62f, if (ep.played) Palette.archiveDone else Color.WHITE)
            label("", shortDate(ep.episode_date), 13, FontKind.BODY, Palette.brown, CANVAS_W / 2 - 130f, y + 14f)
            label("", ep.title, 13, FontKind.BODY, Palette.brown, CANVAS_W / 2 - 130f, y - 10f, maxW = 200f)
            if (ep.played) {
                label("", "✓", 16, FontKind.UI, Palette.brown, CANVAS_W / 2 + 130f, y)
            }
        }

        if (archivePage > 0) {
            makeButton("archive_up", CANVAS_W / 2 - 60f, 80f, 44f, 44f, Palette.sky)
            label("", "▲", 16, FontKind.UI, Color.WHITE, CANVAS_W / 2 - 60f, 80f)
        }
        if (archivePage < totalPages - 1) {
            makeButton("archive_down", CANVAS_W / 2 + 60f, 80f, 44f, 44f, Palette.sky)
            label("", "▼", 16, FontKind.UI, Color.WHITE, CANVAS_W / 2 + 60f, 80f)
        }
        DebugLogger.feature("게임", "아카이브 표시됨", mapOf("page" to archivePage, "total" to archiveList.size))
    }

    private fun shortDate(iso: String): String {
        val parts = iso.split("-")
        return if (parts.size == 3) "${parts[1].toInt()}/${parts[2].toInt()}" else iso
    }

    private fun openEpisode(id: Int, onDone: () -> Unit) {
        DebugLogger.feature("게임", "아카이브 에피소드 선택", mapOf("episodeId" to id))
        Thread {
            try {
                ApiClient.ensureAuth()
                val qs = ApiClient.fetchQuestions(id)
                val title = archiveList.firstOrNull { it.id == id }?.title ?: "과거 에피소드"
                Gdx.app.postRunnable {
                    startEpisode(qs, title)
                    onDone()
                }
            } catch (e: Exception) {
                DebugLogger.log("warn", "게임", "에피소드 문제 로드 실패", mapOf("error" to (e.message ?: "")))
                Gdx.app.postRunnable { onDone() }
            }
        }.start()
    }

    // MARK: - 에피소드 공통

    private fun startEpisode(qs: List<Question>, title: String) {
        if (qs.isEmpty()) return
        questions = qs
        episodeTitle = title
        quickPlay = false
        sceneIndex = 0
        correctCount = 0
        totalExp = 0
        combo = 0
        DebugLogger.feature("게임", "에피소드 시작", mapOf("title" to title, "questions" to qs.size))
        showScene(0)
    }

    private fun startQuickPlay(q: QuickQuestion) {
        quickPlay = true
        questions = listOf(Question(id = q.id, scene_index = 0, narrative = q.narrative, choices = q.choices, explanation = q.explanation))
        sceneIndex = 0
        correctCount = 0
        totalExp = 0
        combo = 0
        DebugLogger.feature("게임", "퀵플레이 시작", mapOf("qid" to q.id))
        showQuestion()
    }

    private fun startTodayEpisode() {
        DebugLogger.feature("게임", "오늘의 에피소드 선택됨")
        Thread {
            try {
                ApiClient.ensureAuth()
                val episode = ApiClient.fetchTodayEpisode()
                val qs = ApiClient.fetchQuestions(episode.id)
                Gdx.app.postRunnable { startEpisode(qs, episode.title) }
            } catch (e: Exception) {
                DebugLogger.log("warn", "게임", "오늘 에피소드 로드 실패 — 선택 화면 복귀", mapOf("error" to (e.message ?: "")))
                Gdx.app.postRunnable { showSelection() }
            }
        }.start()
    }

    private fun loadReview() {
        DebugLogger.feature("게임", "오답 복습 선택됨")
        Thread {
            try {
                ApiClient.ensureAuth()
                val review = ApiClient.fetchReviewQuestions()
                Gdx.app.postRunnable { startEpisode(review.questions, review.title) }
            } catch (e: Exception) {
                DebugLogger.log("warn", "게임", "복습 로드 실패", mapOf("error" to (e.message ?: "")))
                Gdx.app.postRunnable { showSelection() }
            }
        }.start()
    }

    private fun handleQuickPlay() {
        Thread {
            try {
                ApiClient.ensureAuth()
                val q = ApiClient.fetchQuickQuestion()
                Gdx.app.postRunnable { startQuickPlay(q) }
            } catch (e: Exception) {
                DebugLogger.log("warn", "게임", "퀵플레이 문제 로드 실패", mapOf("error" to (e.message ?: "")))
                Gdx.app.postRunnable { showSelection() }
            }
        }.start()
    }

    // MARK: - SCENE (지문 타이핑)

    private fun showScene(index: Int) {
        state = GameState.SCENE
        sceneIndex = index
        val question = questions[index]
        clearWidgets()
        buildBackground()
        DebugLogger.feature("게임", "scene 진입", mapOf("index" to index, "total" to questions.size))

        // 캐릭터 (코드 도형 — macOS 폴백과 동일)
        makeCharacter(CANVAS_W / 2, 470f, 1.4f)
        label("", "?", 34, FontKind.BODY, Palette.brown, CANVAS_W / 2 + 40f, 560f) // 🤔
        label("", "지문을 잘 읽어보세요!", 15, FontKind.BODY, Palette.brown, CANVAS_W / 2, 350f)

        box("", CANVAS_W / 2, 220f, 320f, 150f, Color.WHITE) // 대화창
        box("", CANVAS_W / 2, 220f, 320f, 150f, Color(0f, 0f, 0f, 0f), z = -0.5f) // 자리만
        label("", "지문", 17, FontKind.BODY, Color.BLACK, CANVAS_W / 2, 225f, maxW = 300f) // 타이핑 시 교체
        label("", "${index + 1} / ${questions.size}", 14, FontKind.UI, Palette.brown, CANVAS_W / 2, 745f)
        makeCancelButton()

        makeButton("next", CANVAS_W / 2, 80f, 120f, 48f, Palette.sky)
        label("", "▸ 다음", 18, FontKind.UI, Color.WHITE, CANVAS_W / 2, 80f)

        startTyping(question.narrative)
    }

    private fun makeCharacter(x: Float, y: Float, scale: Float) {
        val w = 72f * scale; val h = 90f * scale
        box("", x, y, w, h, Palette.peach)                       // 몸통
        box("", x + 12f * scale, y + 22f * scale, 8f * scale, 8f * scale, Color.BLACK)  // 눈
        box("", x + 12f * scale, y + 8f * scale, 16f * scale, 4f * scale, Color.BLACK)  // 입
    }

    private fun makeMonster(x: Float, y: Float, scale: Float = 0.4f) {
        val w = 84f * scale; val h = 80f * scale
        box("", x, y, w, h, Palette.monster)
        box("", x - 14f * scale, y + 20f * scale, 18f * scale, 18f * scale, Color.WHITE)   // 눈
        box("", x + 14f * scale, y + 20f * scale, 18f * scale, 18f * scale, Color.WHITE)
        box("", x - 14f * scale, y + 20f * scale, 8f * scale, 8f * scale, Palette.pupil)   // 동공
        box("", x + 14f * scale, y + 20f * scale, 8f * scale, 8f * scale, Palette.pupil)
        box("", x - 8f * scale, y - 28f * scale, 8f * scale, 12f * scale, Color.WHITE)     // 송곳니
        box("", x + 8f * scale, y - 28f * scale, 8f * scale, 12f * scale, Color.WHITE)
    }

    private fun startTyping(text: String) {
        fullText = text
        typedCount = 0
        typing = true
        updateDialogText()
    }

    private fun updateDialogText() {
        val shown = fullText.take(typedCount)
        labels.filter { it.text == "지문" }.forEach { }
        labels.removeAll { it.name == "dialog" }
        label("dialog", shown, 17, FontKind.BODY, Color.BLACK, CANVAS_W / 2, 225f, maxW = 300f)
    }

    // MARK: - QUESTION

    private fun showQuestion() {
        state = GameState.QUESTION
        DebugLogger.feature("게임", "question 진입", mapOf("scene" to sceneIndex))
        val question = questions.getOrNull(sceneIndex) ?: return
        currentQuestion = question
        clearWidgets()
        buildBackground()

        label("", "문제 ${sceneIndex + 1} / ${questions.size}", 14, FontKind.UI, Palette.brown, CANVAS_W / 2, 745f)
        makeCancelButton()

        makeButton("", CANVAS_W / 2, 700f, 200f, 40f, Palette.brown) // 문제 배너
        label("", "문제 출제!", 18, FontKind.UI, Color.WHITE, CANVAS_W / 2, 700f)

        box("", CANVAS_W / 2, 535f, 330f, 180f, Color.WHITE) // 지문 박스
        label("", question.narrative, 16, FontKind.BODY, Color.BLACK, CANVAS_W / 2, 535f, maxW = 300f)

        question.choices.forEachIndexed { i, choice ->
            val y = 388f - i * 76f
            makeButton("choice_$i", CANVAS_W / 2, y, 310f, 62f, Palette.cream)
            label("", listOf("A", "B", "C", "D")[i], 20, FontKind.UI, Palette.brown, CANVAS_W / 2 - 130f, y)
            label("", choice.text, 14, FontKind.BODY, Color.BLACK, CANVAS_W / 2 + 10f, y, maxW = 240f)
        }

        makeCharacter(CANVAS_W / 2, 85f, 0.7f) // 캐릭터 (문제 화면 하단)
    }

    // MARK: - RESULT

    private fun showResult(correct: Boolean, explanation: String, expGained: Int) {
        state = if (correct) GameState.RESULT_CORRECT else GameState.RESULT_WRONG
        DebugLogger.feature("게임", if (correct) "정답" else "오답", mapOf("exp" to expGained, "scene" to sceneIndex))
        clearWidgets()
        buildBackground()
        val resultColor = if (correct) Palette.green else Palette.red
        makeCancelButton()

        makeButton("", CANVAS_W / 2, 610f, 260f, 64f, resultColor)
        label("", if (correct) "정답! EXP +$expGained" else "오답… 다시 도전!", 20, FontKind.UI, Color.WHITE, CANVAS_W / 2, 610f)

        currentQuestion?.let { q ->
            val correctChoice = q.choices.firstOrNull { it.isCorrect }
            if (correctChoice != null) {
                label("", if (correct) "정답: ${correctChoice.text}" else "다시 풀어볼까요?", 16, FontKind.BODY, Palette.brown, CANVAS_W / 2, 520f, maxW = 310f)
            }
        }

        box("", CANVAS_W / 2, 430f, 330f, 100f, Color.WHITE) // 설명 박스
        label("", explanation, 14, FontKind.BODY, Color.BLACK, CANVAS_W / 2, 435f, maxW = 300f)

        makeCharacter(CANVAS_W / 2, 170f, 1f)
        label("", if (correct) "★" else "☆", 30, FontKind.BODY, Palette.brown, CANVAS_W / 2, 265f)

        if (correct) {
            spawnExpPopup(expGained)
        } else {
            makeMonster(CANVAS_W / 2 + 60f, 170f, 0.4f)
        }

        val actionText = if (correct) "다음 장면으로 →" else "같은 문제 다시 풀기"
        makeButton(if (correct) "next_scene" else "retry", CANVAS_W / 2, 320f, 240f, 56f, Palette.sky)
        label("", actionText, 18, FontKind.BODY, Palette.brown, CANVAS_W / 2, 320f)
    }

    private fun spawnExpPopup(exp: Int) {
        label("", "+$exp EXP", 22, FontKind.UI, Palette.green, CANVAS_W / 2, 270f, z = 50f)
    }

    private fun spawnComboBanner(comboNum: Int) {
        label("", "${comboNum}콤보! 보너스 +10 EXP", 20, FontKind.UI, Palette.orange, CANVAS_W / 2, 330f, z = 51f)
    }

    // MARK: - CLEAR

    private fun showClear() {
        state = GameState.CLEAR
        DebugLogger.feature("게임", "에피소드 클리어", mapOf("correct" to correctCount, "exp" to totalExp))
        clearWidgets()
        buildBackground()

        label("", "에피소드 클리어!", 30, FontKind.UI, Palette.brown, CANVAS_W / 2, 600f)
        label("", "${correctCount}문제 정답 · EXP +$totalExp", 18, FontKind.UI, Color.BLACK, CANVAS_W / 2, 520f)
        label("", "현재 Lv.${store.level} · 리그: ${leagueName(store.league)}", 14, FontKind.BODY, Palette.brown, CANVAS_W / 2, 470f)
        if (store.goldenPass) {
            label("", "★ 골든패스 — 오늘 첫 정답 EXP 2배!", 14, FontKind.BODY, Palette.orange, CANVAS_W / 2, 435f)
        }

        makeButton("restart", CANVAS_W / 2, 400f, 220f, 56f, Palette.green)
        label("", "다시 시작", 18, FontKind.UI, Color.WHITE, CANVAS_W / 2, 400f)
    }

    // MARK: - 입력

    // MARK: - 입력 (InputProcessor)

    private val touchPoint = Vector2()

    override fun keyDown(keycode: Int): Boolean {
        if (keycode == com.badlogic.gdx.Input.Keys.BACK) {
            if (state == GameState.SELECTION) {
                Gdx.app.exit()
            } else {
                showSelection()
            }
            return true
        }
        return false
    }

    override fun keyUp(keycode: Int): Boolean = false
    override fun keyTyped(character: Char): Boolean = false
    override fun touchDown(screenX: Int, screenY: Int, pointer: Int, button: Int): Boolean {
        val pos = viewport.unproject(touchPoint.set(screenX.toFloat(), screenY.toFloat()))
        handleTap(pos.x, pos.y)
        return true
    }

    override fun touchUp(screenX: Int, screenY: Int, pointer: Int, button: Int): Boolean = false
    override fun touchCancelled(screenX: Int, screenY: Int, pointer: Int, button: Int): Boolean = false
    override fun touchDragged(screenX: Int, screenY: Int, pointer: Int): Boolean = false
    override fun mouseMoved(screenX: Int, screenY: Int): Boolean = false
    override fun scrolled(amountX: Float, amountY: Float): Boolean = false

    private fun handleTap(gx: Float, gy: Float) {
        val hit = boxes.asSequence()
            .filter { it.name.isNotEmpty() }
            .filter { kotlin.math.abs(gx - it.x) <= it.w / 2 && kotlin.math.abs(gy - it.y) <= it.h / 2 }
            .sortedBy { it.z }
            .lastOrNull()
        val name = hit?.name ?: run {
            DebugLogger.log("warn", "게임", "클릭 무시 (노드 없음)", mapOf("x" to gx.toInt(), "y" to gy.toInt()))
            return
        }

        if (name == "cancel") {
            DebugLogger.feature("게임", "취소됨 (선택 화면으로 복귀)", mapOf("state" to state.name))
            showSelection()
            return
        }

        when (state) {
            GameState.SPLASH -> {}
            GameState.SELECTION -> when (name) {
                "episode_today" -> startTodayEpisode()
                "quickplay" -> handleQuickPlay()
                "archive" -> { showArchive(); loadArchive {} }
                "review" -> loadReview()
                "ranking" -> { showRanking(); loadRanking {} }
            }
            GameState.ARCHIVE -> when (name) {
                "archive_retry" -> loadArchive {}
                "archive_up" -> { archivePage = maxOf(0, archivePage - 1); showArchive() }
                "archive_down" -> { archivePage += 1; showArchive() }
                else -> if (name.startsWith("ep_")) {
                    name.drop(3).toIntOrNull()?.let { openEpisode(it) {} }
                }
            }
            GameState.RANKING -> when (name) {
                "rank_retry" -> loadRanking {}
            }
            GameState.SCENE -> if (name == "next") {
                if (typing) {
                    typedCount = fullText.length
                    typing = false
                    updateDialogText()
                } else {
                    showQuestion()
                }
            }
            GameState.QUESTION -> if (name.startsWith("choice_")) {
                name.drop(7).toIntOrNull()?.let { idx ->
                    currentQuestion?.let { handleAnswer(idx, it) }
                }
            }
            GameState.RESULT_CORRECT -> if (name == "next_scene") {
                if (quickPlay) {
                    quickPlay = false
                    showSelection()
                    return
                }
                val nextIndex = sceneIndex + 1
                if (nextIndex < questions.size) showScene(nextIndex) else showClear()
            }
            GameState.RESULT_WRONG -> if (name == "retry") showQuestion()
            GameState.CLEAR -> if (name == "restart") {
                correctCount = 0
                totalExp = 0
                combo = 0
                showSelection()
            }
        }
    }

    private fun handleAnswer(index: Int, question: Question) {
        val choice = question.choices.getOrNull(index) ?: return
        val explanation = question.explanation ?: question.narrative
        if (choice.isCorrect) {
            correctCount += 1
            combo += 1
            var exp = 10 + minOf((combo - 1) * 2, 10)
            if (combo >= 5) {
                exp += 10
                spawnComboBanner(combo)
            }
            totalExp += exp
            DebugLogger.feature("게임", "콤보", mapOf("combo" to combo, "exp" to exp))
            showResult(correct = true, explanation = explanation, expGained = exp)
        } else {
            combo = 0
            showResult(correct = false, explanation = explanation, expGained = 0)
        }
        val submitCombo = maxOf(combo, 1)
        Thread {
            try {
                ApiClient.submitAnswer(question.id, choice.text, submitCombo)
            } catch (e: Exception) {
                DebugLogger.log("warn", "게임", "답안 제출 실패 — 오프라인 큐", mapOf("error" to (e.message ?: "")))
                store.enqueueAnswer(question.id, choice.text, submitCombo)
            }
        }.start()
    }

    // MARK: - 루프

    override fun render() {
        super.render()
        if (state == GameState.SCENE && typing) {
            typedCount += 1
            updateDialogText()
            if (typedCount >= fullText.length) {
                typedCount = fullText.length
                typing = false
            }
        }

        camera.update()
        viewport.apply()
        batch.projectionMatrix = camera.combined
        shape.projectionMatrix = camera.combined

        // 배경 전체 크림 (wall보다 아래)
        shape.begin(ShapeRenderer.ShapeType.Filled)
        shape.setColor(Palette.cream)
        shape.rect(0f, 0f, CANVAS_W, CANVAS_H)

        val sorted = boxes.sortedBy { it.z }
        for (b in sorted) {
            if (b.fill.a == 0f) continue
            shape.setColor(b.fill)
            shape.rect(b.x - b.w / 2, b.y - b.h / 2, b.w, b.h)
        }
        shape.end()

        batch.begin()
        for (l in labels.sortedBy { it.z }) {
            drawLabel(l)
        }
        batch.end()
    }

    private fun drawLabel(l: Label) {
        val f = font(l.font, l.size)
        val text = if (l.text.isEmpty()) " " else l.text
        val maxW = l.maxW
        layout.setText(f, " ")
        val spaceW = layout.width
        if (maxW <= 0f || spaceW == 0f) {
            layout.setText(f, text)
            f.draw(batch, text, l.x - layout.width / 2, l.y + f.getAscent() * 0.45f)
            return
        }
        // 줄바꿈 wrap
        val wrapped = wrapText(f, text, maxW)
        val lines = wrapped.split("\n")
        layout.setText(f, wrapped)
        val totalH = layout.height
        var y = l.y + totalH / 2 - f.getAscent() * 0.45f
        for (line in lines) {
            layout.setText(f, line)
            f.draw(batch, line, l.x - layout.width / 2, y)
            y -= f.getLineHeight()
        }
    }

    private fun wrapText(f: BitmapFont, text: String, maxW: Float): String {
        val sb = StringBuilder()
        for (chunk in text.split("\n")) {
            val words = chunk.split(" ")
            var line = ""
            for (word in words) {
                val candidate = if (line.isEmpty()) word else "$line $word"
                layout.setText(f, candidate)
                if (layout.width > maxW && line.isNotEmpty()) {
                    sb.append(line).append('\n')
                    line = word
                } else {
                    line = candidate
                }
            }
            sb.append(line).append('\n')
        }
        return sb.toString().trimEnd('\n')
    }

    override fun resize(width: Int, height: Int) {
        viewport.update(width, height, true)
    }

    override fun dispose() {
        batch.dispose()
        shape.dispose()
        white.dispose()
        fontCache.values.forEach { it.dispose() }
    }
}

fun leagueName(league: String): String = when (league) {
    "silver" -> "실버"
    "gold" -> "골드"
    "diamond" -> "다이아몬드"
    else -> "브론즈"
}
