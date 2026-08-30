import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/theme/app_theme.dart';

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('light and dark theme text pairs meet WCAG AA contrast', () {
    final themes = {'light': AppTheme.light(), 'dark': AppTheme.dark()};
    for (final entry in themes.entries) {
      final theme = entry.value;
      final scheme = theme.colorScheme;
      final pairs = {
        'onSurface/surface': (scheme.onSurface, scheme.surface),
        'onSurfaceVariant/surface': (scheme.onSurfaceVariant, scheme.surface),
        'primary/surface': (scheme.primary, scheme.surface),
        'onPrimary/primary': (scheme.onPrimary, scheme.primary),
        'error/surface': (scheme.error, scheme.surface),
      };
      for (final pair in pairs.entries) {
        expect(
          _contrastRatio(pair.value.$1, pair.value.$2),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key} ${pair.key}',
        );
      }
    }
  });

  test('Android button themes provide 48dp touch targets', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final theme = AppTheme.light();
    const states = <WidgetState>{};

    expect(
      theme.filledButtonTheme.style!.minimumSize!.resolve(states)!.height,
      greaterThanOrEqualTo(48),
    );
    expect(
      theme.outlinedButtonTheme.style!.minimumSize!.resolve(states)!.height,
      greaterThanOrEqualTo(48),
    );
    expect(
      theme.textButtonTheme.style!.minimumSize!.resolve(states)!.height,
      greaterThanOrEqualTo(48),
    );
    final iconSize = theme.iconButtonTheme.style!.minimumSize!.resolve(states)!;
    expect(iconSize.width, greaterThanOrEqualTo(48));
    expect(iconSize.height, greaterThanOrEqualTo(48));
    expect(theme.listTileTheme.minTileHeight, greaterThanOrEqualTo(48));
  });

  test('button themes expose hover focus pressed and disabled states', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final styles = [
        theme.filledButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
        theme.textButtonTheme.style!,
        theme.iconButtonTheme.style!,
      ];
      for (final style in styles) {
        final hover = style.overlayColor!.resolve({WidgetState.hovered});
        final focus = style.overlayColor!.resolve({WidgetState.focused});
        final pressed = style.overlayColor!.resolve({WidgetState.pressed});
        expect(hover, isNotNull);
        expect(focus, isNotNull);
        expect(pressed, isNotNull);
        expect(pressed, isNot(equals(hover)));
      }

      final side = theme.outlinedButtonTheme.style!.side!;
      expect(
        side.resolve({WidgetState.disabled}),
        isNot(equals(side.resolve(const {}))),
      );
    }
  });
}
