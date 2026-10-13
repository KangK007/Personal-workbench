import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Static edge ornament. It is drawn at the display size, so it adds no
/// decoded bitmap memory and never runs an animation behind work content.
class JadeBotanicalEdge extends StatelessWidget {
  const JadeBotanicalEdge({
    super.key,
    this.width = 64,
    this.height = 40,
    this.compact = false,
  });

  final double width;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _BotanicalPainter(
            color: context.accents.jade.color.withValues(alpha: 0.08),
            compact: compact,
          ),
        ),
      ),
    ),
  );
}

class _BotanicalPainter extends CustomPainter {
  const _BotanicalPainter({required this.color, required this.compact});

  final Color color;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 60);
    final stem = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    final leafFill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(89, 61)
      ..cubicTo(74, 40, 64, 25, 49, 7);
    canvas.drawPath(path, stem);
    _leaf(canvas, leafFill, const Offset(75, 42), const Offset(92, 20), 7);
    _leaf(canvas, leafFill, const Offset(66, 31), const Offset(48, 25), 6);
    if (!compact) {
      _leaf(canvas, leafFill, const Offset(57, 17), const Offset(71, 2), 5);
      final branch = Path()
        ..moveTo(88, 60)
        ..quadraticBezierTo(64, 52, 45, 51);
      canvas.drawPath(branch, stem);
      _leaf(canvas, leafFill, const Offset(61, 52), const Offset(47, 38), 6);
      _leaf(canvas, leafFill, const Offset(52, 51), const Offset(36, 57), 4.5);
    }
    canvas.restore();
  }

  void _leaf(
    Canvas canvas,
    Paint paint,
    Offset base,
    Offset tip,
    double width,
  ) {
    final delta = tip - base;
    final length = math.sqrt(delta.dx * delta.dx + delta.dy * delta.dy);
    final normal = Offset(-delta.dy / length, delta.dx / length) * width;
    final middle = Offset.lerp(base, tip, 0.53)!;
    final leaf = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(
        middle.dx + normal.dx,
        middle.dy + normal.dy,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        middle.dx - normal.dx,
        middle.dy - normal.dy,
        base.dx,
        base.dy,
      )
      ..close();
    canvas.drawPath(leaf, paint);
  }

  @override
  bool shouldRepaint(covariant _BotanicalPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.compact != compact;
}
