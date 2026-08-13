// Wordville Android — 앱 모듈
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "com.borasarang.wordville"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.borasarang.wordville"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.3.0"
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86", "x86_64")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    sourceSets["main"].jniLibs.srcDirs("build/libs")
}

// libGDX 네이티브 .so 추출 (gdx-platform natives jar → jniLibs)
val nativesConfig = configurations.create("natives")

dependencies {
    val gdxVersion = "1.14.2"
    implementation("com.badlogicgames.gdx:gdx:$gdxVersion")
    implementation("com.badlogicgames.gdx:gdx-backend-android:$gdxVersion")
    implementation("com.badlogicgames.gdx:gdx-freetype:$gdxVersion")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.0")
    nativesConfig("com.badlogicgames.gdx:gdx-platform:$gdxVersion:natives-arm64-v8a")
    nativesConfig("com.badlogicgames.gdx:gdx-platform:$gdxVersion:natives-armeabi-v7a")
    nativesConfig("com.badlogicgames.gdx:gdx-platform:$gdxVersion:natives-x86")
    nativesConfig("com.badlogicgames.gdx:gdx-platform:$gdxVersion:natives-x86_64")
    nativesConfig("com.badlogicgames.gdx:gdx-freetype-platform:$gdxVersion:natives-arm64-v8a")
    nativesConfig("com.badlogicgames.gdx:gdx-freetype-platform:$gdxVersion:natives-armeabi-v7a")
    nativesConfig("com.badlogicgames.gdx:gdx-freetype-platform:$gdxVersion:natives-x86")
    nativesConfig("com.badlogicgames.gdx:gdx-freetype-platform:$gdxVersion:natives-x86_64")
}

val copyAndroidNatives by tasks.registering(Copy::class) {
    val target = layout.projectDirectory.dir("libs")
    doFirst { target.asFile.deleteRecursively() }
    nativesConfig.files.forEach { jar ->
        val abi = when {
            jar.name.endsWith("natives-arm64-v8a.jar") -> "arm64-v8a"
            jar.name.endsWith("natives-armeabi-v7a.jar") -> "armeabi-v7a"
            jar.name.endsWith("natives-x86.jar") -> "x86"
            jar.name.endsWith("natives-x86_64.jar") -> "x86_64"
            else -> null
        }
        if (abi != null) {
            from(zipTree(jar)) { into("libs/$abi"); include("*.so") }
        }
    }
    into(layout.buildDirectory)
}
tasks.matching { it.name == "preBuild" || it.name.contains("externalNativeBuild") }
    .configureEach { dependsOn(copyAndroidNatives) }