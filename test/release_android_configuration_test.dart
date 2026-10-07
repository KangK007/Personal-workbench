import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release keeps notification Gson metadata and icon resource', () {
    final proguard = File('android/app/proguard-rules.pro').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(proguard, contains('-keepattributes Signature'));
    expect(
      proguard,
      contains(
        '-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken',
      ),
    );
    expect(gradle, contains('isShrinkResources = false'));
  });
}
