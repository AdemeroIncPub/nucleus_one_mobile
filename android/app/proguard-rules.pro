#Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# NOTE: this section is a temp fix until a new version of
# flutter is release, then it can be removed
# https://github.com/flutter/flutter/issues/37441
# https://github.com/flutter/flutter/issues/40218
# https://github.com/flutter/flutter/pull/39126
# https://github.com/flutter/flutter/pull/39157
-dontwarn io.flutter.app.**
-dontwarn io.flutter.plugin.**
-dontwarn io.flutter.util.**
-dontwarn io.flutter.view.**
-dontwarn io.flutter.**
-dontwarn io.flutter.plugins.**

-keep class com.google.android.** { *; }
-keep class com.google.firebase.** { *; }
