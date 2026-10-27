import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../format.dart';
import '../platform/haptics.dart';
import '../theme.dart';

/// Every scroll view bounces like on an iPhone, with a mouse or a finger,
/// with no glow and no scrollbar.
class AppScrollBehavior extends ScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

bool reducedMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// Shrinks a little under the finger and springs back, with a tick.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97, this.haptic = true, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: enabled
            ? () {
                if (widget.haptic) Haptics.tick();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: Duration(milliseconds: _down ? 80 : 320),
          curve: _down ? Curves.easeOut : Curves.elasticOut,
          child: AnimatedOpacity(
            opacity: _down ? 0.82 : 1,
            duration: const Duration(milliseconds: 100),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Fades in from a soft blur, a little below its place.
class BlurIn extends StatefulWidget {
  const BlurIn({super.key, required this.child, this.delay = Duration.zero, this.duration = const Duration(milliseconds: 900), this.blur = 10, this.rise = 10});

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double blur;
  final double rise;

  @override
  State<BlurIn> createState() => _BlurInState();
}

class _BlurInState extends State<BlurIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reducedMotion(context)) {
      _c.value = 1;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        child: widget.child,
        builder: (context, child) {
          final t = _t.value;
          if (t >= 1) return child!;
          final sigma = widget.blur * (1 - t);
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, widget.rise * (1 - t)),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
                child: child,
              ),
            ),
          );
        },
      );
}

/// Text that arrives word by word out of a blur.
class BlurText extends StatelessWidget {
  const BlurText(this.text, {super.key, required this.style, this.align = WrapAlignment.start, this.delay = Duration.zero, this.stagger = const Duration(milliseconds: 70)});

  final String text;
  final TextStyle style;
  final WrapAlignment align;
  final Duration delay;
  final Duration stagger;

  @override
  Widget build(BuildContext context) {
    final words = text.split(' ');
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Wrap(
        alignment: align,
        runAlignment: align,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < words.length; i++)
            BlurIn(
              delay: delay + stagger * i,
              child: Text(i < words.length - 1 ? '${words[i]} ' : words[i], style: style),
            ),
        ],
      ),
    );
  }
}

/// A euro amount that counts to its new value.
class CountUp extends StatefulWidget {
  const CountUp(this.value, {super.key, required this.style, this.cents = false, this.duration = const Duration(milliseconds: 650)});

  final double value;
  final TextStyle style;
  final bool cents;
  final Duration duration;

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> {
  bool _built = false;

  @override
  Widget build(BuildContext context) {
    // Counts up from zero once. After that, a slider moving the number only
    // eases it a little: shaping big text on every frame is what made it lag.
    final first = !_built;
    _built = true;
    final style = widget.style;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.value),
      duration: reducedMotion(context) ? Duration.zero : (first ? widget.duration : const Duration(milliseconds: 90)),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => hideAmounts
          // Hidden: small quiet dots in the place of the big number, same height.
          ? SizedBox(
              height: (style.fontSize ?? 16) * (style.height ?? 1.2),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: Text('€•••••', style: style.copyWith(fontSize: (style.fontSize ?? 16) * 0.55, letterSpacing: 6, color: C.ink3)),
              ),
            )
          : Text(eur(v, cents: widget.cents), style: figures(style), maxLines: 1),
    );
  }
}

/// Rounded button: navy and filled, or a quiet outline.
class AppButton extends StatelessWidget {
  const AppButton(this.label, {super.key, required this.onTap, this.filled = true, this.busy = false});

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: busy ? null : onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? (onTap == null ? C.ink3 : C.navy) : null,
            border: filled ? null : Border.all(color: C.ink.withValues(alpha: 0.28)),
            borderRadius: BorderRadius.circular(27),
          ),
          child: busy
              ? SizedBox(width: 20, height: 20, child: _Spinner(color: filled ? C.ground : C.ink))
              : Text(label, style: sans(16, weight: FontWeight.w500, color: filled ? C.ground : C.ink)),
        ),
      );
}

class _Spinner extends StatefulWidget {
  const _Spinner({required this.color});
  final Color color;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(turns: _c, child: CustomPaint(painter: _ArcPainter(widget.color)));
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Offset.zero & size, 0, 4.4, false, p);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}

/// Small spinner for pull to refresh and busy states.
class Spinner extends StatelessWidget {
  const Spinner({super.key, this.size = 18, this.color = C.ink2});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: _Spinner(color: color));
}
