import 'package:flutter/widgets.dart';

import '../platform/haptics.dart';
import '../platform/web_glue.dart';
import '../state.dart';
import '../theme.dart';
import '../ui/basics.dart';
import '../ui/mark.dart';

/// Six dots and a keypad. [onDone] says whether the PIN was accepted.
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.title, this.subtitle, required this.onDone, this.footer});

  final String title;
  final String? subtitle;
  final Future<bool> Function(String pin) onDone;
  final Widget? footer;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _busy = false;
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _press(String d) async {
    if (_busy || _pin.length >= 6) return;
    setState(() => _pin += d);
    if (_pin.length < 6) return;
    _busy = true;
    final ok = await widget.onDone(_pin);
    if (!mounted) return;
    if (!ok) {
      if (!reducedMotion(context)) _shake.forward(from: 0);
      Haptics.confirm();
    }
    setState(() {
      _busy = false;
      if (!ok) _pin = '';
    });
  }

  void _back() {
    if (_busy || _pin.isEmpty) return;
    Haptics.tick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const Spacer(flex: 2),
          BlurText(widget.title, style: serif(34), align: WrapAlignment.center),
          if (widget.subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 12, 40, 0),
              child: Text(widget.subtitle!, style: sans(15, color: C.ink2, height: 1.4), textAlign: TextAlign.center),
            ),
          const SizedBox(height: 30),
          AnimatedBuilder(
            animation: _shake,
            builder: (context, child) => Transform.translate(offset: Offset(12 * (1 - _shake.value) * _wave(_shake.value), 0), child: child),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 6; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.symmetric(horizontal: 9),
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length ? C.navy : const Color(0x00000000),
                      border: Border.all(color: i < _pin.length ? C.navy : C.ink.withValues(alpha: 0.3), width: 1.4),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['', '0', '<']])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final k in row)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      child: k.isEmpty
                          ? const SizedBox(width: 76, height: 76)
                          : Pressable(
                              haptic: k != '<',
                              scale: 0.9,
                              semanticLabel: k == '<' ? 'Delete' : k,
                              onTap: () => k == '<' ? _back() : _press(k),
                              child: Container(
                                width: 76,
                                height: 76,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: k == '<' ? const Color(0x00000000) : C.raised, border: k == '<' ? null : Border.all(color: C.rule.withValues(alpha: 0.08))),
                                child: k == '<' ? const _Backspace() : Text(k, style: figures(serif(32, tracking: 0))),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          SizedBox(height: 56, child: Center(child: widget.footer)),
          SizedBox(height: 12 + browserSafeArea().bottom),
        ],
      );

  static double _wave(double t) => t == 0 ? 0 : (t * 12).floor().isEven ? 1 : -1;
}

class _Backspace extends StatelessWidget {
  const _Backspace();

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(26, 18), painter: _BackspacePainter());
}

class _BackspacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = C.ink2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    canvas.drawPath(Path()..moveTo(8, 1)..lineTo(w - 1, 1)..lineTo(w - 1, h - 1)..lineTo(8, h - 1)..lineTo(1, h / 2)..close(), p);
    canvas.drawLine(Offset(12, h / 2 - 3.5), Offset(18, h / 2 + 3.5), p);
    canvas.drawLine(Offset(18, h / 2 - 3.5), Offset(12, h / 2 + 3.5), p);
  }

  @override
  bool shouldRepaint(_BackspacePainter old) => false;
}

class LockScreen extends StatefulWidget {
  const LockScreen(this.state, {super.key});

  final AppState state;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  int _fails = 0;
  DateTime? _until;

  Future<bool> _try(String pin) async {
    final until = _until;
    if (until != null && DateTime.now().isBefore(until)) return false;
    if (await widget.state.unlock(pin)) return true;
    _fails++;
    // Slows a guesser down on this device: 5 wrong tries, then 30 seconds each.
    if (_fails >= 5) _until = DateTime.now().add(const Duration(seconds: 30));
    setState(() {});
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _until != null && DateTime.now().isBefore(_until!);
    return ColoredBox(
      color: C.ground,
      child: Column(
        children: [
          SizedBox(height: 28 + browserSafeArea().top),
          const AppMark(size: 56),
          Expanded(
            child: PinPad(
              title: 'Enter your PIN',
              subtitle: waiting ? 'Too many tries. Wait 30 seconds.' : 'Your portfolio is sealed on this phone.',
              onDone: _try,
              footer: Pressable(
                onTap: () => widget.state.disconnect(),
                child: Text('Forgot PIN? Disconnect', style: sans(14, color: C.ink2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
