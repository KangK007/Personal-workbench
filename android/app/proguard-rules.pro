# Project-specific R8 rules can be added here when a dependency requires them.

# flutter_local_notifications deserializes scheduled notifications through Gson
# TypeToken. Release shrinking must preserve its generic signature.
-keepattributes Signature
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
