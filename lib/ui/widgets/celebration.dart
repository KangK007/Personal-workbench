import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A quiet, dismissible completion state. The ring settles once, without
/// confetti or a continuously running decorative animation.
class FocusCelebration extends StatelessWidget {
  const FocusCelebration({
    super.key,
    required this.title,
    this.subtitle,
    this.duration = const Duration(milliseconds: 360),
    this.actionLabel = '继续',
    this.onDone,
  });

  final String title;
  final String? subtitle;
  final Duration duration;
  final String actionLabel;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : duration;
    final narrowLargeText =
        MediaQuery.sizeOf(context).width < 360 &&
        MediaQuery.textScalerOf(context).scale(14) >= 22;
    final visualTitle = narrowLargeText && title == '本次专注已记录'
        ? '本次专注\n已记录'
        : title;
    void close() {
      if (onDone case final callback?) {
        callback();
      } else {
        Navigator.of(context).maybePop();
      }
    }

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                color: scheme.surface,
                elevation: 2,
                borderRadius: BorderRadius.circular(tokens.panelRadius),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: close,
                          tooltip: '关闭完成反馈',
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      RepaintBoundary(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: animationDuration,
                          curve: Curves.easeOutCubic,
                          builder: (context, progress, _) => SizedBox.square(
                            dimension: 88,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox.square(
                                  dimension: 88,
                                  child: CircularProgressIndicator(
                                    key: const ValueKey(
                                      'focus-completion-ring',
                                    ),
                                    value: progress,
                                    strokeWidth: 7,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor: scheme.primaryContainer,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      scheme.primary,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.check_rounded,
                                  size: 40,
                                  color: scheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        visualTitle,
                        semanticsLabel: title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          subtitle!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: tokens.mutedText),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: close,
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(actionLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single pulse when a countdown reaches its target.
class PulseRing extends StatelessWidget {
  const PulseRing({
    super.key,
    this.color,
    this.duration = const Duration(milliseconds: 850),
  });

  final Color? color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.tertiary;
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => Container(
          width: 180 + 220 * t,
          height: 180 + 220 * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: tint.withValues(alpha: (1 - t) * 0.5),
              width: 2.5 - 1.5 * t,
            ),
          ),
        ),
      ),
    );
  }
}
