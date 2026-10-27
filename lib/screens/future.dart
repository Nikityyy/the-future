import 'package:flutter/widgets.dart';

import '../format.dart';
import '../platform/web_glue.dart';
import '../state.dart';
import '../theme.dart';
import '../ui/basics.dart';
import '../ui/chart.dart';
import '../ui/chrome.dart';
import '../ui/filter.dart';
import '../ui/lists.dart';
import '../ui/ruler.dart';
import '../ui/savings.dart';
import 'plan.dart';

const _scenarioNames = ['Cautious', 'Expected', 'Hopeful'];
const _horizons = [5, 10, 20, 30];

class FuturePage extends StatelessWidget {
  const FuturePage(this.state, {super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final s = state.snapshot;
          if (s == null) return const SizedBox();
          final low = state.projectionFor(0);
          final mid = state.projectionFor(state.scenario);
          final high = state.projectionFor(2);
          final usual = state.usual;
          final changed = state.monthlyOverride != null && state.monthlyOverride != usual;
          final now = DateTime.now();
          final step = (state.years * 12 / 120).ceil();
          List<double> thin(List<double> v) => [for (var i = 0; i < v.length; i += step) v[i], if ((v.length - 1) % step != 0) v.last];
          return CustomScrollView(
            slivers: [
              LargeTitle('Future', trailing: EyeButton(state)),
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 6), child: KindChips(state))),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
                  child: Column(
                    children: [
                      BlurIn(child: CountUp(mid.end, style: serif(72, color: C.greenInk, tracking: -2.4))),
                      const SizedBox(height: 10),
                      Pressable(
                        onTap: () => showSheet<void>(context, (_) => AssumptionsSheet(state)),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: 'Estimated value in ${state.years} years${state.realTerms ? ', in today’s money' : ''}  '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                width: 15,
                                height: 15,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.ink3, width: 1)),
                                child: Text('i', style: sans(10, weight: FontWeight.w600, color: C.ink3, height: 1)),
                              ),
                            ),
                          ]),
                          style: sans(14.5, color: C.ink2),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 20, 4),
                  child: GrowthChart(
                    low: thin(low.values),
                    mid: thin(mid.values),
                    high: thin(high.values),
                    start: now,
                    years: state.years,
                    restartKey: '${state.years}${state.scenario}',
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Segments(labels: _scenarioNames, index: state.scenario, onChanged: (i) => state.setPlan(scenario: i)),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Segments(labels: [for (final y in _horizons) '$y years'], index: _horizons.indexOf(state.years).clamp(0, 3), onChanged: (i) => state.setPlan(years: _horizons[i])),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
                  child: Row(
                    children: [
                      Expanded(child: Text('Amount you’ll add monthly', style: sans(15, weight: FontWeight.w500))),
                      if (changed)
                        PillButton('Reset to ${eur(usual)}', onTap: () => state.setPlan(monthly: null)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: RulerSlider(
                    label: 'Monthly amount',
                    value: state.monthly,
                    min: 0,
                    max: 3000,
                    step: 5,
                    onChanged: (v) => state.setPlan(monthly: v),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 2, 24, 26),
                  child: Text(
                    state.mode == Mode.demo || usual > 0 ? 'Your last six months average ${eur(usual)} a month. Slide to see what changes if you add more or less from next month.' : 'No recent purchases found. Slide to set what you plan to add each month.',
                    style: sans(13, color: C.ink2, height: 1.4),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Group(
                  header: 'WHERE ${eur(mid.end)} COMES FROM',
                  children: [
                    Row2(title: 'You have today', trailing: Text(eur(mid.contributed.first), style: figures(sans(16)))),
                    Row2(title: 'You add', subtitle: '${eur(state.monthly)} a month for ${state.years} years', trailing: Text('+${eur(mid.added)}', style: figures(sans(16)))),
                    Row2(title: 'It grows by', subtitle: 'At ${_rate(state)} a year on average', trailing: Text('+${eur(mid.growth)}', style: figures(sans(16, color: C.greenInk, weight: FontWeight.w500)))),
                  ],
                ),
              ),
              SliverToBoxAdapter(child: SavingsCompare(state, plan: mid, cautious: low, savings: state.savingsFor())),
              SliverToBoxAdapter(
                child: Group(
                  header: 'YOUR PLAN',
                  footer: 'A projection, not a forecast: real returns vary, crypto most of all. Taxes and fees are not included. Not financial advice.',
                  children: [
                    Row2(title: 'One-time additions', trailing: Text(state.oneOffs.isEmpty ? 'None' : '${state.oneOffs.length}', style: sans(15, color: C.ink2)), chevron: true, onTap: () => showSheet<void>(context, (_) => OneOffsSheet(state))),
                    Row2(title: 'Yearly raise', trailing: Text(state.raisePercent == 0 ? 'Off' : '${state.raisePercent.toStringAsFixed(state.raisePercent % 1 == 0 ? 0 : 1)}%', style: sans(15, color: C.ink2)), chevron: true, onTap: () => showSheet<void>(context, (_) => AssumptionsSheet(state))),
                    Row2(title: 'Assumptions', subtitle: 'Returns per asset type, inflation', chevron: true, onTap: () => showSheet<void>(context, (_) => AssumptionsSheet(state))),
                  ],
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: Dock.clearance(context) + browserSafeArea().top)),
            ],
          );
        },
      );

  static String _rate(AppState s) {
    final mix = s.snapshot!.mixFor(s.active);
    var r = 0.0;
    for (final e in mix.entries) {
      r += e.value * s.returns[e.key]![s.scenario];
    }
    return '${r.toStringAsFixed(1)}%';
  }
}
