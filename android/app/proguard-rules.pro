# Project-specific ProGuard/R8 rules.
# Flutter and Android plugin defaults provide the required baseline rules.
# Add narrowly-scoped keep rules here only when runtime reflection requires them.

-dontwarn javax.annotation.**
-dontwarn org.jetbrains.annotations.**
-dontwarn com.google.android.play.core.**

# Preserve Flutter plugin registration and Android component entry points.
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

