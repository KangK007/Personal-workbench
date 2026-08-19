import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════════════════
// 现代装饰组件集：几何Logo · 清爽背景 · 简洁分割线 · 现代加载动画
// ══════════════════════════════════════════════════════════════════════════

// ─── 几何 Logo ───
// 左上角项目 Logo，翠绿圆角方形 + 简洁几何图形
class SealLogo extends StatelessWidget {
  const SealLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = context.tokens.sealColor;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _SealLogoPainter(
          primaryColor: color,
          surfaceColor: context.tokens.panel,
          accentColor: context.tokens.gold,
        ),
      ),
    );
  }
}

class _SealLogoPainter extends CustomPainter {
  const _SealLogoPainter({
    required this.primaryColor,
    required this.surfaceColor,
    required this.accentColor,
  });

  final Color primaryColor;
  final Color surfaceColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * 0.22;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    // 主背景渐变
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
      ).createShader(rect.outerRect);
    canvas.drawRRect(rect, bgPaint);

    // 几何图形：重叠圆形（代表工作台的模块化）
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final circleRadius = size.width * 0.18;

    final outlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = size.width * 0.04
      ..style = PaintingStyle.stroke;

    // 左上圆
    canvas.drawCircle(
      Offset(center.dx - size.width * 0.1, center.dy - size.width * 0.1),
      circleRadius * 0.7,
      outlinePaint,
    );

    // 右下圆
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.1, center.dy + size.width * 0.1),
      circleRadius * 0.7,
      outlinePaint,
    );

    // 中心点
    final dotPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width * 0.06, dotPaint);

    // 顶部高光
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final highlightPath = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(
        Offset(size.width - radius, 0),
        radius: Radius.circular(radius),
      )
      ..lineTo(size.width, radius)
      ..arcToPoint(
        Offset(size.width - radius, 0),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _SealLogoPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.surfaceColor != surfaceColor;
}

// ─── 清爽背景暗纹 ───
// 极淡的几何网格点阵，现代工作台底纹
class LandscapePattern extends StatelessWidget {
  const LandscapePattern({
    super.key,
    this.width = double.infinity,
    this.height = 200,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _LandscapePainter(
            dotColor: theme.colorScheme.primary.withValues(
              alpha: isDark ? 0.06 : 0.04,
            ),
            accentColor: context.tokens.gold.withValues(alpha: 0.05),
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

class _LandscapePainter extends CustomPainter {
  const _LandscapePainter({
    required this.dotColor,
    required this.accentColor,
    required this.isDark,
  });

  final Color dotColor;
  final Color accentColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = dotColor;
    final spacing = 24.0;
    final rand = math.Random(7);

    for (var y = 0.0; y < size.height; y += spacing) {
      for (var x = 0.0; x < size.width; x += spacing) {
        final offset = rand.nextDouble() * 2 - 1;
        canvas.drawCircle(Offset(x + offset, y + offset), 1.2, dotPaint);
      }
    }

    // 装饰性弧线
    final arcPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final arcPath = Path()
      ..moveTo(size.width * 0.6, size.height * 0.3)
      ..cubicTo(
        size.width * 0.75,
        size.height * 0.15,
        size.width * 0.85,
        size.height * 0.4,
        size.width,
        size.height * 0.25,
      );
    canvas.drawPath(arcPath, arcPaint);

    // 点缀光点
    final glowPaint = Paint()..color = accentColor;
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.2),
      2.5,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LandscapePainter oldDelegate) =>
      oldDelegate.dotColor != dotColor ||
      oldDelegate.accentColor != accentColor;
}

// ─── 简洁分割线 ───
class InkBrushDivider extends StatelessWidget {
  const InkBrushDivider({super.key, this.width = double.infinity});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 1,
      child: CustomPaint(
        painter: _InkBrushDividerPainter(
          color: context.tokens.divider,
          accent: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

class _InkBrushDividerPainter extends CustomPainter {
  const _InkBrushDividerPainter({required this.color, required this.accent});

  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(covariant _InkBrushDividerPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accent != accent;
}

// ─── 现代加载动画 ───
class InkRippleLoader extends StatefulWidget {
  const InkRippleLoader({super.key, this.size = 60, this.color});

  final double size;
  final Color? color;

  @override
  State<InkRippleLoader> createState() => _InkRippleLoaderState();
}

class _InkRippleLoaderState extends State<InkRippleLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _InkRipplePainter(
              progress: _controller.value,
              color: color,
            ),
          );
        },
      ),
    );
  }
}

class _InkRipplePainter extends CustomPainter {
  const _InkRipplePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 中心点
    canvas.drawCircle(
      center,
      size.width * 0.08,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill,
    );

    // 三层涟漪
    for (var layer = 0; layer < 3; layer++) {
      final layerProgress = (progress + layer * 0.33) % 1.0;
      final radius = size.width * 0.15 + layerProgress * size.width * 0.35;
      final fade = (1.0 - layerProgress);
      final alpha = fade * fade * 0.35;

      final paint = Paint()
        ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..strokeWidth = 2.0 * (1.0 - layerProgress * 0.5)
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InkRipplePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ─── 现代标签/徽章 ───
class BambooChip extends StatelessWidget {
  const BambooChip({
    super.key,
    required this.label,
    this.color,
    this.size = ChipSize.normal,
  });

  final String label;
  final Color? color;
  final ChipSize size;

  static const normal = ChipSize.normal;
  static const small = ChipSize.small;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).colorScheme.primaryContainer;
    final fg = color != null
        ? _bestContrast(bg)
        : Theme.of(context).colorScheme.onPrimaryContainer;
    return Container(
      height: size.height,
      padding: EdgeInsets.symmetric(horizontal: size.hPadding),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: size.fontSize,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _bestContrast(Color bg) {
    const dark = Color(0xFF1A1D29);
    const light = Color(0xFFF8FAFC);
    double contrast(Color fg) {
      final l = math.max(fg.computeLuminance(), bg.computeLuminance());
      final d = math.min(fg.computeLuminance(), bg.computeLuminance());
      return (l + 0.05) / (d + 0.05);
    }

    return contrast(dark) >= contrast(light) ? dark : light;
  }
}

enum ChipSize {
  normal(24, 8, 12),
  small(20, 6, 11);

  const ChipSize(this.height, this.hPadding, this.fontSize);
  final double height;
  final double hPadding;
  final double fontSize;
}

// ─── 状态标签（现代圆角样式） ───
class SealStatusLabel extends StatelessWidget {
  const SealStatusLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = context.tokens.sealColor;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── 背景纹理 ───
// 极淡的网格点阵，现代工作台底纹质感
class SilkTexture extends StatelessWidget {
  const SilkTexture({super.key, this.opacity});

  final double? opacity;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final base = context.tokens.divider;
    final alpha = opacity ?? (isLight ? 0.3 : 0.2);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _SilkTexturePainter(
            color: base.withValues(alpha: alpha),
            spacing: isLight ? 20.0 : 24.0,
          ),
        ),
      ),
    );
  }
}

class _SilkTexturePainter extends CustomPainter {
  const _SilkTexturePainter({required this.color, required this.spacing});

  final Color color;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    // 极淡水平线
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SilkTexturePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.spacing != spacing;
}

// ─── 底部装饰渐变 ───
// 页面底部淡淡的渐变装饰
class InkHorizon extends StatelessWidget {
  const InkHorizon({super.key, this.height = 90});

  final double height;

  @override
  Widget build(BuildContext context) {
    final wash = context.tokens.washColor;
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _InkHorizonPainter(washColor: wash)),
      ),
    );
  }
}

class _InkHorizonPainter extends CustomPainter {
  const _InkHorizonPainter({required this.washColor});

  final Color washColor;

  @override
  void paint(Canvas canvas, Size size) {
    // 从透明到淡色的渐变
    final gradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          washColor.withValues(alpha: 0),
          washColor.withValues(alpha: 0.03),
          washColor.withValues(alpha: 0.01),
        ],
        stops: const [0.0, 0.62, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, gradient);
  }

  @override
  bool shouldRepaint(covariant _InkHorizonPainter oldDelegate) =>
      oldDelegate.washColor != washColor;
}
