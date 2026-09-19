import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 专注计时结束的仪式感覆盖层：
/// 弹性放大的对勾徽章 + 扩散光环 + 彩纸粒子 + 文案浮入。
class FocusCelebration extends StatefulWidget {
  const FocusCelebration({
    super.key,
    required this.title,
    this.subtitle,
    this.duration = const Duration(milliseconds: 1800),
  });

  final String title;
  final String? subtitle;
  final Duration duration;

  @override
  State<FocusCelebration> createState() => _FocusCelebrationState();
}

class _FocusCelebrationState extends State<FocusCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    if (MediaQuery.disableAnimationsOf(context)) {
      return ColoredBox(
        color: scheme.scrim.withValues(alpha: 0.55),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 46,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: tokens.mutedText),
                ),
            ],
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return ColoredBox(
          color: scheme.scrim.withValues(alpha: 0.32 * math.min(1, t * 4)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 双层扩散光环
              for (final interval in const [(0.0, 0.55), (0.12, 0.7)])
                () {
                  final local =
                      ((t - interval.$1) / (interval.$2 - interval.$1)).clamp(
                        0.0,
                        1.0,
                      );
                  if (local <= 0 || local >= 1) return const SizedBox.shrink();
                  return Container(
                    width: 120 + 240 * local,
                    height: 120 + 240 * local,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.primary.withValues(
                          alpha: (1 - local) * 0.42,
                        ),
                        width: 2,
                      ),
                    ),
                  );
                }(),
              // 彩纸粒子
              CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(
                  progress: ((t - 0.08) / 0.92).clamp(0.0, 1.0),
                  colors: [
                    scheme.primary,
                    scheme.tertiary,
                    tokens.reward,
                    tokens.info,
                  ],
                ),
              ),
              // 对勾徽章：弹性放大 + 轻微上浮
              Transform.translate(
                offset: Offset(
                  0,
                  -26 -
                      6 *
                          Curves.easeOutCubic.transform(
                            ((t - 0.05) / 0.5).clamp(0.0, 1.0),
                          ),
                ),
                child: Transform.scale(
                  scale: Curves.elasticOut.transform(
                    ((t - 0.05) / 0.55).clamp(0.0, 1.0),
                  ),
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 46,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // 文案浮入
              Padding(
                padding: const EdgeInsets.only(top: 150),
                child: Opacity(
                  opacity: Curves.easeOut.transform(
                    ((t - 0.38) / 0.3).clamp(0.0, 1.0),
                  ),
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      12 *
                          (1 -
                              Curves.easeOut.transform(
                                ((t - 0.38) / 0.3).clamp(0.0, 1.0),
                              )),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.subtitle!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: tokens.mutedText),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 彩纸粒子画笔：从中心向四周抛撒的小方片，带重力下坠与淡出。
class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  static const _particles = 22;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final random = math.Random(20260816);
    final center = size.center(Offset.zero);
    for (var i = 0; i < _particles; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final speed = 90 + random.nextDouble() * 170;
      final travel = Curves.easeOutCubic.transform(progress);
      final gravity = 190 * progress * progress;
      final offset = Offset(
        center.dx + math.cos(angle) * speed * travel,
        center.dy + math.sin(angle) * speed * travel * 0.72 + gravity,
      );
      final particleSize = 4.0 + random.nextDouble() * 4;
      final opacity = (1 - progress) * 0.9;
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(angle + progress * (random.nextBool() ? 5 : -5));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: particleSize,
            height: particleSize * 0.6,
          ),
          Radius.circular(particleSize * 0.22),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 单圈扩散脉冲：用于倒计时到达目标时围绕计时器的轻量提示。
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
