import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Assinatura de release (ver AUDITORIA_TECNICA.md, AUD-006, e ADR.md):
// android/app/key.properties nunca é commitado (ver .gitignore). Gere um
// keystore próprio com:
//
//   keytool -genkeypair -v -keystore android/app/release-keystore.jks \
//     -alias maia_chess_release -keyalg RSA -keysize 2048 -validity 10000
//
// e crie android/app/key.properties com:
//
//   storeFile=release-keystore.jks
//   storePassword=<senha do keystore>
//   keyAlias=maia_chess_release
//   keyPassword=<senha da chave>
val keystorePropertiesFile = rootProject.file("app/key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
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

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Usa a chave de release dedicada quando android/app/key.properties
            // existir (gerado localmente, nunca commitado). Sem esse arquivo,
            // cai de volta para a chave de debug — como antes, para que
            // `flutter run --release` continue funcionando sem setup extra em
            // ambiente de desenvolvimento — mas avisa no configure do Gradle
            // para isso não passar despercebido numa build para distribuição.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "AVISO: android/app/key.properties nao encontrado; build " +
                        "de release assinada com a chave de DEBUG. Ver ADR.md " +
                        "(assinatura de release) antes de distribuir o APK."
                )
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
