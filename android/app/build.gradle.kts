import java.util.Properties

plugins {
    id("com.android.application")
    // Flutter follows AGP, which provides the Kotlin compiler.
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
val emulatorX64 = project.findProperty("target-platform")?.toString() == "android-x64"

val keystorePropertiesFile = rootProject.file("app/key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.maiachess.maia_chess"
    compileSdk = flutter.compileSdkVersion
    // Pinned native toolchain for release reproducibility.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.maiachess.maia_chess"
        // Bundled ONNX Runtime requires Android API 24 or later.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            // Release devices use ARM64; CI has a separate x86_64 runtime.
            // Flutter configures ABI splits itself when requested; AGP rejects
            // combining those splits with defaultConfig ABI filters.
            if (project.findProperty("split-per-abi") != "true") {
                abiFilters.clear()
                abiFilters += listOf(if (emulatorX64) "x86_64" else "arm64-v8a")
            }
        }
    }

    packaging {
        jniLibs.useLegacyPackaging = true
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

// Run full lint with the same Flutter inputs and ABI as the release APK.
if (providers.gradleProperty("lint-release").orNull == "true") {
    tasks.matching { it.name == "assembleRelease" }.configureEach {
        dependsOn("lintRelease")
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// The published APK stays ARM64. CI emulator builds use the official matching
// ORT 1.22 runtime; pub's onnxruntime_plus only bundles ARM libraries.
if (emulatorX64) {
    dependencies {
        debugImplementation("com.microsoft.onnxruntime:onnxruntime-android:1.22.0")
    }
}
