import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'common.dart';

// ══════════════════════════════════════════════════════════════════════════
// 个人航行日志组件：日志页标记 · 简洁加载动画 · 标签徽章
// ══════════════════════════════════════════════════════════════════════════

// ─── 日志页 Logo ───
class SealLogo extends StatelessWidget {
  const SealLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = context.tokens.route;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _SealLogoPainter(
          primaryColor: color,
          surfaceColor: context.tokens.panel,
          accentColor: context.tokens.marker,
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

    canvas.drawRRect(rect, Paint()..color = primaryColor);

    final page = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.2,
        size.height * 0.14,
        size.width * 0.62,
        size.height * 0.72,
      ),
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(page, Paint()..color = surfaceColor);

    final routePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final route = Path()
      ..moveTo(size.width * 0.34, size.height * 0.3)
      ..lineTo(size.width * 0.61, size.height * 0.48)
      ..lineTo(size.width * 0.43, size.height * 0.69);
    canvas.drawPath(route, routePaint);

    final nodePaint = Paint()..color = primaryColor;
    for (final node in [
      Offset(size.width * 0.34, size.height * 0.3),
      Offset(size.width * 0.43, size.height * 0.69),
    ]) {
      canvas.drawCircle(node, size.width * 0.055, nodePaint);
    }
    canvas.drawCircle(
      Offset(size.width * 0.61, size.height * 0.48),
      size.width * 0.065,
      Paint()..color = accentColor,
    );
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
    final color = context.tokens.route;
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
