// DebugLogger — android.util.Log 기반 (macOS DebugLogger 대응)
package com.borasarang.wordville

import android.util.Log

object DebugLogger {
    private const val TAG = "Wordville"

    fun log(level: String, feature: String, message: String, meta: Map<String, Any?> = emptyMap()) {
        val metaStr = if (meta.isEmpty()) "" else " | " + meta.entries.joinToString { (k, v) -> "$k=$v" }
        when (level) {
            "warn" -> Log.w(TAG, "[$feature] $message$metaStr")
            "error" -> Log.e(TAG, "[$feature] $message$metaStr")
            else -> Log.i(TAG, "[$feature] $message$metaStr")
        }
    }

    fun feature(feature: String, message: String, meta: Map<String, Any?> = emptyMap()) =
        log("info", feature, message, meta)
}
