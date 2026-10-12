# Keep Flutter embedding classes accessed reflectively during plugin registration.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep JNI method names that R8 cannot infer from native callers.
# Dart FFI symbols are preserved by the native build, independently of R8.
-keepclasseswithmembernames class * {
    native <methods>;
}

# Flutter references Play Core APIs for deferred components, which this app
# does not use. Suppress missing-class warnings for that unused code path.
-dontwarn com.google.android.play.core.**
