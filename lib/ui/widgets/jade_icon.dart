import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Navigation and domain marks, drawn on the same 24dp grid.
/// At 20dp and below the accent fill is removed to keep the silhouette clear.
enum JadeGlyph {
  today,
  plan,
  groups,
  execute,
  focus,
  projects,
  records,
  protocols,
  growth,
  settings,
}

class JadeIcon extends StatelessWidget {
  const JadeIcon({
    super.key,
    required this.glyph,
    this.size = AppIconSize.md,
    this.color,
    this.monochrome = false,
    this.semanticLabel,
  });

  final JadeGlyph glyph;
  final double size;
  final Color? color;
  final bool monochrome;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final foreground =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    final icon = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _JadeIconPainter(
          glyph: glyph,
          color: foreground,
          accent: Theme.of(context).colorScheme.primary,
          monochrome: monochrome || size < AppIconSize.md,
        ),
      ),
    );
    if (semanticLabel == null) return icon;
    return Semantics(label: semanticLabel, image: true, child: icon);
  }
}

class _JadeIconPainter extends CustomPainter {
  const _JadeIconPainter({
    required this.glyph,
    required this.color,
    required this.accent,
    required this.monochrome,
  });

  final JadeGlyph glyph;
  final Color color;
  final Color accent;
  final bool monochrome;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final soft = Paint()
      ..color = accent.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final point = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    switch (glyph) {
      case JadeGlyph.today:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 3, 18, 18),
            const Radius.circular(3),
          ),
          line,
        );
        canvas.drawLine(const Offset(12, 3), const Offset(12, 21), line);
        canvas.drawLine(const Offset(3, 12), const Offset(21, 12), line);
        if (!monochrome) {
          canvas.drawCircle(const Offset(16.7, 7.3), 2.2, soft);
        }
        canvas.drawCircle(const Offset(16.7, 7.3), 0.9, point);
        break;
      case JadeGlyph.plan:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 2.5, 14, 19),
            const Radius.circular(2.8),
          ),
          line,
        );
        if (!monochrome) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(8, 6, 8, 3),
              const Radius.circular(1),
            ),
            soft,
          );
        }
        for (final y in [7.5, 12.0, 16.5]) {
          canvas.drawLine(Offset(8, y), Offset(16, y), line);
        }
        break;
      case JadeGlyph.groups:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2.5, 3, 8, 7),
            const Radius.circular(1.5),
          ),
          line,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(13.5, 3, 8, 7),
            const Radius.circular(1.5),
          ),
          line,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(8, 15, 8, 7),
            const Radius.circular(1.5),
          ),
          line,
        );
        canvas.drawLine(const Offset(6.5, 10), const Offset(6.5, 12), line);
        canvas.drawLine(const Offset(17.5, 10), const Offset(17.5, 12), line);
        canvas.drawLine(const Offset(6.5, 12), const Offset(17.5, 12), line);
        canvas.drawLine(const Offset(12, 12), const Offset(12, 15), line);
        if (!monochrome) {
          canvas.drawCircle(const Offset(12, 12), 1.7, soft);
        }
        break;
      case JadeGlyph.execute:
        canvas.drawCircle(const Offset(12, 13), 8, line);
        canvas.drawLine(const Offset(12, 2), const Offset(12, 5), line);
        canvas.drawLine(const Offset(9, 2), const Offset(15, 2), line);
        canvas.drawLine(const Offset(12, 13), const Offset(12, 8.5), line);
        canvas.drawLine(const Offset(12, 13), const Offset(15.5, 15), line);
        if (!monochrome) {
          canvas.drawCircle(const Offset(17.5, 7), 2, soft);
        }
        break;
      case JadeGlyph.focus:
        canvas.drawCircle(const Offset(11.5, 13), 7.5, line);
        canvas.drawLine(const Offset(11.5, 13), const Offset(11.5, 8.5), line);
        canvas.drawLine(const Offset(11.5, 13), const Offset(14.5, 14.5), line);
        final leaf = Path()
          ..moveTo(16, 6)
          ..quadraticBezierTo(17.5, 2, 21.5, 2)
          ..quadraticBezierTo(21.5, 6, 17.5, 7)
          ..close();
        if (!monochrome) canvas.drawPath(leaf, soft);
        canvas.drawPath(leaf, line);
        canvas.drawLine(const Offset(16.5, 7), const Offset(14.5, 9), line);
        break;
      case JadeGlyph.projects:
        final folder = Path()
          ..moveTo(2.5, 7)
          ..quadraticBezierTo(2.5, 5, 4.5, 5)
          ..lineTo(9, 5)
          ..lineTo(11, 7.2)
          ..lineTo(19.5, 7.2)
          ..quadraticBezierTo(21.5, 7.2, 21.5, 9.2)
          ..lineTo(21.5, 18.5)
          ..quadraticBezierTo(21.5, 20.5, 19.5, 20.5)
          ..lineTo(4.5, 20.5)
          ..quadraticBezierTo(2.5, 20.5, 2.5, 18.5)
          ..close();
        if (!monochrome) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(12, 10, 6, 7),
              const Radius.circular(1.5),
            ),
            soft,
          );
        }
        canvas.drawPath(folder, line);
        break;
      case JadeGlyph.records:
        final book = Path()
          ..moveTo(12, 5.5)
          ..quadraticBezierTo(8.7, 3.5, 3, 4.5)
          ..lineTo(3, 18.5)
          ..quadraticBezierTo(8.5, 17.5, 12, 20)
          ..quadraticBezierTo(15.5, 17.5, 21, 18.5)
          ..lineTo(21, 4.5)
          ..quadraticBezierTo(15.3, 3.5, 12, 5.5);
        canvas.drawPath(book, line);
        canvas.drawLine(const Offset(12, 5.5), const Offset(12, 20), line);
        if (!monochrome) {
          canvas.drawCircle(const Offset(17, 8), 2.1, soft);
        }
        break;
      case JadeGlyph.protocols:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 2.5, 16, 19),
            const Radius.circular(2.5),
          ),
          line,
        );
        canvas.drawLine(const Offset(7.5, 3), const Offset(7.5, 21), line);
        final bookmark = Path()
          ..moveTo(12, 3)
          ..lineTo(12, 12)
          ..lineTo(15, 10)
          ..lineTo(18, 12)
          ..lineTo(18, 3);
        if (!monochrome) canvas.drawPath(bookmark, soft);
        canvas.drawPath(bookmark, line);
        canvas.drawLine(const Offset(11, 16), const Offset(17, 16), line);
        break;
      case JadeGlyph.growth:
        canvas.drawLine(const Offset(12, 21), const Offset(12, 8), line);
        canvas.drawLine(const Offset(12, 15), const Offset(7.5, 11.5), line);
        canvas.drawLine(const Offset(12, 12), const Offset(16.5, 8.5), line);
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(7, 8.5), width: 8, height: 5),
          line,
        );
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(17, 6), width: 8, height: 5),
          line,
        );
        if (!monochrome) canvas.drawCircle(const Offset(12, 19), 2.2, soft);
        break;
      case JadeGlyph.settings:
        canvas.drawCircle(const Offset(12, 12), 6.5, line);
        canvas.drawCircle(const Offset(12, 12), 2.5, line);
        for (var index = 0; index < 8; index++) {
          final angle = index * math.pi / 4;
          final dx = math.cos(angle);
          final dy = math.sin(angle);
          canvas.drawLine(
            Offset(12 + dx * 8, 12 + dy * 8),
            Offset(12 + dx * 10, 12 + dy * 10),
            line,
          );
        }
        if (!monochrome) canvas.drawCircle(const Offset(12, 12), 1.1, soft);
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _JadeIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.accent != accent ||
      oldDelegate.monochrome != monochrome;
}
