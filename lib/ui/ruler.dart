import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../format.dart';
import '../platform/haptics.dart';
import '../theme.dart';

/// A ruler you slide under a fixed mark: a real scroll view, so it flings and
/// bounces at its ends like everything else, then settles on a tick.
class RulerSlider extends StatefulWidget {
  const RulerSlider({super.key, required this.value, required this.min, required this.max, required this.step, required this.onChanged, this.label});

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
  late final ScrollController _c = ScrollController(initialScrollOffset: _offsetOf(widget.value));
  late int _index = _indexOf(widget.value);
  bool _settling = false;

  int get _count => ((widget.max - widget.min) / widget.step).round();
  int _indexOf(double v) => ((v - widget.min) / widget.step).round().clamp(0, _count);
  double _offsetOf(double v) => _indexOf(v) * _gap;

  @override
  void didUpdateWidget(RulerSlider old) {
    super.didUpdateWidget(old);
    // Changed from outside (reset): move the ruler to it.
    if (_indexOf(widget.value) != _index && _c.hasClients && !_c.position.isScrollingNotifier.value) {
      _index = _indexOf(widget.value);
      _c.animateTo(_index * _gap, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
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
        _c.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic).whenComplete(() => _settling = false);
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
          value: eur(widget.value),
          increasedValue: eur(math.min(widget.max, widget.value + widget.step)),
          decreasedValue: eur(math.max(widget.min, widget.value - widget.step)),
          onIncrease: () => widget.onChanged(math.min(widget.max, widget.value + widget.step)),
          onDecrease: () => widget.onChanged(math.max(widget.min, widget.value - widget.step)),
          child: SizedBox(
            height: 104,
            child: Stack(
              children: [
                Positioned.fill(
                  top: 40,
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (r) => const LinearGradient(colors: [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)], stops: [0, 0.22, 0.78, 1]).createShader(r),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onScroll,
                      child: SingleChildScrollView(
                        controller: _c,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        child: CustomPaint(
                          size: Size(_count * _gap + box.maxWidth, 64),
                          painter: _TicksPainter(count: _count, gap: _gap, pad: half, min: widget.min, step: widget.step),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: half - 0.75,
                  top: 28,
                  child: Container(width: 1.5, height: 44, decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(1))),
                ),
                Positioned(
                  left: half - 34,
                  top: 0,
                  width: 68,
                  child: Container(
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(9)),
                    child: Text(eur(cur), style: figures(sans(15, weight: FontWeight.w600, color: C.ground))),
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
  _TicksPainter({required this.count, required this.gap, required this.pad, required this.min, required this.step});

  final int count;
  final double gap;
  final double pad;
  final double min;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = C.ink.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = C.ink.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var i = 0; i <= count; i++) {
      final x = pad + i * gap;
      final big = i % 5 == 0;
      canvas.drawLine(Offset(x, 6), Offset(x, big ? 24 : 16), big ? major : minor);
      if (i % 5 == 0 && i % 10 == 0 || (i % 5 == 0 && count < 40)) {
        final tp = TextPainter(
          text: TextSpan(text: eur(min + i * step), style: figures(sans(12, color: C.ink3))),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, 34));
      }
    }
  }

  @override
  bool shouldRepaint(_TicksPainter old) => old.count != count || old.pad != pad || old.min != min || old.step != step;
}
