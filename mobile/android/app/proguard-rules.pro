# Twilio Programmable Voice — requis pour que le SDK ne soit pas obfusqué
# en build release (sinon les appels échouent silencieusement).
-keep class com.twilio.** { *; }
-keep class tvo.webrtc.** { *; }
-dontwarn tvo.webrtc.**
-keep class com.twilio.voice.** { *; }
-keepattributes InnerClasses
