import 'package:flutter/widgets.dart';

import '../format.dart';
import '../platform/haptics.dart';
import '../prices.dart';
import '../snapshot.dart';
import '../theme.dart';
import 'basics.dart' show skipEntrance;
import 'chrome.dart';

const _frames = [('day', '1D', 'in the past day'), ('week', '1W', 'in the past week'), ('month', '1M', 'in the past month'), ('six_month', '6M', 'in the past 6 months'), ('year', '1Y', 'in the past year'), ('all', 'All', '')];
const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// What the whole portfolio was worth over time, from Bitpanda, with the
/// change over the picked period. The change leaves out money you added, so
/// a deposit never shows up as growth. Drag along the line to read a moment.
class ValueHistory extends StatefulWidget {
  const ValueHistory(this.s, {super.key});

  final Snapshot s;

  @override
  State<ValueHistory> createState() => _ValueHistoryState();
}

class _ValueHistoryState extends State<ValueHistory> {
  String _frame = 'month';
  int? _scrub;

  @override
  Widget build(BuildContext context) {
    final frames = [for (final f in _frames) if ((widget.s.history[f.$1]?.length ?? 0) > 1) f];
    if (frames.isEmpty) return const SizedBox();
    final f = frames.firstWhere((f) => f.$1 == _frame, orElse: () => frames.last);
    final pts = widget.s.history[f.$1]!;
    final (t0, v0) = pts.first;
    final (t1, v1) = pts.last;
    final added = widget.s.netAddedBetween(t0, t1);
    final gain = v1 - v0 - added;
    final base = v0 + (added > 0 ? added : 0);
    final up = gain >= 0;
    final label = f.$1 == 'all' ? 'since ${_monthNames[t0.month - 1]} ${t0.year}' : f.$3;
    final i = _scrub;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              height: 20,
              child: i == null
                  ? Text.rich(TextSpan(children: [
                      TextSpan(text: '${signedEur(gain)}${base > 0 ? '  (${percent(gain / base * 100)})' : ''}', style: figures(sans(14, weight: FontWeight.w500, color: up ? C.greenInk : C.loss))),
                      TextSpan(text: '  $label', style: sans(14, color: C.ink2)),
                    ]))
                  : Text.rich(TextSpan(children: [
                      TextSpan(text: eur(pts[i].$2), style: figures(sans(14, weight: FontWeight.w600))),
                      TextSpan(text: '  ${_when(pts[i].$1, f.$1)}', style: sans(14, color: C.ink2)),
                    ])),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) {
              void scrubTo(double dx) {
                final n = (dx / box.maxWidth * (pts.length - 1)).round().clamp(0, pts.length - 1);
                if (n != _scrub) {
                  Haptics.selection();
                  setState(() => _scrub = n);
                }
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => scrubTo(d.localPosition.dx),
                onHorizontalDragUpdate: (d) => scrubTo(d.localPosition.dx),
                onHorizontalDragEnd: (_) => setState(() => _scrub = null),
                onHorizontalDragCancel: () => setState(() => _scrub = null),
                child: Semantics(
                  label: 'Portfolio value $label: from ${eur(v0)} to ${eur(v1)}.',
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(f.$1),
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: skipEntrance(context) ? 0 : 500),
                    curve: Curves.easeOutCubic,
                    builder: (_, p, _) => CustomPaint(
                      size: Size(box.maxWidth, 150),
                      painter: _Line(pts, up ? C.green : C.loss, p, i),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          if (frames.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Segments(
                labels: [for (final f in frames) f.$2],
                index: frames.indexOf(f),
                onChanged: (n) => setState(() => _frame = frames[n].$1),
              ),
            ),
        ],
      ),
    );
  }

  static String _when(DateTime t, String frame) {
    final l = t.toLocal();
    final day = '${l.day} ${_monthNames[l.month - 1]}';
    if (frame == 'day' || frame == 'week') return '$day, ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    return frame == 'month' ? day : '$day ${l.year}';
  }
}

/// One holding's price over a picked period, loaded from Bitpanda when shown.
/// Drag along the line to read a moment.
class PriceChart extends StatefulWidget {
  const PriceChart(this.h, {super.key});

  final Holding h;

  @override
  State<PriceChart> createState() => _PriceChartState();
}

class _PriceChartState extends State<PriceChart> {
  /// The picked period, and the one whose prices are on screen: the old line
  /// stays, with its own words, until the new one has loaded.
  String _period = 'month', _shown = 'month';
  List<(DateTime, double)>? _pts;
  bool _failed = false;
  int? _scrub;

  @override
  void initState() {
    super.initState();
    _pick('month');
  }

  void _pick(String period) {
    setState(() {
      _period = period;
      _failed = false;
      _scrub = null;
    });
    prices(widget.h, period).then(
      (pts) {
        if (!mounted || _period != period) return;
        setState(() {
          _pts = pts;
          _shown = period;
        });
      },
      onError: (Object _) {
        if (mounted && _period == period) setState(() => _failed = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = chartPeriods.firstWhere((p) => p.$1 == _shown);
    final pts = _pts ?? const [];
    final ok = pts.length > 1;
    final i = _scrub;
    final up = !ok || pts.last.$2 >= pts.first.$2;
    String unit(double v) => eur(v, cents: v < 1000);

    final Widget head;
    if (_failed) {
      head = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pick(_period),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: 'The price chart did not load.  ', style: sans(14, color: C.ink2)),
          TextSpan(text: 'Try again', style: sans(14, weight: FontWeight.w600, color: C.navy)),
        ])),
      );
    } else if (ok && i != null) {
      head = Text.rich(TextSpan(children: [
        TextSpan(text: unit(pts[i].$2), style: figures(sans(14, weight: FontWeight.w600))),
        TextSpan(text: '  ${_ValueHistoryState._when(pts[i].$1, _shown == 'five-years' ? 'year' : _shown)}', style: sans(14, color: C.ink2)),
      ]));
    } else if (ok) {
      head = Text.rich(TextSpan(children: [
        TextSpan(text: percent((pts.last.$2 / pts.first.$2 - 1) * 100), style: figures(sans(14, weight: FontWeight.w500, color: up ? C.greenInk : C.loss))),
        TextSpan(text: '  ${p.$3}', style: sans(14, color: C.ink2)),
      ]));
    } else {
      head = Text(_pts == null ? '' : 'No prices for this period.', style: sans(14, color: C.ink2));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: SizedBox(height: 20, child: head)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) {
              void scrubTo(double dx) {
                final n = (dx / box.maxWidth * (pts.length - 1)).round().clamp(0, pts.length - 1);
                if (n != _scrub) {
                  Haptics.selection();
                  setState(() => _scrub = n);
                }
              }

              // Room for the line while it loads; none when there is nothing to show.
              if (!ok) return SizedBox(height: _pts == null && !_failed ? 150 : 0);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => scrubTo(d.localPosition.dx),
                onHorizontalDragUpdate: (d) => scrubTo(d.localPosition.dx),
                onHorizontalDragEnd: (_) => setState(() => _scrub = null),
                onHorizontalDragCancel: () => setState(() => _scrub = null),
                child: Semantics(
                  label: '${widget.h.name} price ${p.$3}: from ${unit(pts.first.$2)} to ${unit(pts.last.$2)}.',
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_shown),
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: skipEntrance(context) ? 0 : 500),
                    curve: Curves.easeOutCubic,
                    builder: (_, t, _) => CustomPaint(size: Size(box.maxWidth, 150), painter: _Line(pts, up ? C.green : C.loss, t, i)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Segments(
              labels: [for (final p in chartPeriods) p.$2],
              index: chartPeriods.indexWhere((p) => p.$1 == _period),
              onChanged: (n) => _pick(chartPeriods[n].$1),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends CustomPainter {
  _Line(this.pts, this.color, this.progress, this.scrub);

  final List<(DateTime, double)> pts;
  final Color color;
  final double progress;
  final int? scrub;

  @override
  void paint(Canvas canvas, Size size) {
    var lo = double.infinity, hi = -double.infinity;
    for (final p in pts) {
      if (p.$2 < lo) lo = p.$2;
      if (p.$2 > hi) hi = p.$2;
    }
    final pad = (hi - lo) * 0.12 + 1;
    lo -= pad;
    hi += pad;
    final n = pts.length - 1;
    Offset at(int i) => Offset(size.width * i / n, size.height - (pts[i].$2 - lo) / (hi - lo) * size.height);

    final last = (n * progress).ceil().clamp(1, n);
    final line = Path()..moveTo(0, at(0).dy);
    for (var i = 1; i <= last; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(at(last).dx, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)]).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final s = scrub;
    if (s != null) {
      final p = at(s);
      canvas.drawLine(Offset(p.dx, 0), Offset(p.dx, size.height), Paint()..color = C.ink.withValues(alpha: 0.25));
      canvas.drawCircle(p, 5, Paint()..color = C.ground);
      canvas.drawCircle(p, 5, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_Line old) => old.pts != pts || old.progress != progress || old.scrub != scrub || old.color != color;
}
