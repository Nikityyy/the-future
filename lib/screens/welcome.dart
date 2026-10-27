import 'package:flutter/widgets.dart';

import '../platform/haptics.dart';
import '../platform/web_glue.dart';
import '../projection.dart';
import '../state.dart';
import '../theme.dart';
import '../ui/basics.dart';
import '../ui/chart.dart';
import '../ui/chrome.dart';
import '../ui/journey.dart';
import '../ui/mark.dart';
import '../ui/ruler.dart';
import 'connect.dart';

/// Three screens: the name, the number the app is about, and a number to slide.
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

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: C.ground,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) {
                  Haptics.selection();
                  setState(() => _page = i);
                },
                children: [
                  _Slide(
                    active: _page == 0,
                    art: const AppMark(size: 136),
                    title: 'Welcome to The Future',
                    body: 'Your Bitpanda investments, and what they become if you keep going.',
                  ),
                  _Slide(
                    active: _page == 1,
                    art: const Journey(today: '€27,673', future: '€148,230', caption: 'IN 20 YEARS'),
                    title: 'Your money, twenty years on',
                    body: 'See what your ETFs and crypto grow into at the pace you invest today.',
                  ),
                  _LiveSlide(active: _page == 2),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
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
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Row(
                children: [
                  Expanded(child: AppButton('Try the demo', filled: false, onTap: widget.state.startDemo)),
                  const SizedBox(width: 12),
                  Expanded(child: AppButton('Connect Bitpanda', onTap: () => showSheet<void>(context, (_) => ConnectSheet(widget.state)))),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + browserSafeArea().bottom),
              child: Text('Free. No account. Your key never leaves GitHub.', style: sans(12.5, color: C.ink2), textAlign: TextAlign.center),
            ),
          ],
        ),
      );
}

class _Slide extends StatelessWidget {
  const _Slide({required this.active, required this.art, required this.title, required this.body});

  final bool active;
  final Widget art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(32, browserSafeArea().top, 32, 0),
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 1,
                child: active
                    ? BlurIn(key: ValueKey(title), duration: const Duration(milliseconds: 1100), child: art)
                    : Opacity(opacity: 0, child: art),
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  if (active)
                    BlurText(title, style: serif(48, height: 1.02), align: WrapAlignment.center, delay: const Duration(milliseconds: 250))
                  else
                    Opacity(opacity: 0, child: Text(title, style: serif(48, height: 1.02), textAlign: TextAlign.center)),
                  const SizedBox(height: 18),
                  if (active) BlurIn(delay: const Duration(milliseconds: 750), child: Text(body, style: sans(15.5, color: C.ink2, height: 1.45), textAlign: TextAlign.center)),
                ],
              ),
            ),
          ],
        ),
      );
}

/// The real chart and ruler with sample money, so the idea is in your hands before you sign in.
class _LiveSlide extends StatefulWidget {
  const _LiveSlide({required this.active});

  final bool active;

  @override
  State<_LiveSlide> createState() => _LiveSlideState();
}

class _LiveSlideState extends State<_LiveSlide> {
  double _monthly = 200;

  static const _start = {Kind.fund: 10000.0};
  static const _mix = {Kind.fund: 1.0};

  Projection _run(double yearly) => project(start: _start, mix: _mix, monthly: _monthly, months: 240, yearlyReturn: {Kind.fund: yearly});

  List<double> _thin(List<double> v) => [for (var i = 0; i < v.length; i += 2) v[i], v.last];

  @override
  Widget build(BuildContext context) {
    final low = _run(3), mid = _run(6.5), high = _run(9);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, browserSafeArea().top + 12, 24, 0),
      child: Column(
        children: [
          if (widget.active)
            BlurText('Slide a number, see your years', style: serif(38, height: 1.02), align: WrapAlignment.center)
          else
            Opacity(opacity: 0, child: Text('Slide a number, see your years', style: serif(38, height: 1.02), textAlign: TextAlign.center)),
          const SizedBox(height: 18),
          CountUp(mid.end, style: serif(60, color: C.greenInk, tracking: -2)),
          const SizedBox(height: 4),
          Text('in 20 years, from €10,000 today', style: sans(14, color: C.ink2)),
          Expanded(
            child: Center(
              child: GrowthChart(low: _thin(low.values), mid: _thin(mid.values), high: _thin(high.values), start: DateTime.now(), years: 20, restartKey: 'welcome', height: 230, interactive: false),
            ),
          ),
          Align(alignment: Alignment.centerLeft, child: Text('Amount you’ll add monthly', style: sans(15, weight: FontWeight.w500))),
          RulerSlider(label: 'Monthly amount', value: _monthly, min: 0, max: 1000, step: 5, onChanged: (v) => setState(() => _monthly = v)),
        ],
      ),
    );
  }
}
