import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/theme/app_theme.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android uses system fonts with matching type metrics', () {
    final androidTheme = _themeFor(TargetPlatform.android);

    final androidStyles = _appTextStyles(androidTheme.textTheme);

    expect(androidStyles.keys, isNotEmpty);
    for (final entry in androidStyles.entries) {
      final name = entry.key;
      final android = entry.value;

      expect(
        _usesForbiddenFont(android),
        isFalse,
        reason: '$name must use the Android system font',
      );
      expect(android.fontSize, isNotNull, reason: '$name font size');
      expect(android.height, isNotNull, reason: '$name line height');
      expect(android.fontWeight, isNotNull, reason: '$name weight');
      expect(android.letterSpacing, isNotNull, reason: '$name letter spacing');
    }
  });
}

ThemeData _themeFor(TargetPlatform platform) {
  debugDefaultTargetPlatformOverride = platform;
  return AppTheme.light();
}

Map<String, TextStyle> _appTextStyles(TextTheme theme) => {
  'headlineMedium': theme.headlineMedium!,
  'titleLarge': theme.titleLarge!,
  'titleMedium': theme.titleMedium!,
  'titleSmall': theme.titleSmall!,
  'bodyLarge': theme.bodyLarge!,
  'bodyMedium': theme.bodyMedium!,
  'bodySmall': theme.bodySmall!,
  'labelLarge': theme.labelLarge!,
  'labelMedium': theme.labelMedium!,
};

bool _usesForbiddenFont(TextStyle style) {
  const forbiddenFamilies = {
    'barlowcondensed',
    'stkaiti',
    'kaiti',
    'simsun',
    'noto serif cjk sc',
    'source han serif sc',
  };
  final families = <String>[
    if (style.fontFamily != null) style.fontFamily!,
    ...?style.fontFamilyFallback,
  ];
  return families.any(
    (family) => forbiddenFamilies.contains(family.toLowerCase()),
  );
}
