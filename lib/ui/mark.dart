import 'package:flutter/widgets.dart';

/// The app icon: three rising bars under an arrow that points up and to the
/// right. Painted, so it stays sharp at any size. Matches web/icons/icon.svg.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
          border: Border.all(color: const Color(0x1416170F), width: 1),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
          boxShadow: [BoxShadow(color: const Color(0xFF18202F).withValues(alpha: 0.2), blurRadius: size * 0.42, offset: Offset(0, size * 0.16))],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(size * 0.22), child: CustomPaint(painter: _MarkPainter())),
      );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final k = s.width / 1024;
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFFFFFFF));
    canvas.translate(0, 60 * k);
    final bar = Paint()..color = const Color(0xFF1E2536);
    for (final (x, y, h) in const [(212.0, 600.0, 224.0), (428.0, 468.0, 356.0), (644.0, 336.0, 488.0)]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x * k, y * k, 168 * k, h * k), Radius.circular(34 * k)), bar);
    }
    final arrow = Paint()
      ..color = const Color(0xFF14683C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 76 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(212 * k, 452 * k)
        ..lineTo(430 * k, 270 * k)
        ..lineTo(560 * k, 332 * k)
        ..lineTo(792 * k, 128 * k),
      arrow,
    );
    canvas.drawPath(
      Path()
        ..moveTo(668 * k, 118 * k)
        ..lineTo(800 * k, 118 * k)
        ..lineTo(800 * k, 250 * k),
      arrow,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => false;
}
