import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: see docs/android-releases.md.
// Keep android/app/key.properties and the keystore out of version control.
// Generate a dedicated key with:
//
//   keytool -genkeypair -v -keystore android/app/release-keystore.jks \
//     -alias maia_chess_release -keyalg RSA -keysize 2048 -validity 10000
//
// Then create android/app/key.properties with:
//
//   storeFile=release-keystore.jks
//   storePassword=<keystore password>
//   keyAlias=maia_chess_release
//   keyPassword=<key password>
val keystorePropertiesFile = rootProject.file("app/key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.maiachess.maia_chess"
    compileSdk = flutter.compileSdkVersion
    // Match the lc0 plugin's FFI/CMake toolchain.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.maiachess.maia_chess"
        // lc0 requires Android API 24 or later.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            // arm64-v8a for devices; x86_64 for development emulators.
            // The lc0 plugin enables only these 64-bit ABIs.
            // Flutter configures ABI splits itself when requested; AGP rejects
            // combining those splits with defaultConfig ABI filters.
            if (project.findProperty("split-per-abi") != "true") {
                abiFilters += listOf("arm64-v8a", "x86_64")
            }
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
            // Local release builds fall back to debug signing when no dedicated
            // key is configured. CI requires release signing for publication.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "WARNING: android/app/key.properties is missing; release " +
                        "build uses the DEBUG signing key. See docs/android-releases.md " +
                        "before distributing the APK."
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
