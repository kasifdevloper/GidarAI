# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.kts.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# Keep data classes used by Gson
-keepclassmembers class ai.gidar.app.data.remote.** { *; }
-keepclassmembers class ai.gidar.app.data.local.** { *; }

# Keep Hilt generated classes
-keep class dagger.hilt.** { *; }
-keep class * extends dagger.hilt.android.internal.managers.ViewComponentManager$FragmentContextWrapper { *; }

# Keep Room generated classes
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Entity class * { *; }

# Keep Retrofit
-keepattributes Signature
-keepattributes *Annotation*
-keep class retrofit2.** { *; }
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}

# Keep OkHttp
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**

# Keep Gson
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep Markwon
-keep class io.noties.markwon.** { *; }

# Keep Coil
-keep class coil.** { *; }

# Keep DataStore
-keep class androidx.datastore.** { *; }

# Keep Security Crypto
-keep class androidx.security.crypto.** { *; }

# Keep SSE
-keep class okhttp3.sse.** { *; }

# General Android
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Keep custom application class
-keep class ai.gidar.app.GidarApp { *; }

# Keep all activities
-keep public class * extends android.app.Activity
-keep public class * extends androidx.activity.ComponentActivity

# Keep all ViewModels
-keep class * extends androidx.lifecycle.ViewModel { *; }

# Keep all Composable functions
-keepclassmembers class * {
    @androidx.compose.runtime.Composable *;
}
