import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/widgets.dart';

import '../format.dart';
import '../platform/haptics.dart';
import '../prices.dart';
import '../projection.dart' show Kind;
import '../snapshot.dart';
import '../theme.dart';
import 'basics.dart' show Switch2, reducedMotion, skipEntrance;
import 'chrome.dart';

const _frames = [('day', '1D', 'in the past day'), ('week', '1W', 'in the past week'), ('month', '1M', 'in the past month'), ('six_month', '6M', 'in the past 6 months'), ('year', '1Y', 'in the past year'), ('all', 'All', '')];
const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// What the whole portfolio was worth over time, from Bitpanda, with the
/// change over the picked period. The change leaves out money you added, so
/// a deposit never shows up as growth. Drag along the line to read a moment.
/// With [only], just those kinds: Bitpanda keeps no history per kind, so the
/// line is built from the prices and the units you held (see kindValues).
///
/// With [compare] on, a second line shows what the same money, put in at the
/// same moments, would be worth in MSCI World (see benchmarkLine).
class ValueHistory extends StatefulWidget {
  const ValueHistory(this.s, {super.key, this.only, this.compare = false, this.onCompare});

  final Snapshot s;
  final Set<Kind>? only;
  final bool compare;
  final ValueChanged<bool>? onCompare;

  @override
  State<ValueHistory> createState() => _ValueHistoryState();
}

class _ValueHistoryState extends State<ValueHistory> {
  /// The picked period, and the one whose line is on screen: the line
  /// before stays, with its own words, while the picked one is built.
  String _frame = 'month';
  String? _shown;
  int? _scrub;

  /// The lines built for [ValueHistory.only], by frame, and the ones being built or failed.
  final _built = <String, List<(DateTime, double)>>{};

  /// The whole portfolio's lines, up to the live prices, kept so a rebuild
  /// hands the chart the same line and does not start it moving.
  final _whole = <String, List<(DateTime, double)>>{};
  final _loading = <String>{};
  final _failed = <String>{};

  /// MSCI World's prices by frame, the comparison lines built on them (by
  /// frame, for the line they were built on), and the frames whose prices
  /// are loading or could not be had.
  final _index = <String, List<(DateTime, double)>>{};
  final _bench = <String, (List<(DateTime, double)>, List<(DateTime, double)>)>{};
  final _indexLoading = <String>{};
  final _indexFailed = <String>{};

  /// Each line's change, worked out once: a finger on the chart rebuilds
  /// every frame, and the change walks every transaction.
  final _changes = Expando<({double gain, double added, double? percent})>();
  ({double gain, double added, double? percent}) _change(List<(DateTime, double)> pts) => _changes[pts] ??= widget.s.change(pts, kinds: widget.only);

  @override
  void didUpdateWidget(ValueHistory old) {
    super.didUpdateWidget(old);
    if (!identical(old.s, widget.s) || !setEquals(old.only, widget.only)) {
      _built.clear();
      _whole.clear();
      _loading.clear();
      _failed.clear();
      _bench.clear();
      _scrub = null;
    }
  }

  void _build(String frame) {
    if (widget.only == null || _built.containsKey(frame) || _loading.contains(frame) || _failed.contains(frame)) return;
    _loading.add(frame);
    final (s, only) = (widget.s, widget.only!);
    kindValues(s, only, frame, [for (final p in s.historyNow(frame)!) p.$1]).then(
      (pts) {
        if (!mounted || !identical(s, widget.s) || !setEquals(only, widget.only)) return;
        setState(() {
          _loading.remove(frame);
          _built[frame] = pts;
        });
      },
      onError: (Object _) {
        if (!mounted || !identical(s, widget.s) || !setEquals(only, widget.only)) return;
        setState(() {
          _loading.remove(frame);
          _failed.add(frame);
        });
      },
    );
  }

  void _loadIndex(String frame) {
    if (!widget.compare || _index.containsKey(frame) || _indexLoading.contains(frame) || _indexFailed.contains(frame)) return;
    _indexLoading.add(frame);
    prices(msciWorld, frame == 'all' ? 'five-years' : frame).then(
      (pts) {
        if (!mounted) return;
        setState(() {
          _indexLoading.remove(frame);
          pts.isEmpty ? _indexFailed.add(frame) : _index[frame] = pts;
        });
      },
      onError: (Object _) {
        if (mounted) setState(() => _indexFailed.add(frame));
      },
    );
  }

  /// The comparison for [pts], built once per line, so a rebuild hands the
  /// chart the same list and does not start it moving.
  List<(DateTime, double)>? _benchFor(String frame, List<(DateTime, double)> pts) {
    final index = _index[frame];
    if (!widget.compare || index == null) return null;
    final cached = _bench[frame];
    if (cached != null && identical(cached.$1, pts)) return cached.$2.length == pts.length ? cached.$2 : null;
    final line = benchmarkLine(pts, index, widget.s.trades, kinds: widget.only);
    _bench[frame] = (pts, line);
    return line.length == pts.length ? line : null;
  }

  @override
  Widget build(BuildContext context) {
    final frames = [for (final f in _frames) if ((widget.s.history[f.$1]?.length ?? 0) > 1) f];
    if (frames.isEmpty) return const SizedBox();
    final f = frames.firstWhere((f) => f.$1 == _frame, orElse: () => frames.last);
    _build(f.$1);
    List<(DateTime, double)>? line(String frame) => widget.only == null ? _whole[frame] ??= widget.s.historyNow(frame)! : _built[frame];
    if (line(f.$1) != null) _shown = f.$1;
    final shown = frames.firstWhere((x) => x.$1 == _shown, orElse: () => f);
    final pts = line(shown.$1);
    if (pts == null) return _waiting(frames, f);
    final (t0, v0) = pts.first;
    final v1 = pts.last.$2;
    final (:gain, added: _, percent: pct) = _change(pts);
    final up = gain >= 0;
    _loadIndex(shown.$1);
    final bench = _benchFor(shown.$1, pts);
    final benchChange = bench == null || bench.length < 2 ? null : _change(bench);
    final label = shown.$1 == 'all' ? 'since ${_monthNames[t0.month - 1]} ${t0.year}' : shown.$3;
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
              child: _failed.contains(f.$1)
                  ? _retry(f)
                  : i == null
                  ? Text.rich(TextSpan(children: [
                      TextSpan(text: '${signedEur(gain)}${pct != null ? '  (${percent(pct)})' : ''}', style: figures(sans(14, weight: FontWeight.w500, color: up ? C.greenInk : C.loss))),
                      TextSpan(text: '  $label', style: sans(14, color: C.ink2)),
                    ]))
                  : Text.rich(TextSpan(children: [
                      TextSpan(text: eur(pts[i].$2), style: figures(sans(14, weight: FontWeight.w600))),
                      if (bench != null) TextSpan(text: '  vs ${eur(bench[i].$2)}', style: figures(sans(14, weight: FontWeight.w500, color: _MorphLine.benchColor))),
                      TextSpan(text: '  ${_when(pts[i].$1, shown.$1)}', style: sans(14, color: C.ink2)),
                    ])),
            ),
          ),
          if (widget.compare)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: SizedBox(
                height: 18,
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: _MorphLine.benchColor, shape: BoxShape.circle)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        benchChange != null
                            ? 'MSCI World instead: ${signedEur(benchChange.gain)}${benchChange.percent != null ? '  (${percent(benchChange.percent!)})' : ''}'
                            : _indexFailed.contains(shown.$1)
                                ? 'MSCI World could not load.'
                                : switch (_index[shown.$1]) {
                                    final index? => 'No MSCI World prices before ${_monthNames[index.first.$1.toLocal().month - 1]} ${index.first.$1.toLocal().year}.',
                                    null => 'Loading MSCI World…',
                                  },
                        style: figures(sans(13, color: C.ink2)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) {
              void scrubTo(double dx) {
                final n = _nearest(pts, dx / box.maxWidth);
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
                  child: _MorphLine(pts, bench: bench, color: up ? C.green : C.loss, scrub: i, width: box.maxWidth),
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
          if (widget.onCompare != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 20, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Compare with MSCI World', style: sans(15))),
                  Switch2(on: widget.compare, onChanged: widget.onCompare!),
                ],
              ),
            ),

        ],
      ),
    );
  }

  /// Says the line for [f] could not be built, and builds it again on a tap.
  Widget _retry((String, String, String) f) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          _failed.remove(f.$1);
          _build(f.$1);
        }),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: 'The chart did not load.  ', style: sans(14, color: C.ink2)),
          TextSpan(text: 'Try again', style: sans(14, weight: FontWeight.w600, color: C.navy)),
        ])),
      );

  /// Room for the line while it is built, or a way to ask again when it could not be.
  Widget _waiting(List<(String, String, String)> frames, (String, String, String) f) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(height: 20, child: _failed.contains(f.$1) ? _retry(f) : null),
            ),
            const SizedBox(height: 10),
            const SizedBox(height: _MorphLine.height),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Segments(
                labels: [for (final x in frames) x.$2],
                index: frames.indexOf(f),
                onChanged: (n) => setState(() => _frame = frames[n].$1),
              ),
            ),
          ],
        ),
      );

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
        TextSpan(text: '  ${_shown == 'day' && widget.h.kind != Kind.crypto ? 'today' : p.$3}', style: sans(14, color: C.ink2)),
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
                final n = _nearest(pts, dx / box.maxWidth);
                if (n != _scrub) {
                  Haptics.selection();
                  setState(() => _scrub = n);
                }
              }

              // Room for the line while it loads; none when there is nothing to show.
              if (!ok) return SizedBox(height: _pts == null && !_failed ? _MorphLine.height : 0);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => scrubTo(d.localPosition.dx),
                onHorizontalDragUpdate: (d) => scrubTo(d.localPosition.dx),
                onHorizontalDragEnd: (_) => setState(() => _scrub = null),
                onHorizontalDragCancel: () => setState(() => _scrub = null),
                child: Semantics(
                  label: '${widget.h.name} price ${p.$3}: from ${unit(pts.first.$2)} to ${unit(pts.last.$2)}.',
                  child: _MorphLine(pts, color: up ? C.green : C.loss, scrub: i, width: box.maxWidth),
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

/// The point of [pts] nearest to [f] of the way across, by time.
int _nearest(List<(DateTime, double)> pts, double f) {
  int us(int i) => pts[i].$1.microsecondsSinceEpoch;
  final t = us(0) + (us(pts.length - 1) - us(0)) * f.clamp(0.0, 1.0);
  var lo = 0, hi = pts.length - 1;
  while (hi - lo > 1) {
    final m = (lo + hi) >> 1;
    us(m) <= t ? lo = m : hi = m;
  }
  return t - us(lo) <= us(hi) - t ? lo : hi;
}

/// The low and high a chart of [values] spans, with some room above and
/// below. The room follows the size of the numbers, so a coin worth a cent
/// still moves.
(double, double) _bounds(Iterable<double> values) {
  var lo = double.infinity, hi = -double.infinity;
  for (final v in values) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  final pad = hi > lo ? (hi - lo) * 0.12 : (hi.abs() > 0 ? hi.abs() * 0.05 : 1);
  return (lo - pad, hi + pad);
}

/// [pts] in a unit square: across by time, as Bitpanda and every broker
/// draw it, so a gap in the data is a slope and not a cliff; down by value
/// between [bounds].
List<Offset> _unit(List<(DateTime, double)> pts, (double, double) bounds) {
  final (lo, hi) = bounds;
  final t0 = pts.first.$1.microsecondsSinceEpoch, span = pts.last.$1.microsecondsSinceEpoch - t0;
  return [for (final (i, p) in pts.indexed) Offset(span > 0 ? (p.$1.microsecondsSinceEpoch - t0) / span : i / (pts.length - 1), (hi - p.$2) / (hi - lo))];
}

/// [u] read off at [k] even steps across, so two lines with different
/// points can bend into each other point by point.
List<Offset> _resample(List<Offset> u, int k) {
  var j = 0;
  return [
    for (var i = 0; i < k; i++)
      () {
        final x = i / (k - 1);
        while (j < u.length - 2 && u[j + 1].dx < x) {
          j++;
        }
        final (a, b) = (u[j], u[j + 1]);
        return Offset(x, a.dy + (b.dy - a.dy) * (b.dx > a.dx ? ((x - a.dx) / (b.dx - a.dx)).clamp(0.0, 1.0) : 1.0));
      }(),
  ];
}

/// The line of a chart, [height] high, and the [bench] line drawn behind
/// it on the same scale. The first line draws in from the left; a new
/// period's line grows out of the one on screen, bending into its shape and
/// color, the way the Stocks app moves between periods. A comparison line
/// that appears grows out of the main one.
class _MorphLine extends StatefulWidget {
  const _MorphLine(this.pts, {this.bench, required this.color, required this.scrub, required this.width});

  final List<(DateTime, double)> pts;
  final List<(DateTime, double)>? bench;
  final Color color;
  final int? scrub;
  final double width;

  static const height = 150.0;
  static const benchColor = C.slate;

  @override
  State<_MorphLine> createState() => _MorphLineState();
}

class _MorphLineState extends State<_MorphLine> with SingleTickerProviderStateMixin {
  static const _samples = 400;

  late final _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  /// The lines in the unit square, exact and sampled.
  late List<Offset> _to;
  List<Offset>? _toBench;
  late List<Offset> _toSampled;
  List<Offset>? _toBenchSampled;

  /// The lines on screen when the points changed, sampled, and the main
  /// line's color; null while the first line draws in.
  List<Offset>? _from, _fromBench;
  late Color _fromColor = widget.color;
  bool _first = true;

  @override
  void initState() {
    super.initState();
    _shape();
  }

  /// Both lines on one scale, so the gap between them is real.
  void _shape() {
    final bench = widget.bench;
    final bounds = _bounds([for (final p in widget.pts) p.$2, for (final p in bench ?? const <(DateTime, double)>[]) p.$2]);
    _to = _unit(widget.pts, bounds);
    _toSampled = _resample(_to, _samples);
    _toBench = bench == null || bench.length < 2 ? null : _unit(bench, bounds);
    _toBenchSampled = _toBench == null ? null : _resample(_toBench!, _samples);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_first) {
      _first = false;
      skipEntrance(context) ? _t.value = 1 : _t.forward();
    }
  }

  List<Offset> _lerp(List<Offset> a, List<Offset> b, double e) => [for (var i = 0; i < _samples; i++) Offset.lerp(a[i], b[i], e)!];

  @override
  void didUpdateWidget(_MorphLine old) {
    super.didUpdateWidget(old);
    if (identical(old.pts, widget.pts) && identical(old.bench, widget.bench) && old.color == widget.color) return;
    // Taken before the new lines replace the old ones, so a switch in the
    // middle of a morph starts from where the lines are.
    final from = _from, fromBench = _fromBench, e = Curves.easeOutCubic.transform(_t.value);
    final moving = from != null && !_t.isCompleted;
    final shape = moving ? _lerp(from, _toSampled, e) : _toSampled;
    final toBench = _toBenchSampled;
    final benchShape = toBench == null ? null : moving && fromBench != null ? _lerp(fromBench, toBench, e) : toBench;
    final color = moving ? Color.lerp(_fromColor, old.color, e)! : old.color;
    _shape();
    if (reducedMotion(context)) {
      _from = _fromBench = null;
      _t.value = 1;
      return;
    }
    _from = shape;
    _fromBench = benchShape ?? shape;
    _fromColor = color;
    _t.forward(from: 0);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        builder: (context, _) {
          final from = _from, s = widget.scrub, size = Size(widget.width, _MorphLine.height);
          if (from == null) {
            return CustomPaint(size: size, painter: _Line(_to, widget.color, Curves.easeOutCubic.transform(_t.value), s == null ? null : _to[s], bench: _toBench));
          }
          if (_t.isCompleted) return CustomPaint(size: size, painter: _Line(_to, widget.color, 1, s == null ? null : _to[s], bench: _toBench));
          final e = Curves.easeOutCubic.transform(_t.value);
          final toBench = _toBenchSampled, fromBench = _fromBench;
          return CustomPaint(
            size: size,
            painter: _Line(
              _lerp(from, _toSampled, e),
              Color.lerp(_fromColor, widget.color, e)!,
              1,
              null,
              bench: toBench == null || fromBench == null ? null : _lerp(fromBench, toBench, e),
            ),
          );
        },
      );
}

/// A line through [unit] (see [_unit]), drawn up to [reveal] of the way
/// across, with a dot on [dot] while a finger reads it.
class _Line extends CustomPainter {
  _Line(this.unit, this.color, this.reveal, this.dot, {this.bench});

  final List<Offset> unit;
  final Color color;
  final double reveal;
  final Offset? dot;

  /// The comparison line, drawn thinner and behind.
  final List<Offset>? bench;

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(Offset u) => Offset(u.dx * size.width, u.dy * size.height);
    (Path, Offset) path(List<Offset> unit) {
      final start = at(unit.first);
      final line = Path()..moveTo(start.dx, start.dy);
      var end = start;
      for (var i = 1; i < unit.length; i++) {
        final (a, b) = (unit[i - 1], unit[i]);
        end = at(b.dx <= reveal ? b : Offset.lerp(a, b, (reveal - a.dx) / (b.dx - a.dx))!);
        line.lineTo(end.dx, end.dy);
        if (b.dx > reveal) break;
      }
      return (line, end);
    }

    if (bench case final b?) {
      canvas.drawPath(
        path(b).$1,
        Paint()
          ..color = _MorphLine.benchColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    final start = at(unit.first);
    final (line, end) = path(unit);
    final fill = Path.from(line)
      ..lineTo(end.dx, size.height)
      ..lineTo(start.dx, size.height)
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
    final d = dot;
    if (d != null) {
      final p = at(d);
      canvas.drawLine(Offset(p.dx, 0), Offset(p.dx, size.height), Paint()..color = C.ink.withValues(alpha: 0.25));
      canvas.drawCircle(p, 5, Paint()..color = C.ground);
      canvas.drawCircle(
        p,
        5,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_Line old) => !identical(old.unit, unit) || !identical(old.bench, bench) || old.reveal != reveal || old.dot != dot || old.color != color;
}
