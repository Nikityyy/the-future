import 'package:flutter/widgets.dart';

import '../theme.dart';

/// The app icon: a navy tile with the curve that ends in a glowing point.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: C.navy,
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [BoxShadow(color: C.navy.withValues(alpha: 0.28), blurRadius: size * 0.4, offset: Offset(0, size * 0.14))],
        ),
        child: CustomPaint(painter: _MarkPainter()),
      );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final path = Path()
      ..moveTo(w * 0.2, w * 0.74)
      ..cubicTo(w * 0.42, w * 0.72, w * 0.58, w * 0.6, w * 0.74, w * 0.28);
    canvas.drawPath(
      path,
      Paint()
        ..color = C.ground
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.07
        ..strokeCap = StrokeCap.round,
    );
    final end = Offset(w * 0.74, w * 0.28);
    canvas.drawCircle(end, w * 0.15, Paint()..color = const Color(0xFF7BC08B).withValues(alpha: 0.25));
    canvas.drawCircle(end, w * 0.075, Paint()..color = const Color(0xFF7BC08B));
  }

  @override
  bool shouldRepaint(_MarkPainter old) => false;
}
