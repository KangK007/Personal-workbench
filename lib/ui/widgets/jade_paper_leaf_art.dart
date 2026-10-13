import 'package:flutter/material.dart';

/// Static paper and leaf art shared by the small hero illustrations.
class JadePaperLeafArt extends StatelessWidget {
  const JadePaperLeafArt({
    super.key,
    required this.icon,
    required this.accent,
    required this.wash,
    required this.paper,
    required this.border,
    this.showGrowthBars = false,
  });

  final IconData icon;
  final Color accent;
  final Color wash;
  final Color paper;
  final Color border;
  final bool showGrowthBars;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 128,
    height: 96,
    child: CustomPaint(
      painter: _PaperLeafPainter(
        accent: accent,
        wash: wash,
        paper: paper,
        border: border,
        showGrowthBars: showGrowthBars,
      ),
      child: Align(
        alignment: const Alignment(-0.27, -0.18),
        child: Icon(icon, size: 27, color: accent),
      ),
    ),
  );
}

class _PaperLeafPainter extends CustomPainter {
  const _PaperLeafPainter({
    required this.accent,
    required this.wash,
    required this.paper,
    required this.border,
    required this.showGrowthBars,
  });

  final Color accent;
  final Color wash;
  final Color paper;
  final Color border;
  final bool showGrowthBars;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 128, size.height / 96);
    final leafFill = Paint()..color = accent.withValues(alpha: 0.24);
    final stem = Paint()
      ..color = accent.withValues(alpha: 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = accent.withValues(alpha: 0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawOval(
      const Rect.fromLTWH(14, 11, 102, 78),
      Paint()..color = wash.withValues(alpha: 0.72),
    );
    canvas.save();
    canvas.translate(39, 16);
    canvas.rotate(-0.13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 68, 66),
        const Radius.circular(11),
      ),
      Paint()..color = wash,
    );
    canvas.restore();
    final sheet = RRect.fromRectAndRadius(
      const Rect.fromLTWH(24, 13, 68, 68),
      const Radius.circular(11),
    );
    canvas.drawRRect(sheet, Paint()..color = paper);
    canvas.drawRRect(
      sheet,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (showGrowthBars) {
      for (final (x, y, height) in [
        (39.0, 67.0, 9.0),
        (53.0, 61.0, 15.0),
        (67.0, 54.0, 22.0),
      ]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 7, height),
            const Radius.circular(3),
          ),
          Paint()..color = accent.withValues(alpha: 0.5),
        );
      }
    } else {
      canvas.drawLine(const Offset(39, 63), const Offset(74, 63), line);
      canvas.drawLine(const Offset(39, 70), const Offset(64, 70), line);
    }

    canvas.drawPath(
      Path()
        ..moveTo(81, 89)
        ..cubicTo(91, 71, 100, 53, 106, 31),
      stem,
    );
    _leaf(canvas, leafFill, const Offset(91, 71), const Offset(109, 61), 7);
    _leaf(canvas, leafFill, const Offset(99, 52), const Offset(86, 38), 6);
    _leaf(canvas, leafFill, const Offset(105, 36), const Offset(116, 22), 5);
    canvas.restore();
  }

  void _leaf(
    Canvas canvas,
    Paint paint,
    Offset base,
    Offset tip,
    double halfWidth,
  ) {
    final middle = Offset.lerp(base, tip, 0.55)!;
    final delta = tip - base;
    final normal =
        Offset(-delta.dy / delta.distance, delta.dx / delta.distance) *
        halfWidth;
    canvas.drawPath(
      Path()
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
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PaperLeafPainter oldDelegate) =>
      accent != oldDelegate.accent ||
      wash != oldDelegate.wash ||
      paper != oldDelegate.paper ||
      border != oldDelegate.border ||
      showGrowthBars != oldDelegate.showGrowthBars;
}
