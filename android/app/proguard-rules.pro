# Add project specific ProGuard rules here.

# Keep Godot engine classes
-keep class org.godotengine.** { *; }

# Keep Google Play services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep application classes
-keep class com.game.mergemogul.** { *; }