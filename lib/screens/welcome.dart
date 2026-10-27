import 'package:flutter/widgets.dart';

import '../platform/haptics.dart';
import '../platform/web_glue.dart';
import '../state.dart';
import '../theme.dart';
import '../ui/basics.dart';
import '../ui/chrome.dart';
import '../ui/mark.dart';
import 'connect.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen(this.state, {super.key});

  final AppState state;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  static const _slides = [
    ('Welcome to The Future', 'Your Bitpanda investments, and what they become if you keep going.'),
    ('Slide a number, see your years', 'Change what you add each month and watch twenty years move with it.'),
    ('Private by construction', 'No account. No server of mine. Your Bitpanda key never leaves GitHub, and your numbers open only with your passphrase.'),
  ];

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: C.ground,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) {
                  Haptics.selection();
                  setState(() => _page = i);
                },
                itemBuilder: (context, i) => _Slide(index: i, active: _page == i, title: _slides[i].$1, body: _slides[i].$2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(color: i == _page ? C.ink : C.ink.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3)),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 16 + browserSafeArea().bottom),
              child: Row(
                children: [
                  Expanded(child: AppButton('Try the demo', filled: false, onTap: widget.state.startDemo)),
                  const SizedBox(width: 12),
                  Expanded(child: AppButton('Connect Bitpanda', onTap: () => showSheet<void>(context, (_) => ConnectSheet(widget.state)))),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Slide extends StatelessWidget {
  const _Slide({required this.index, required this.active, required this.title, required this.body});

  final int index;
  final bool active;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final top = browserSafeArea().top;
    return Padding(
      padding: EdgeInsets.fromLTRB(32, top, 32, 0),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Center(
              child: BlurIn(
                key: ValueKey('art$index$active'),
                duration: const Duration(milliseconds: 1000),
                child: switch (index) {
                  0 => const AppMark(size: 92),
                  1 => const _MiniFuture(),
                  _ => const _Seal(),
                },
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                if (active)
                  BlurText(title, style: serif(48, height: 1.02), align: WrapAlignment.center, delay: const Duration(milliseconds: 150))
                else
                  Opacity(opacity: 0, child: Text(title, style: serif(48, height: 1.02), textAlign: TextAlign.center)),
                const SizedBox(height: 18),
                if (active)
                  BlurIn(delay: const Duration(milliseconds: 650), child: Text(body, style: sans(15.5, color: C.ink2, height: 1.45), textAlign: TextAlign.center)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small banknote-like card: the number the app is about.
class _MiniFuture extends StatelessWidget {
  const _MiniFuture();

  @override
  Widget build(BuildContext context) => Container(
        width: 250,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        decoration: BoxDecoration(
          color: C.raised,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: C.rule.withValues(alpha: 0.08)),
          boxShadow: [BoxShadow(color: C.ink.withValues(alpha: 0.10), blurRadius: 40, offset: const Offset(0, 18))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('In 20 years', style: sans(13, color: C.ink2)),
            const SizedBox(height: 4),
            Text('€148,230', style: figures(serif(40, color: C.greenInk))),
            const SizedBox(height: 14),
            SizedBox(height: 70, width: double.infinity, child: CustomPaint(painter: _CurvePainter())),
          ],
        ),
      );
}

class _CurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()..moveTo(0, s.height);
    for (var i = 1; i <= 40; i++) {
      final t = i / 40;
      path.lineTo(s.width * t, s.height - (s.height - 6) * (t * t * 0.8 + t * 0.2));
    }
    canvas.drawPath(path, Paint()..color = C.green..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round);
    final end = Offset(s.width, 6);
    canvas.drawCircle(end, 11, Paint()..color = C.green.withValues(alpha: 0.25));
    canvas.drawCircle(end, 4.5, Paint()..color = C.green);
  }

  @override
  bool shouldRepaint(_CurvePainter old) => false;
}

class _Seal extends StatelessWidget {
  const _Seal();

  @override
  Widget build(BuildContext context) => Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(color: C.greenSoft, shape: BoxShape.circle, border: Border.all(color: C.green.withValues(alpha: 0.4))),
        child: CustomPaint(painter: _LockPainter()),
      );
}

class _LockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = C.greenInk..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round;
    final c = s.center(Offset.zero);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, 7), width: 34, height: 26), const Radius.circular(7)), Paint()..color = C.greenInk);
    canvas.drawArc(Rect.fromCenter(center: c.translate(0, -6), width: 22, height: 26), 3.14159, 3.14159, false, p);
    canvas.drawLine(c.translate(-11, -6), c.translate(-11, -1), p);
    canvas.drawLine(c.translate(11, -6), c.translate(11, -1), p);
  }

  @override
  bool shouldRepaint(_LockPainter old) => false;
}
