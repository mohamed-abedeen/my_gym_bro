# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core: Flutter's deferred-components support references these classes,
# but the app doesn't use deferred components or ship the Play Core library.
-dontwarn com.google.android.play.core.**

# Firebase
-keep class com.google.firebase.** { *; }

# Supabase / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# SQLCipher
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# RevenueCat
-keep class com.revenuecat.purchases.** { *; }
