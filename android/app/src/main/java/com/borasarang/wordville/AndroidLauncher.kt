// AndroidLauncher — libGDX 진입점 (immersive, portrait)
package com.borasarang.wordville

import android.os.Bundle
import android.view.WindowManager
import com.badlogic.gdx.backends.android.AndroidApplication
import com.badlogic.gdx.backends.android.AndroidApplicationConfiguration

class AndroidLauncher : AndroidApplication() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        SettingsStoreHolder.store = SettingsStore(applicationContext)

        val config = AndroidApplicationConfiguration()
        config.useImmersiveMode = true
        config.useWakelock = true
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        DebugLogger.feature("앱", "런처 시작", mapOf("uuid" to SettingsStoreHolder.store.uuid.take(8)))
        initialize(WordvilleGame(), config)
    }
}
