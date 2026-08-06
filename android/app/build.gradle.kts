plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.maiachess.maia_chess"
    compileSdk = flutter.compileSdkVersion
    // Fixado na versão exigida pelo plugin leela_chess_zero (lc0 via FFI/CMake).
    // Ver ADR.md - "Escolha de ABIs e versão do NDK".
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.maiachess.maia_chess"
        // minSdk 24 é exigido pelo motor lc0 (pacote leela_chess_zero). Ver ADR.md.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            // arm64-v8a: dispositivos reais modernos. x86_64: emuladores (dev/CI).
            // armeabi-v7a fica de fora porque o motor lc0 (leela_chess_zero) só builda
            // para arm64-v8a/x86_64 upstream. Ver ADR.md.
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
