// SettingsStore — SharedPreferences (uuid, 닉네임, 서버 주소, 프로필 캐시, 오프라인 큐)
package com.borasarang.wordville

import android.content.Context

class SettingsStore(context: Context) {
    private val prefs = context.getSharedPreferences("wordville", Context.MODE_PRIVATE)

    var uuid: String
        get() = prefs.getString("uuid", null) ?: generateUuid().also { uuid = it }
        set(value) = prefs.edit().putString("uuid", value).apply()

    var nickname: String
        get() = prefs.getString("nickname", "글마을 주민")!!
        set(value) = prefs.edit().putString("nickname", value).apply()

    var serverBaseURL: String
        get() = prefs.getString("serverBaseURL", "http://10.0.2.2:3000")!!
        set(value) = prefs.edit().putString("serverBaseURL", value).apply()

    var token: String
        get() = prefs.getString("token", "")!!
        set(value) = prefs.edit().putString("token", value).apply()

    var profileJson: String?
        get() = prefs.getString("profile", null)
        set(value) = prefs.edit().putString("profile", value).apply()

    private var _profile: AuthUser? = null
    var profile: AuthUser?
        get() = _profile ?: profileJson?.let { runCatching { ApiClient.json.decodeFromString<AuthUser>(it) }.getOrNull() }
        set(value) {
            _profile = value
            profileJson = value?.let { runCatching { ApiClient.json.encodeToString<AuthUser>(it) }.getOrNull() }
        }

    val level: Int get() = profile?.level ?: 1
    val exp: Int get() = profile?.exp ?: 0
    val streakDays: Int get() = profile?.streak_days ?: 0
    val league: String get() = profile?.league ?: "bronze"
    val goldenPass: Boolean get() = (profile?.streak_days ?: 0) >= 7

    // 오프라인 큐 (SharedPreferences JSON — IndexedDB 대체, 용량 한계 내)
    private val queueKey = "offlineQueue"
    var offlineQueue: List<QueuedAnswer>
        get() = prefs.getString(queueKey, "[]")?.let {
            runCatching { ApiClient.json.decodeFromString<List<QueuedAnswer>>(it) }.getOrDefault(emptyList())
        } ?: emptyList()
        set(value) = prefs.edit().putString(queueKey, ApiClient.json.encodeToString(value)).apply()

    fun enqueueAnswer(questionId: Int, selected: String, combo: Int) {
        val q = offlineQueue.toMutableList()
        q.add(QueuedAnswer(questionId = questionId, selected = selected, combo = combo))
        offlineQueue = q
        DebugLogger.feature("오프라인 큐", "답안 대기 등록", mapOf("count" to q.size))
    }

    fun clearQueue() {
        offlineQueue = emptyList()
    }

    private fun generateUuid(): String {
        val bytes = ByteArray(16)
        java.security.SecureRandom().nextBytes(bytes)
        bytes[6] = ((bytes[6].toInt() and 0x0f) or 0x40).toByte()
        bytes[8] = ((bytes[8].toInt() and 0x3f) or 0x80).toByte()
        val hex = bytes.joinToString("") { "%02x".format(it) }
        return hex.substring(0, 8) + "-" + hex.substring(8, 12) + "-" + hex.substring(12, 16) +
            "-" + hex.substring(16, 20) + "-" + hex.substring(20)
    }
}
