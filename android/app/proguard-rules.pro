# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Whisper FFI
-keep class com.eva.br.** { *; }
-keep class * extends dart.ffi.Opaque { *; }

# Record Package
-keep class com.llfbandit.record.** { *; }
