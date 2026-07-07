# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# ML Kit Text Recognition - keep all language model classes
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Suppress missing class warnings from R8
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
