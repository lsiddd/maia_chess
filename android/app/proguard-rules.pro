# Flutter engine e embedding: nomes de classe consultados via reflection
# pelo mecanismo de registro de plugins.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# lc0 (leela_chess_zero) e stockfish falam com o binário nativo via
# Dart FFI/JNI; preserva os pontos de entrada nativos para o linker não
# perder símbolos que o R8 não enxerga sendo chamados do lado Dart.
-keepclasseswithmembernames class * {
    native <methods>;
}

# O Flutter engine referencia as APIs do Play Core (deferred components /
# dynamic feature modules) mesmo quando o app não as usa, como aqui. Sem a
# dependência do Play Core no classpath, o R8 falha ao resolver essas
# classes; -dontwarn é seguro pois o caminho de código nunca é exercitado.
-dontwarn com.google.android.play.core.**
