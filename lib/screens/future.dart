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
          final real = state.projectionFor(state.scenario, real: true).end;
          final goal = state.filter.isEmpty ? state.goal : null;
          final milestones = _milestones(mid.values, now: DateTime.now());
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
                      BlurIn(blur: 0, duration: const Duration(milliseconds: 500), child: CountUp(mid.end, style: serif(72, color: C.greenInk, tracking: -2.4))),
                      const SizedBox(height: 10),
                      Pressable(
                        onTap: () => showSheet<void>(context, (_) => AssumptionsSheet(state)),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: 'On your account in ${state.years} years.\nWorth ≈ ${eur(real)} in today’s money  '),
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
                          style: sans(14.5, color: C.ink2, height: 1.45),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (milestones.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(milestones, style: figures(sans(13.5, weight: FontWeight.w500, color: C.greenInk)), textAlign: TextAlign.center),
                      ],
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
                    monthsPerPoint: step,
                    goal: goal?.amount,
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
                    state.mode == Mode.demo || usual > 0 ? 'Your last six months average ${eur(usual)} a month.' : 'No recent purchases found. Slide to set what you plan to add.',
                    style: sans(13, color: C.ink2, height: 1.4),
                  ),
                ),
              ),
              if (goal != null) SliverToBoxAdapter(child: _GoalCard(state)),
              SliverToBoxAdapter(
                child: Group(
                  header: 'WHERE ${eur(mid.end)} COMES FROM',
                  footer: 'Growth at ${_rate(state)} a year on average.',
                  children: [_Parts(today: mid.contributed.first, added: mid.added, growth: mid.growth)],
                ),
              ),
              SliverToBoxAdapter(child: SavingsCompare(state, plan: mid, cautious: low, savings: state.savingsFor())),
              SliverToBoxAdapter(
                child: Group(
                  header: 'YOUR PLAN',
                  footer: 'A projection, not a forecast. Before taxes and fees. Not financial advice.',
                  children: [
                    Row2(title: 'Goal', trailing: Text(state.goal == null ? 'Set one' : '${eur(state.goal!.amount)} by ${state.goal!.year}', style: figures(sans(15, color: C.ink2))), chevron: true, onTap: () => showSheet<void>(context, (_) => GoalSheet(state), height: state.goal == null ? 400 : 450)),
                    Row2(title: 'One-time additions', trailing: Text(state.oneOffs.isEmpty ? 'None' : '${state.oneOffs.length}', style: sans(15, color: C.ink2)), chevron: true, onTap: () => showSheet<void>(context, (_) => OneOffsSheet(state))),
                    Row2(title: 'Assumptions', subtitle: 'Returns, inflation, yearly raise', chevron: true, onTap: () => showSheet<void>(context, (_) => AssumptionsSheet(state))),
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

  /// The next round amounts the expected line passes, with the year.
  static String _milestones(List<double> v, {required DateTime now}) {
    const marks = [10e3, 25e3, 50e3, 100e3, 250e3, 500e3, 1e6, 2.5e6, 5e6, 10e6];
    final out = <String>[];
    for (final m in marks) {
      if (m <= v.first) continue;
      final i = v.indexWhere((x) => x >= m);
      if (i < 0) break;
      final label = m >= 1e6 ? '€${(m / 1e6).toStringAsFixed(m % 1e6 == 0 ? 0 : 1)}M' : '€${(m / 1e3).round()}k';
      out.add('$label in ${DateTime(now.year, now.month + i).year}');
      if (out.length == 2) break;
    }
    return hideAmounts || out.isEmpty ? '' : 'Passes ${out.join('  ·  ')}';
  }
}

/// Today's money, what you add and the growth, as one bar.
class _Parts extends StatelessWidget {
  const _Parts({required this.today, required this.added, required this.growth});

  final double today, added, growth;

  @override
  Widget build(BuildContext context) {
    final parts = [('You have today', today, C.sand), ('You add', added, C.navy), ('Growth', growth, C.green)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, p) in parts.indexed)
                    if (p.$2 > 0) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(flex: (p.$2 * 100).round().clamp(1, 1 << 30), child: ColoredBox(color: p.$3)),
                    ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final p in parts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: p.$3, shape: BoxShape.circle)),
                  const SizedBox(width: 9),
                  Expanded(child: Text(p.$1, style: sans(15))),
                  Text('${p.$3 == C.sand ? '' : p.$2 < 0 ? '−' : '+'}${eur(p.$2.abs())}', style: figures(sans(15.5, weight: FontWeight.w500, color: p.$3 == C.green ? C.greenInk : C.ink))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// How the goal stands: progress today and whether the plan gets there in time.
class _GoalCard extends StatelessWidget {
  const _GoalCard(this.state);
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final g = state.goal!;
    final today = state.snapshot!.value;
    final reached = state.goalReachedIn();
    final onTrack = reached != null && reached <= g.year;
    final need = onTrack ? null : state.monthlyForGoal();
    final scenario = _scenarioNames[state.scenario].toLowerCase();
    final String status;
    if (onTrack) {
      status = 'On track. At ${eur(state.monthly)} a month the $scenario case gets there in $reached.';
    } else if (need == null) {
      status = 'Out of reach by ${g.year} in the $scenario case. Try a later year.';
    } else {
      status = 'Add ${eur(need)} a month instead of ${eur(state.monthly)} to get there by ${g.year}.${reached != null ? ' At today’s amount it takes until $reached.' : ''}';
    }
    return Group(
      header: 'YOUR GOAL',
      children: [
        Pressable(
          onTap: () => showSheet<void>(context, (_) => GoalSheet(state), height: state.goal == null ? 400 : 450),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${eur(g.amount)} by ${g.year}', style: serif(26, tracking: -0.4)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    height: 10,
                    alignment: Alignment.centerLeft,
                    color: C.ink.withValues(alpha: 0.06),
                    child: FractionallySizedBox(widthFactor: (today / g.amount).clamp(0.0, 1.0), heightFactor: 1, child: const ColoredBox(color: C.green)),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${eur(today)} today, ${(today / g.amount * 100).clamp(0, 100).toStringAsFixed(0)}% of the way', style: figures(sans(13, color: C.ink2))),
                const SizedBox(height: 12),
                Text(status, style: sans(15, weight: FontWeight.w500, color: onTrack ? C.greenInk : C.ink, height: 1.4)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
