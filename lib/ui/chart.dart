import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../format.dart';
import '../platform/haptics.dart';
import '../theme.dart';
import 'basics.dart';

/// The growth curve with its band between the cautious and the hopeful case.
/// The picked scenario is the bold line; drag a finger along it to read a month.
class GrowthChart extends StatefulWidget {
  const GrowthChart({super.key, required this.low, required this.mid, required this.high, required this.start, required this.years, required this.restartKey, this.height = 280, this.interactive = true});

  final List<double> low;
  final List<double> mid;
  final List<double> high;
  final DateTime start;
  final int years;

  /// The chart draws itself again when this changes.
  final Object restartKey;

  final double height;

  /// Whether a finger dragged along it reads a month.
  final bool interactive;

  @override
  State<GrowthChart> createState() => _GrowthChartState();
}

class _GrowthChartState extends State<GrowthChart> with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  int? _scrub;
  bool _first = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_first) {
      _first = false;
      reducedMotion(context) ? _draw.value = 1 : _draw.forward();
    }
  }

  @override
  void didUpdateWidget(GrowthChart old) {
    super.didUpdateWidget(old);
    if (old.restartKey != widget.restartKey && !reducedMotion(context)) _draw.forward(from: 0.25);
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  void _scrubTo(double dx, double width) {
    final n = widget.mid.length - 1;
    final plotW = width - _Painter.left;
    final i = (((dx - _Painter.left) / plotW) * n).round().clamp(0, n);
    if (i != _scrub) {
      Haptics.selection();
      setState(() => _scrub = i);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: widget.interactive ? (d) => _scrubTo(d.localPosition.dx, box.maxWidth) : null,
          onHorizontalDragUpdate: widget.interactive ? (d) => _scrubTo(d.localPosition.dx, box.maxWidth) : null,
          onHorizontalDragEnd: widget.interactive ? (_) => setState(() => _scrub = null) : null,
          onHorizontalDragCancel: widget.interactive ? () => setState(() => _scrub = null) : null,
          child: Semantics(
            label: 'Growth chart. In ${widget.years} years: ${eur(widget.low.last)} cautious, ${eur(widget.mid.last)} expected, ${eur(widget.high.last)} hopeful.',
            child: AnimatedBuilder(
              animation: _draw,
              builder: (context, _) => CustomPaint(
                size: Size(box.maxWidth, widget.height),
                painter: _Painter(
                  low: widget.low,
                  mid: widget.mid,
                  high: widget.high,
                  start: widget.start,
                  years: widget.years,
                  progress: Curves.easeOutCubic.transform(_draw.value),
                  scrub: _scrub,
                ),
              ),
            ),
          ),
        ),
      );
}

class _Painter extends CustomPainter {
  _Painter({required this.low, required this.mid, required this.high, required this.start, required this.years, required this.progress, required this.scrub});

  static const left = 46.0;
  static const _top = 12.0;
  static const _bottom = 30.0;

  final List<double> low, mid, high;
  final DateTime start;
  final int years;
  final double progress;
  final int? scrub;

  static double _niceMax(double v) {
    if (v <= 0) return 1000;
    final e = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in [1.0, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]) {
      if (m * e >= v * 1.04) return m * e;
    }
    return 10 * e;
  }

  static String _short(double v) => hideAmounts ? '•••' : v >= 1e6 ? '€${(v / 1e6).toStringAsFixed(v >= 1e7 ? 0 : 1)}M' : v >= 1000 ? '€${(v / 1000).round()}K' : '€${v.round()}';

  @override
  void paint(Canvas canvas, Size size) {
    final n = mid.length - 1;
    final yMax = _niceMax(high.reduce(math.max));
    final plot = Rect.fromLTRB(left, _top, size.width - 14, size.height - _bottom);
    double x(int i) => plot.left + plot.width * i / n;
    double y(double v) => plot.bottom - plot.height * (v / yMax).clamp(0, 1);

    // Grid and labels.
    final grid = Paint()
      ..color = C.ink.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var g = 0; g <= 4; g++) {
      final v = yMax * g / 4;
      final gy = y(v);
      _dotted(canvas, Offset(plot.left, gy), Offset(plot.right, gy), grid);
      _text(canvas, _short(v), Offset(plot.left - 8, gy), C.ink3, align: 1);
    }
    _text(canvas, 'Now', Offset(plot.left, plot.bottom + 10), C.ink3, align: 0, below: true);
    _text(canvas, '${start.year + years}', Offset(plot.right, plot.bottom + 10), C.ink3, align: 2, below: true);

    final last = (n * progress).floor().clamp(1, n);
    Path line(List<double> s) {
      final p = Path()..moveTo(x(0), y(s[0]));
      for (var i = 1; i <= last; i++) {
        p.lineTo(x(i), y(s[i]));
      }
      return p;
    }

    // Band between cautious and hopeful.
    final band = Path()..moveTo(x(0), y(high[0]));
    for (var i = 1; i <= last; i++) {
      band.lineTo(x(i), y(high[i]));
    }
    for (var i = last; i >= 0; i--) {
      band.lineTo(x(i), y(low[i]));
    }
    band.close();
    canvas.drawPath(band, Paint()..color = C.green.withValues(alpha: 0.11));

    for (final s in [low, high]) {
      canvas.drawPath(
        line(s),
        Paint()
          ..color = C.green.withValues(alpha: 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // The expected line and the glow under it.
    final mainPath = line(mid);
    final fill = Path.from(mainPath)
      ..lineTo(x(last), plot.bottom)
      ..lineTo(x(0), plot.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..shader = ui.Gradient.linear(Offset(0, plot.top), Offset(0, plot.bottom), [C.green.withValues(alpha: 0.2), C.green.withValues(alpha: 0)]),
    );
    canvas.drawPath(
      mainPath,
      Paint()
        ..color = C.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // The point: at the end, or under the finger.
    final i = scrub ?? last;
    final pt = Offset(x(i), y(mid[i]));
    canvas.drawCircle(pt, 18, Paint()..shader = ui.Gradient.radial(pt, 18, [C.green.withValues(alpha: 0.38), C.green.withValues(alpha: 0)]));
    canvas.drawCircle(pt, 5.2, Paint()..color = C.ground);
    canvas.drawCircle(pt, 4, Paint()..color = C.green);

    if (scrub != null) {
      canvas.drawLine(Offset(pt.dx, plot.top), Offset(pt.dx, plot.bottom), Paint()..color = C.ink.withValues(alpha: 0.18));
      final date = DateTime(start.year, start.month + scrub!);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      _tip(canvas, size, pt.dx, '${months[date.month - 1]} ${date.year}', eur(mid[i]), '${eur(low[i])} to ${eur(high[i])}');
    }
  }

  void _tip(Canvas canvas, Size size, double cx, String a, String b, String c) {
    final faded = C.ground.withValues(alpha: 0.7);
    final tps = [
      for (final e in [(a, sans(12, color: faded)), (b, figures(serif(22, color: C.ground, tracking: -0.4))), (c, figures(sans(11.5, color: faded)))])
        TextPainter(text: TextSpan(text: e.$1, style: e.$2), textDirection: TextDirection.ltr)..layout(),
    ];
    final w = tps.map((t) => t.width).reduce(math.max) + 24;
    final h = tps.fold(0.0, (s, t) => s + t.height) + 18;
    final left = (cx - w / 2).clamp(0.0, size.width - w);
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(left, 0, w, h), const Radius.circular(12));
    canvas.drawRRect(r, Paint()..color = C.navy);
    var dy = 9.0;
    for (final t in tps) {
      t.paint(canvas, Offset(left + 12, dy));
      dy += t.height;
    }
  }

  static final _labels = <String, TextPainter>{};

  void _dotted(Canvas canvas, Offset a, Offset b, Paint p) {
    final dashes = <Offset>[for (var dx = a.dx; dx < b.dx; dx += 4) ...[Offset(dx, a.dy), Offset(dx + 1.5, a.dy)]];
    canvas.drawPoints(ui.PointMode.lines, dashes, p);
  }

  void _text(Canvas canvas, String s, Offset at, Color c, {required int align, bool below = false}) {
    if (_labels.length > 120) _labels.clear();
    final tp = _labels.putIfAbsent(
      '$s|${c.toARGB32()}',
      () => TextPainter(text: TextSpan(text: s, style: figures(sans(11.5, color: c))), textDirection: TextDirection.ltr)..layout(),
    );
    final dx = align == 1 ? at.dx - tp.width : align == 2 ? at.dx - tp.width : at.dx;
    tp.paint(canvas, Offset(dx, below ? at.dy - 2 : at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_Painter o) => true;
}
