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
  const GrowthChart({super.key, required this.low, required this.mid, required this.high, required this.start, required this.years, required this.restartKey, this.height = 280, this.interactive = true, this.monthsPerPoint = 1, this.goal});

  final List<double> low;
  final List<double> mid;
  final List<double> high;
  final DateTime start;
  final int years;

  /// The chart draws itself again when this changes.
  final Object restartKey;

  final double height;

  /// The values are thinned out; each point is this many months apart.
  final int monthsPerPoint;

  /// The goal: its amount and how many months from now it is due. Drawn
  /// as a target at that moment, which the line passes over or under.
  final ({double amount, int months})? goal;

  /// Whether a finger dragged along it reads a month.
  final bool interactive;

  @override
  State<GrowthChart> createState() => _GrowthChartState();
}

class _GrowthChartState extends State<GrowthChart> with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  int? _scrub;
  bool _first = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_first) {
      _first = false;
      skipEntrance(context) ? _draw.value = 1 : _draw.forward();
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
                  monthsPerPoint: widget.monthsPerPoint,
                  goal: widget.goal,
                ),
              ),
            ),
          ),
        ),
      );
}

/// The top of the scale and the number of steps up to it. Each step is 1,
/// 2, 2.5 or 5 times a power of ten, so every line reads as a round amount
/// (never €62.5K or €188K), and of the step counts that fit, the one whose
/// top sits closest above [v] wins. A short chart takes fewer steps, so the
/// labels never touch.
(double, int) chartScale(double v, {required bool short}) {
  if (v <= 0) return (1000, short ? 2 : 4);
  (double, int)? best;
  for (final n in short ? const [2, 3] : const [3, 4, 5]) {
    final raw = v * 1.04 / n;
    final e = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final step = [1.0, 2.0, 2.5, 5.0, 10.0].map((m) => m * e).firstWhere((x) => x >= raw * (1 - 1e-9));
    if (best == null || step * n < best.$1 - 1e-6) best = (step * n, n);
  }
  return best!;
}

/// €2.5K, €40K, €1.25M: as short as the amount allows, never rounded wrong.
String shortEur(double v) {
  String fmt(double x) => x == x.roundToDouble() ? '${x.round()}' : x.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  if (hideAmounts) return '•••';
  return v >= 1e6 ? '€${fmt(v / 1e6)}M' : v >= 1000 ? '€${fmt(v / 1000)}K' : '€${v.round()}';
}

class _Painter extends CustomPainter {
  _Painter({required this.low, required this.mid, required this.high, required this.start, required this.years, required this.progress, required this.scrub, this.monthsPerPoint = 1, this.goal});

  static const left = 46.0;
  static const _top = 12.0;
  static const _bottom = 30.0;

  final List<double> low, mid, high;
  final DateTime start;
  final int years;
  final double progress;
  final int? scrub;
  final int monthsPerPoint;
  final ({double amount, int months})? goal;

  @override
  void paint(Canvas canvas, Size size) {
    final n = mid.length - 1;
    final g = goal;
    // A goal within the years shown is kept on the chart.
    final goalInside = g != null && g.months <= years * 12;
    final plot = Rect.fromLTRB(left, _top, size.width - 14, size.height - _bottom);
    final (yMax, lines) = chartScale(math.max(high.reduce(math.max), goalInside ? g.amount : 0), short: plot.height < 160);
    double x(int i) => plot.left + plot.width * i / n;
    double y(double v) => plot.bottom - plot.height * (v / yMax).clamp(0, 1);

    // Grid and labels.
    final grid = Paint()
      ..color = C.ink.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var g = 0; g <= lines; g++) {
      final v = yMax * g / lines;
      final gy = y(v);
      _dotted(canvas, Offset(plot.left, gy), Offset(plot.right, gy), grid);
      _text(canvas, shortEur(v), Offset(plot.left - 8, gy), C.ink3, align: 1);
    }
    _text(canvas, 'Now', Offset(plot.left, plot.bottom + 10), C.ink3, align: 0, below: true);
    _text(canvas, '${start.year + years}', Offset(plot.right, plot.bottom + 10), C.ink3, align: 2, below: true);

    // The goal: a dashed line at its amount up to when it is due, and a
    // ring there. Due after the years shown, the line runs across and says when.
    if (g != null && g.amount <= yMax) {
      final gp = Paint()
        ..color = C.navy.withValues(alpha: 0.55)
        ..strokeWidth = 1.4;
      final gy = y(g.amount);
      final end = goalInside ? plot.left + plot.width * g.months / (years * 12) : plot.right;
      for (var gx = plot.left; gx < end; gx += 9) {
        canvas.drawLine(Offset(gx, gy), Offset(math.min(gx + 5, end), gy), gp);
      }
      final due = DateTime(start.year, start.month + g.months).year;
      if (goalInside) {
        for (var dy = gy + 9; dy < plot.bottom; dy += 9) {
          canvas.drawLine(Offset(end, dy), Offset(end, math.min(dy + 5, plot.bottom)), gp);
        }
        canvas.drawCircle(Offset(end, gy), 6, Paint()..color = C.ground);
        canvas.drawCircle(
          Offset(end, gy),
          6,
          Paint()
            ..color = C.navy
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      final label = goalInside ? 'Goal $due' : 'Goal in $due';
      final leftHalf = end - plot.left < plot.width / 2;
      _text(canvas, label, Offset(leftHalf ? plot.left + 4 : end - (goalInside ? 10 : 0), gy - 12), C.navy, align: leftHalf ? 0 : 2);
    }

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
      final date = DateTime(start.year, start.month + scrub! * monthsPerPoint);
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
