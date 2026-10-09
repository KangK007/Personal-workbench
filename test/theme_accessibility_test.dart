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
        'primary/canvas': (
          scheme.primary,
          theme.extension<WorkbenchTokens>()!.canvas,
        ),
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
      final tokens = theme.extension<WorkbenchTokens>()!;
      for (final text in [tokens.mutedText, tokens.inkFaint, scheme.primary]) {
        for (final surface in [
          tokens.panel,
          tokens.canvas,
          tokens.subtle,
          tokens.emphasisSurface,
        ]) {
          expect(
            _contrastRatio(text, surface),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key}: small labels on tinted surfaces',
          );
        }
      }
    }
  });

  test('day and night identities expose distinct semantic surfaces', () {
    final day = AppTheme.light();
    final night = AppTheme.dark();
    final dayTokens = day.extension<WorkbenchTokens>()!;
    final nightTokens = night.extension<WorkbenchTokens>()!;

    expect(day.colorScheme.primary, AppColors.lightPrimary);
    expect(night.colorScheme.primary, AppColors.darkPrimary);
    expect(dayTokens.navigation, AppColors.lightNavigation);
    expect(nightTokens.navigation, AppColors.darkNavigation);
    expect(dayTokens.heroStart, AppColors.lightHeroStart);
    expect(nightTokens.heroStart, AppColors.darkHeroStart);
    expect(dayTokens.reward, AppColors.lightReward);
    expect(nightTokens.reward, AppColors.darkReward);
    expect(dayTokens.panelRadius, 20);
    expect(nightTokens.panelRadius, 18);

    for (final theme in [day, night]) {
      final tokens = theme.extension<WorkbenchTokens>()!;
      final scheme = theme.colorScheme;
      expect(
        _contrastRatio(scheme.onSurface, tokens.navigation),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(scheme.onSurface, tokens.heroStart),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(scheme.onSurface, tokens.heroEnd),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(tokens.borderStrong, tokens.panel),
        greaterThanOrEqualTo(3),
      );
    }
  });

  test('theme extension interpolates newly added visual roles', () {
    final day = AppTheme.light().extension<WorkbenchTokens>()!;
    final night = AppTheme.dark().extension<WorkbenchTokens>()!;
    final midpoint = day.lerp(night, 0.5);
    expect(
      midpoint.navigation,
      Color.lerp(day.navigation, night.navigation, 0.5),
    );
    expect(midpoint.heroStart, Color.lerp(day.heroStart, night.heroStart, 0.5));
    expect(
      midpoint.orbitTrack,
      Color.lerp(day.orbitTrack, night.orbitTrack, 0.5),
    );
    expect(midpoint.panelRadius, 19);
    expect(
      day.copyWith(navigation: night.navigation).navigation,
      night.navigation,
    );
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

  test('panel edges are clearer than decorative dividers', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final tokens = theme.extension<WorkbenchTokens>()!;
      expect(
        _contrastRatio(tokens.panelBorder, tokens.panel),
        greaterThan(_contrastRatio(tokens.divider, tokens.panel)),
      );
      expect(
        _contrastRatio(tokens.borderStrong, tokens.panel),
        greaterThanOrEqualTo(_contrastRatio(tokens.panelBorder, tokens.panel)),
      );
    }
  });

  test(
    'forms and actions expose semantic error and keyboard focus borders',
    () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final scheme = theme.colorScheme;
        final inputs = theme.inputDecorationTheme;
        final errorBorder = inputs.errorBorder! as OutlineInputBorder;
        final focusedErrorBorder =
            inputs.focusedErrorBorder! as OutlineInputBorder;
        expect(errorBorder.borderSide.color, scheme.error);
        expect(focusedErrorBorder.borderSide.color, scheme.error);
        expect(focusedErrorBorder.borderSide.width, 2);
        expect(inputs.errorStyle!.color, scheme.error);

        final focused = <WidgetState>{WidgetState.focused};
        final filledSide = theme.filledButtonTheme.style!.side!.resolve(
          focused,
        )!;
        expect(filledSide.width, 2);
        expect(
          _contrastRatio(filledSide.color, scheme.primary),
          greaterThanOrEqualTo(3),
        );
        for (final style in [
          theme.outlinedButtonTheme.style!,
          theme.textButtonTheme.style!,
          theme.iconButtonTheme.style!,
        ]) {
          expect(style.side!.resolve(focused)!.width, 2);
        }
      }
    },
  );
}
