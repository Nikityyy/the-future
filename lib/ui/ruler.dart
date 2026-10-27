import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../format.dart';
import '../platform/haptics.dart';
import '../theme.dart';

/// A ruler you slide under a fixed mark: a real scroll view, so it flings and
/// bounces at its ends like everything else, then settles on a tick.
class RulerSlider extends StatefulWidget {
  const RulerSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.label,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final String? label;

  @override
  State<RulerSlider> createState() => _RulerSliderState();
}

class _RulerSliderState extends State<RulerSlider> {
  static const _gap = 10.0;
  late final ScrollController _c = ScrollController(
    initialScrollOffset: _offsetOf(widget.value),
  );
  late int _index = _indexOf(widget.value);
  bool _settling = false;

  int get _count => ((widget.max - widget.min) / widget.step).round();
  int _indexOf(double v) =>
      ((v - widget.min) / widget.step).round().clamp(0, _count);
  double _offsetOf(double v) => _indexOf(v) * _gap;

  @override
  void didUpdateWidget(RulerSlider old) {
    super.didUpdateWidget(old);
    // Changed from outside (reset): move the ruler to it.
    if (_indexOf(widget.value) != _index &&
        _c.hasClients &&
        !_c.position.isScrollingNotifier.value) {
      _index = _indexOf(widget.value);
      _c.animateTo(
        _index * _gap,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
      final i = (_c.offset / _gap).round().clamp(0, _count);
      if (i != _index) {
        _index = i;
        Haptics.selection();
        widget.onChanged(widget.min + i * widget.step);
      }
    }
    if (n is ScrollEndNotification && !_settling) {
      final target = _index * _gap;
      if ((_c.offset - target).abs() > 0.5) {
        _settling = true;
        _c
            .animateTo(
              target,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
            )
            .whenComplete(() => _settling = false);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cur = widget.min + _index * widget.step;
    return LayoutBuilder(
      builder: (context, box) {
        final half = box.maxWidth / 2;
        return Semantics(
          slider: true,
          label: widget.label,
          value: eur(widget.value, mask: false),
          increasedValue: eur(
            math.min(widget.max, widget.value + widget.step),
            mask: false,
          ),
          decreasedValue: eur(
            math.max(widget.min, widget.value - widget.step),
            mask: false,
          ),
          onIncrease: () => widget.onChanged(
            math.min(widget.max, widget.value + widget.step),
          ),
          onDecrease: () => widget.onChanged(
            math.max(widget.min, widget.value - widget.step),
          ),
          child: SizedBox(
            height: 104,
            child: Stack(
              children: [
                Positioned.fill(
                  top: 40,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        NotificationListener<ScrollNotification>(
                          onNotification: _onScroll,
                          child: SingleChildScrollView(
                            controller: _c,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            child: SizedBox(
                              width: _count * _gap + box.maxWidth,
                              height: 64,
                            ),
                          ),
                        ),
                        // Only the ticks in view are drawn, as the ruler moves.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _TicksPainter(
                                  _c,
                                  count: _count,
                                  gap: _gap,
                                  pad: half,
                                  min: widget.min,
                                  step: widget.step,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: half - 0.75,
                  top: 28,
                  child: Container(
                    width: 1.5,
                    height: 44,
                    decoration: BoxDecoration(
                      color: C.navy,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                Positioned(
                  left: half - 34,
                  top: 0,
                  width: 68,
                  child: Container(
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: C.navy,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      eur(cur, mask: false),
                      style: figures(
                        sans(15, weight: FontWeight.w600, color: C.ground),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TicksPainter extends CustomPainter {
  _TicksPainter(
    this.c, {
    required this.count,
    required this.gap,
    required this.pad,
    required this.min,
    required this.step,
  }) : super(repaint: c);

  final ScrollController c;
  final int count;
  final double gap;
  final double pad;
  final double min;
  final double step;

  static final _labels = <String, TextPainter>{};

  @override
  void paint(Canvas canvas, Size size) {
    final offset = c.hasClients ? c.offset : 0.0;
    final mid = size.width / 2;
    final paint = Paint()..strokeWidth = 1;
    final from = ((offset - pad) / gap).floor().clamp(0, count);
    final to = ((offset + size.width - pad) / gap).ceil().clamp(0, count);
    for (var i = from; i <= to; i++) {
      final x = pad + i * gap - offset;
      // Fade toward both edges, so there is no layer to mask.
      final fade = ((1 - (x - mid).abs() / mid) / 0.24).clamp(0.0, 1.0);
      if (fade <= 0) continue;
      final big = i % 5 == 0;
      canvas.drawLine(
        Offset(x, 6),
        Offset(x, big ? 24 : 16),
        paint..color = C.ink.withValues(alpha: (big ? 0.5 : 0.28) * fade),
      );
      if (i % 10 == 0 || (i % 5 == 0 && count < 40)) {
        final level = (fade * 4).round();
        if (level == 0) continue;
        final text = eur(min + i * step, mask: false);
        final tp = _labels.putIfAbsent(
          '$text|$level',
          () => TextPainter(
            text: TextSpan(
              text: text,
              style: figures(
                sans(12, color: C.ink3.withValues(alpha: C.ink3.a * level / 4)),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(),
        );
        tp.paint(canvas, Offset(x - tp.width / 2, 34));
      }
    }
  }

  @override
  bool shouldRepaint(_TicksPainter old) =>
      old.count != count ||
      old.pad != pad ||
      old.min != min ||
      old.step != step;
}
