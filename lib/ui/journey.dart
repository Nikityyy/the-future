import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../theme.dart';

/// Today on the left, the future on the right, and the stroke between them
/// that rises to a glowing point. The same stroke as the app icon.
class Journey extends StatelessWidget {
  const Journey({super.key, required this.today, required this.future, required this.caption});

  final String today;
  final String future;
  final String caption;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 300,
        height: 250,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _JourneyPainter())),
            Positioned(
              right: 0,
              top: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(caption, style: sans(11.5, weight: FontWeight.w500, color: C.ink2, tracking: 1.4)),
                  const SizedBox(height: 2),
                  Text(future, style: figures(serif(52, color: C.greenInk, tracking: -1.6)), maxLines: 1),
                ],
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TODAY', style: sans(11.5, weight: FontWeight.w500, color: C.ink2, tracking: 1.4)),
                  const SizedBox(height: 2),
                  Text(today, style: figures(serif(30, tracking: -0.8)), maxLines: 1),
                ],
              ),
            ),
          ],
        ),
      );
}

class _JourneyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final a = Offset(s.width * 0.04, s.height * 0.66), b = Offset(s.width * 0.9, s.height * 0.4);
    canvas.drawLine(Offset(0, s.height * 0.78), Offset(s.width, s.height * 0.78), Paint()..color = C.ink.withValues(alpha: 0.12)..strokeWidth = 1);
    final p = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(s.width * 0.45, s.height * 0.66, s.width * 0.7, s.height * 0.58, b.dx, b.dy);
    // Soft fill under the stroke.
    final fill = Path.from(p)..lineTo(b.dx, s.height * 0.78)..lineTo(a.dx, s.height * 0.78)..close();
    canvas.drawPath(fill, Paint()..shader = ui.Gradient.linear(Offset(0, s.height * 0.4), Offset(0, s.height * 0.78), [C.green.withValues(alpha: 0.22), C.green.withValues(alpha: 0)]));
    canvas.drawPath(p, Paint()..color = C.greenInk..style = PaintingStyle.stroke..strokeWidth = 3.4..strokeCap = StrokeCap.round);
    canvas.drawCircle(b, 26, Paint()..shader = ui.Gradient.radial(b, 26, [C.green.withValues(alpha: 0.5), C.green.withValues(alpha: 0)]));
    canvas.drawCircle(b, 6.5, Paint()..color = C.greenInk);
    canvas.drawCircle(a, 4.5, Paint()..color = C.ground..style = PaintingStyle.fill);
    canvas.drawCircle(a, 4.5, Paint()..color = C.ink..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_JourneyPainter old) => false;
}
