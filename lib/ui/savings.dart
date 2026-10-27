import 'package:flutter/widgets.dart';

import '../format.dart';
import '../projection.dart';
import '../state.dart';
import '../theme.dart';
import 'lists.dart';

/// The same money three ways, in plain words: kept as cash, in a savings
/// account, or invested as planned. Bars grow from zero so the gap is the point.
class SavingsCompare extends StatelessWidget {
  const SavingsCompare(this.state, {super.key, required this.plan, required this.cautious, required this.savings});

  final AppState state;
  final Projection plan;
  final Projection cautious;
  final Projection savings;

  @override
  Widget build(BuildContext context) {
    final cash = plan.contributed.last;
    final top = [plan.end, savings.end, cash].reduce((a, b) => a > b ? a : b);
    final gap = plan.end - savings.end;
    final rate = state.savingsRate;
    final rateText = '${rate.toStringAsFixed(rate % 1 == 0 ? 0 : (rate * 10) % 1 == 0 ? 1 : 2)}%';
    final bank = rate == defaultSavingsRate ? 'a Raiffeisen savings account' : 'a savings account at $rateText';
    return Group(
      header: 'VERSUS A SAVINGS ACCOUNT',
      footer: 'Savings rate: $rateText a year, what Raiffeisen Online Sparen pays at several regional banks in October 2026. Other banks pay more or less, so you can change it under Assumptions. Before tax. Savings are protected up to €100,000; investments can lose value.',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gap >= 0 ? 'Investing as planned ends ${eur(gap)} ahead of $bank.' : 'In this case $bank ends ${eur(-gap)} ahead.',
                style: serif(24, height: 1.12, tracking: -0.4),
              ),
              const SizedBox(height: 6),
              Text('Same money, same ${eur(state.monthly)} a month, ${state.years} years.', style: sans(13.5, color: C.ink2)),
              const SizedBox(height: 20),
              _Bar('Kept as cash', 'No growth, just what you put in', cash, top, C.sand),
              _Bar('Savings account', 'Grows slowly and safely', savings.end, top, C.navy),
              _Bar('Invested as planned', 'Grows more, with ups and downs', plan.end, top, C.green, strong: true),
              const SizedBox(height: 6),
              Text(
                cautious.end < savings.end ? 'In the cautious case it would end ${eur(savings.end - cautious.end)} behind. That is the price of a higher return.' : 'Even in the cautious case it ends ${eur(cautious.end - savings.end)} ahead.',
                style: sans(13, color: C.ink2, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.title, this.note, this.value, this.top, this.color, {this.strong = false});

  final String title;
  final String note;
  final double value;
  final double top;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text(title, style: sans(15, weight: strong ? FontWeight.w500 : FontWeight.w400))),
                Text(eur(value), style: figures(sans(16, weight: FontWeight.w500, color: strong ? C.greenInk : C.ink))),
              ],
            ),
            const SizedBox(height: 2),
            Text(note, style: sans(12.5, color: C.ink2)),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: top <= 0 ? 0 : (value / top).clamp(0, 1)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, f, _) => Container(
                height: 10,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(color: C.ink.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(5)),
                child: FractionallySizedBox(widthFactor: f, heightFactor: 1, child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)))),
              ),
            ),
          ],
        ),
      );
}
