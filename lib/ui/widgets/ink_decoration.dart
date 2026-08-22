import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'common.dart';

// ══════════════════════════════════════════════════════════════════════════
// 现代组件集：几何 Logo · 简洁加载动画 · 标签徽章
// （v2 翠绿·锐意：水墨装饰组件已全部移除，背景 = 纯 canvas）
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
      oldDelegate.surfaceColor != surfaceColor ||
      oldDelegate.accentColor != accentColor;
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

// ─── 标签（Tag）───
enum TagSize {
  normal(22, 7, 12),
  small(20, 6, 11);

  const TagSize(this.height, this.hPadding, this.fontSize);
  final double height;
  final double hPadding;
  final double fontSize;
}

/// 通用标签：22px 高、5px 圆角实色。
class Tag extends StatelessWidget {
  const Tag({
    super.key,
    required this.label,
    this.color,
    this.size = TagSize.normal,
  });

  final String label;
  final Color? color;
  final TagSize size;

  static const normal = TagSize.normal;
  static const small = TagSize.small;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.primaryContainer;
    final fg = color != null
        ? bestContrastingText(bg)
        : scheme.onPrimaryContainer;
    return Container(
      height: size.height,
      padding: EdgeInsets.symmetric(horizontal: size.hPadding),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.control),
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
}

/// 兼容别名：v1 水墨命名迁移期保留。
@Deprecated('Use Tag instead.')
class BambooChip extends Tag {
  const BambooChip({
    super.key,
    required super.label,
    super.color,
    super.size = TagSize.normal,
  });
}

// ─── 状态标签（现代圆角样式）───
class SealStatusLabel extends StatelessWidget {
  const SealStatusLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = context.tokens.sealColor;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.control),
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
