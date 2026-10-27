import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// The app icon: a stroke that rises to a glowing point, with faint ripples
/// around it. Painted, so it stays sharp at any size. Matches web/icons/icon.svg.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
          boxShadow: [BoxShadow(color: const Color(0xFF18202F).withValues(alpha: 0.34), blurRadius: size * 0.42, offset: Offset(0, size * 0.16))],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(size * 0.22), child: CustomPaint(painter: _MarkPainter())),
      );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final k = s.width / 1024;
    canvas.drawRect(
      Offset.zero & s,
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(s.width, s.height), const [Color(0xFF37486A), Color(0xFF18202F)]),
    );
    final c = Offset(716 * k, 318 * k);
    final ring = Paint()
      ..color = const Color(0xFFF8F5EC).withValues(alpha: 0.085)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * k;
    for (var r = 150.0; r <= 865; r += 65) {
      canvas.drawCircle(c, r * k, ring);
    }
    final curve = Path()
      ..moveTo(170 * k, 812 * k)
      ..cubicTo(400 * k, 800 * k, 580 * k, 650 * k, 716 * k, 318 * k);
    canvas.drawPath(
      curve,
      Paint()
        ..shader = ui.Gradient.linear(Offset(170 * k, 812 * k), c, [const Color(0xFFF8F5EC).withValues(alpha: 0.18), const Color(0xFFF8F5EC).withValues(alpha: 0.9), const Color(0xFFFFFDF8)], const [0, 0.55, 1])
        ..style = PaintingStyle.stroke
        ..strokeWidth = 58 * k
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      c,
      190 * k,
      Paint()..shader = ui.Gradient.radial(c, 190 * k, [const Color(0xFFF1FFF1), const Color(0xFF9AD9A8), const Color(0xFF4A8B5A).withValues(alpha: 0.55), const Color(0xFF4A8B5A).withValues(alpha: 0)], const [0, 0.3, 0.62, 1]),
    );
    canvas.drawCircle(c, 40 * k, Paint()..color = const Color(0xFFF4FFF4));
  }

  @override
  bool shouldRepaint(_MarkPainter old) => false;
}
