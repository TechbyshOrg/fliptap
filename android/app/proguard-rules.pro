# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep application classes
-keep class com.techbysh.fliptap.** { *; }

# Suppress warnings for missing Play Store Split/Deferred Component dependencies referenced by Flutter Engine
-dontwarn com.google.android.play.core.**

