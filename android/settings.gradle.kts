pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    // Upgrade the compiler used by AGP built-in Kotlin; do not apply KGP.
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")

// Retain the locked package sources while replacing its obsolete Android build.
project(":stockfish").buildFileName = project(":stockfish").projectDir.toPath()
    .relativize(file("stockfish.gradle").toPath()).toString()
