# Consumer ProGuard rules for feature:audio
# Keep Media3 service and session classes
-keep class androidx.media3.** { *; }
-keep class com.quranapp.audio.service.AudioPlaybackService { *; }
