import 'package:flutter/widgets.dart';

import '../platform/web_glue.dart';
import '../projection.dart';
import '../state.dart';
import '../theme.dart';
import '../ui/basics.dart';
import '../ui/chart.dart';
import '../ui/chrome.dart';
import '../ui/mark.dart';
import '../ui/ruler.dart';
import 'connect.dart';

/// The first screen: the promise in one line, and the app itself working
/// under your thumb before you have connected anything.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen(this.state, {super.key});

  final AppState state;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  double _monthly = 200;

  static const _start = {Kind.fund: 10000.0};
  static const _mix = {Kind.fund: 1.0};

  Projection _run(double yearly) => project(start: _start, mix: _mix, monthly: _monthly, months: 240, yearlyReturn: {Kind.fund: yearly});

  List<double> _thin(List<double> v) => [for (var i = 0; i < v.length; i += 2) v[i], v.last];

  /// Below this height the chart has no room left: the page keeps this
  /// height and scrolls instead of squeezing the chart flat.
  static const _minHeight = 720.0;

  @override
  Widget build(BuildContext context) {
    final low = _run(3), mid = _run(6.5), high = _run(9);
    final safe = browserSafeArea();
    return ColoredBox(
      color: C.ground,
      child: LayoutBuilder(
        builder: (context, box) => box.maxHeight >= _minHeight
            ? _page(safe, low, mid, high)
            : SingleChildScrollView(child: SizedBox(height: _minHeight, child: _page(safe, low, mid, high))),
      ),
    );
  }

  Widget _page(EdgeInsets safe, Projection low, Projection mid, Projection high) => Padding(
        padding: EdgeInsets.only(top: safe.top + 14, bottom: safe.bottom + 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const AppMark(size: 26),
                  const SizedBox(width: 9),
                  Text('The Future', style: serif(19)),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: BlurText('See what your money becomes.', style: serif(42, height: 1.02, tracking: -0.8)),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: BlurIn(
                delay: const Duration(milliseconds: 450),
                child: Text('Your Bitpanda ETFs and crypto, years from now. Slide the ruler to try it.', style: sans(15.5, color: C.ink2, height: 1.4)),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: BlurIn(
                delay: const Duration(milliseconds: 650),
                child: Column(
                  children: [
                    CountUp(mid.end, style: serif(54, color: C.greenInk, tracking: -1.8)),
                    Text('in 20 years, from €10,000 today', style: sans(13.5, color: C.ink2)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 20, 0),
                        child: LayoutBuilder(
                          builder: (context, box) => GrowthChart(
                            low: _thin(low.values),
                            mid: _thin(mid.values),
                            high: _thin(high.values),
                            start: DateTime.now(),
                            years: 20,
                            restartKey: 'welcome',
                            height: box.maxHeight,
                            interactive: false,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text('If you add each month', style: sans(14, weight: FontWeight.w500)),
            ),
            RulerSlider(label: 'Monthly amount', value: _monthly, min: 0, max: 1000, step: 5, onChanged: (v) => setState(() => _monthly = v)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: AppButton('Connect Bitpanda', onTap: () => showPage<void>(context, (_) => ConnectSheet(widget.state))),
            ),
            const SizedBox(height: 10),
            Center(child: PillButton('Try it with sample numbers', onTap: widget.state.startDemo)),
            const SizedBox(height: 10),
            if (widget.state.pinErased)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('This phone forgot its PIN. Connect again with your passphrase; your plan is kept.', style: sans(12.5, color: C.loss, height: 1.4), textAlign: TextAlign.center),
              )
            else
              Center(child: Text('Free. No account. Your key stays on GitHub.', style: sans(12.5, color: C.ink2))),
          ],
        ),
      );
}
