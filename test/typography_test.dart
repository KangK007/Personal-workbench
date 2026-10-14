import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/theme/app_theme.dart';
import 'package:personal_workbench/ui/widgets/common.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android uses bundled jade font roles with stable metrics', () {
    final androidTheme = _themeFor(TargetPlatform.android);

    final androidStyles = _appTextStyles(androidTheme.textTheme);

    expect(androidStyles.keys, isNotEmpty);
    expect(androidTheme.textTheme.displayLarge!.fontFamily, AppFonts.display);
    for (final entry in androidStyles.entries) {
      final name = entry.key;
      final android = entry.value;

      expect(android.fontFamily, AppFonts.body, reason: '$name font family');
      expect(android.fontSize, isNotNull, reason: '$name font size');
      expect(android.height, isNotNull, reason: '$name line height');
      expect(android.fontWeight, isNotNull, reason: '$name weight');
      expect(android.letterSpacing, 0, reason: '$name letter spacing');
    }
  });

  test('theme display weight changes without changing font roles', () {
    final day = AppTheme.light().textTheme;
    final night = AppTheme.dark().textTheme;
    expect(day.displayLarge!.fontFamily, AppFonts.display);
    expect(night.displayLarge!.fontFamily, AppFonts.display);
    expect(day.displayLarge!.fontWeight, FontWeight.w500);
    expect(night.displayLarge!.fontWeight, FontWeight.w600);
    expect(day.headlineMedium!.fontFamily, AppFonts.body);
    expect(night.headlineMedium!.fontFamily, AppFonts.body);
    expect(day.bodyLarge!.fontFamily, AppFonts.body);
    expect(night.bodyLarge!.fontFamily, AppFonts.body);
  });

  test('all three font roles load from bundled offline assets', () async {
    final assets = [
      'assets/fonts/LXGWWenKaiGB-Medium.ttf',
      'assets/fonts/IBMPlexSansSC-Regular.otf',
      'assets/fonts/IBMPlexSansSC-Medium.otf',
      'assets/fonts/IBMPlexSansSC-SemiBold.otf',
      'assets/fonts/IBMPlexMono-Medium.ttf',
    ];

    for (final asset in assets) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }
  });

  testWidgets('numeric text uses the bundled monospaced role', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const NumericText('14:00 · +20 XP'),
      ),
    );

    final text = tester.widget<Text>(find.text('14:00 · +20 XP'));
    expect(text.style!.fontFamily, AppFonts.numeric);
    expect(text.style!.fontWeight, FontWeight.w500);
    expect(text.style!.fontFeatures, isNotEmpty);
  });

  testWidgets('page headers reserve the display face for short hero titles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Column(
            children: [
              PageHeader(title: '项目'),
              PageHeader(title: '专注', displayTitle: true),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.text('项目')).style!.fontFamily,
      AppFonts.body,
    );
    expect(
      tester.widget<Text>(find.text('专注')).style!.fontFamily,
      AppFonts.display,
    );
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
