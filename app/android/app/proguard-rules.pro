# Classes appelées depuis le code natif ou Dart : R8 ne peut pas voir ces
# références et les supprimerait.

# media_kit : classes utilisées par libmpv via JNI et par le canal Flutter.
-keep class com.alexmercerind.** { *; }

# Canaux natifs de l'application.
-keep class com.aeroiptv.app.** { *; }
