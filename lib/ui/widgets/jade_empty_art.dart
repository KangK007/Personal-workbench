import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Small code-native line art shared by empty states. The page icon carries the
/// meaning; the leaves and ruled frame only add the quiet Jade visual language.
class JadeEmptyArt extends StatelessWidget {
  const JadeEmptyArt({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final jade = scheme.primary;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: const Size.square(72),
                painter: _JadeEmptyPainter(
                  line: jade.withValues(alpha: 0.72),
                  softLine: jade.withValues(alpha: 0.32),
                  wash: context.accents.moss.container,
                ),
              ),
            ),
            Icon(icon, size: 27, color: jade),
          ],
        ),
      ),
    );
  }
}

class _JadeEmptyPainter extends CustomPainter {
  const _JadeEmptyPainter({
    required this.line,
    required this.softLine,
    required this.wash,
  });

  final Color line;
  final Color softLine;
  final Color wash;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 72;
    canvas.save();
    canvas.scale(scale);
    final fill = Paint()..color = wash;
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final softStroke = Paint()
      ..color = softLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(13, 13, 46, 46),
        const Radius.circular(13),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(13, 13, 46, 46),
        const Radius.circular(13),
      ),
      softStroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(10, 55)
        ..quadraticBezierTo(4, 47, 7, 36),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(7, 41)
        ..quadraticBezierTo(2, 34, 5, 28)
        ..quadraticBezierTo(12, 31, 12, 38)
        ..quadraticBezierTo(10, 41, 7, 41),
      softStroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(62, 55)
        ..quadraticBezierTo(68, 47, 65, 36),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(65, 41)
        ..quadraticBezierTo(70, 34, 67, 28)
        ..quadraticBezierTo(60, 31, 60, 38)
        ..quadraticBezierTo(62, 41, 65, 41),
      softStroke,
    );
    canvas.drawLine(const Offset(27, 65), const Offset(45, 65), softStroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _JadeEmptyPainter oldDelegate) =>
      line != oldDelegate.line ||
      softLine != oldDelegate.softLine ||
      wash != oldDelegate.wash;
}
