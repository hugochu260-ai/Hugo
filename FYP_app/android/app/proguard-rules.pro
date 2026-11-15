# VLC loads these classes from native code (libvlcjni.so).
-keep class org.videolan.libvlc.** { *; }
-keep class org.videolan.libvlc.interfaces.** { *; }
-keep class software.solid.fluttervlcplayer.** { *; }
-dontwarn org.videolan.**
