// ApiClient — OkHttp 동기 호출 + kotlinx.serialization (GameModels.swift와 동일 구조)
package com.borasarang.wordville

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

// ---- 모델 (GameModels.swift 1:1) ----
@Serializable
data class Choice(
    val text: String,
    @SerialName("isCorrect") val isCorrect: Boolean,
)

@Serializable
data class Question(
    val id: Int,
    @SerialName("scene_index") val scene_index: Int,
    val narrative: String,
    val choices: List<Choice>,
    val explanation: String? = null,
)

@Serializable
data class AuthUser(
    val id: String,
    val nickname: String,
    @SerialName("avatar_url") val avatar_url: String? = null,
    val exp: Int? = null,
    @SerialName("streak_days") val streak_days: Int? = null,
    @SerialName("last_played") val last_played: String? = null,
    val league: String? = null,
    val level: Int? = null,
    @SerialName("golden_pass") val golden_pass: Boolean? = null,
)

@Serializable
data class AuthResponse(val token: String, val user: AuthUser)

@Serializable
data class QuickQuestion(
    val id: Int,
    @SerialName("scene_index") val scene_index: Int = 0,
    val narrative: String,
    val choices: List<Choice>,
    val explanation: String? = null,
    @SerialName("episode_title") val episode_title: String? = null,
)

@Serializable
data class EpisodeSummary(
    val id: Int,
    @SerialName("episode_date") val episode_date: String,
    val category: String = "",
    val title: String,
    val played: Boolean = false,
)

@Serializable
data class ReviewEpisode(val title: String, val questions: List<Question>)

@Serializable
data class QuestionsResponse(
    @SerialName("episode_id") val episode_id: Int,
    val questions: List<Question>,
)

@Serializable
data class RankingEntry(
    val id: String,
    val nickname: String,
    val league: String? = null,
    val score: Int? = null,
)

@Serializable
data class WeeklyRanking(
    @SerialName("week_key") val week_key: String? = null,
    @SerialName("my_rank") val my_rank: Int? = null,
    val rankings: List<RankingEntry>,
)

@Serializable
data class QueuedAnswer(
    @SerialName("question_id") val questionId: Int,
    val selected: String,
    val combo: Int,
)

@Serializable
data class APIErrorBody(val code: String, val message: String)

object ApiClient {
    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()

    val json = Json { ignoreUnknownKeys = true }
    private val media = "application/json; charset=utf-8".toMediaType()

    fun get(path: String): String {
        val req = Request.Builder()
            .url(SettingsStoreHolder.store.serverBaseURL + path)
            .header("Authorization", "Bearer ${SettingsStoreHolder.store.token}")
            .build()
        client.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) throw RuntimeException("HTTP ${resp.code}")
            return resp.body?.string() ?: ""
        }
    }

    fun post(path: String, body: String): String {
        val req = Request.Builder()
            .url(SettingsStoreHolder.store.serverBaseURL + path)
            .header("Authorization", "Bearer ${SettingsStoreHolder.store.token}")
            .post(body.toRequestBody(media))
            .build()
        client.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) throw RuntimeException("HTTP ${resp.code}")
            return resp.body?.string() ?: ""
        }
    }

    private inline fun <reified T> parse(text: String): T =
        json.decodeFromString(JsonObjectWrapper.schema<T>(), text).data ?: throw RuntimeException("no data")

    // ensureAuth: uuid 기반 익명 로그인 (토큰 없거나 실패 시 갱신)
    fun ensureAuth(): AuthUser {
        val store = SettingsStoreHolder.store
        if (store.token.isNotEmpty()) {
            runCatching { return fetchMe() }
        }
        val resp = post("/auth/anon", json.encodeToString(
            AuthAnonRequest(nickname = store.nickname, deviceId = store.uuid),
        ))
        val parsed = json.decodeFromString<APIResponse<AuthResponse>>(resp).data
            ?: throw RuntimeException("auth failed")
        store.token = parsed.token
        store.profile = parsed.user
        return parsed.user
    }

    fun fetchMe(): AuthUser {
        val resp = get("/users/me")
        val user = json.decodeFromString<APIResponse<AuthUser>>(resp).data
            ?: throw RuntimeException("me failed")
        SettingsStoreHolder.store.profile = user
        return user
    }

    fun fetchTodayEpisode(): EpisodeSummary {
        val resp = get("/episodes/today")
        return json.decodeFromString<APIResponse<EpisodeSummary>>(resp).data
            ?: throw RuntimeException("today failed")
    }

    fun fetchQuestions(episodeId: Int): List<Question> {
        val resp = get("/episodes/$episodeId/questions")
        return json.decodeFromString<APIResponse<QuestionsResponse>>(resp).data?.questions
            ?: throw RuntimeException("questions failed")
    }

    fun fetchQuickQuestion(): QuickQuestion {
        val resp = get("/episodes/quick")
        return json.decodeFromString<APIResponse<QuickQuestion>>(resp).data
            ?: throw RuntimeException("quick failed")
    }

    fun fetchReviewQuestions(): ReviewEpisode {
        val resp = get("/episodes/review")
        return json.decodeFromString<APIResponse<ReviewEpisode>>(resp).data
            ?: throw RuntimeException("review failed")
    }

    fun fetchEpisodeList(): List<EpisodeSummary> {
        val resp = get("/episodes")
        return json.decodeFromString<APIResponse<List<EpisodeSummary>>>(resp).data
            ?: throw RuntimeException("list failed")
    }

    fun fetchWeeklyRanking(): WeeklyRanking {
        val resp = get("/rankings/weekly")
        return json.decodeFromString<APIResponse<WeeklyRanking>>(resp).data
            ?: throw RuntimeException("ranking failed")
    }

    fun submitAnswer(questionId: Int, selected: String, combo: Int): String {
        val body = json.encodeToString(
            AnswerSubmit(question_id = questionId, selected = selected, combo = combo),
        )
        return post("/answers", body)
    }

    // 오프라인 큐 flush (앱 시작/네트워크 복구 시)
    fun flushQueue() {
        val store = SettingsStoreHolder.store
        val pending = store.offlineQueue
        if (pending.isEmpty()) return
        DebugLogger.feature("오프라인 큐", "flush 시작", mapOf("count" to pending.size))
        runCatching { ensureAuth() }
        for (task in pending) {
            val ok = runCatching {
                submitAnswer(task.questionId, task.selected, task.combo)
            }.isSuccess
            if (!ok) {
                DebugLogger.log("warn", "오프라인 큐", "전송 실패 — 보류", mapOf("qid" to task.questionId))
                return
            }
        }
        store.clearQueue()
        DebugLogger.feature("오프라인 큐", "flush 완료")
    }
}

@Serializable
data class AuthAnonRequest(val nickname: String, @SerialName("device_id") val deviceId: String)

@Serializable
data class AnswerSubmit(
    @SerialName("question_id") val question_id: Int,
    val selected: String,
    val combo: Int,
)

@Serializable
data class APIResponse<T>(
    val ok: Boolean,
    val data: T? = null,
    val error: APIErrorBody? = null,
)

object JsonObjectWrapper {
    inline fun <reified T> schema(): kotlinx.serialization.KSerializer<APIResponse<T>> =
        kotlinx.serialization.serializer<APIResponse<T>>()
}

// SettingsStoreHolder — 게임/API에서 접근 가능한 전역 저장소
object SettingsStoreHolder {
    lateinit var store: SettingsStore
}
