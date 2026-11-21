import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_future/projection.dart';
import 'package:the_future/ui/chart.dart';

void main() {
  const mix = {Kind.fund: 1.0};

  test('no growth just adds up', () {
    final p = project(
      start: {Kind.fund: 1000},
      mix: mix,
      monthly: 100,
      months: 12,
      yearlyReturn: {Kind.fund: 0},
    );
    expect(p.end, closeTo(2200, 1e-9));
    expect(p.added, closeTo(1200, 1e-9));
    expect(p.growth, closeTo(0, 1e-9));
  });

  test('matches the annuity-due formula', () {
    const months = 240;
    final i = math.pow(1.12, 1 / 12) - 1;
    final expected = 100 * (math.pow(1 + i, months) - 1) / i * (1 + i);
    final p = project(
      start: {},
      mix: mix,
      monthly: 100,
      months: months,
      yearlyReturn: {Kind.fund: 12},
    );
    expect(p.end, closeTo(expected, 1e-6));
  });

  test('money added at the end of each month matches the ordinary annuity', () {
    final i = math.pow(1.065, 1 / 12) - 1;
    final p = project(start: {}, mix: mix, monthly: 300, months: 240, yearlyReturn: {Kind.fund: 6.5}, addAt: 1);
    expect(p.end, closeTo(300 * (math.pow(1 + i, 240) - 1) / i, 1e-6));
  });

  test('one-off lands in its month and is split by the mix', () {
    final p = project(
      start: {},
      mix: {Kind.fund: 0.5, Kind.crypto: 0.5},
      monthly: 0,
      months: 3,
      yearlyReturn: {Kind.fund: 0, Kind.crypto: 0},
      oneOffs: const [OneOff(2, 1000)],
    );
    expect(p.values, [0, 0, 1000, 1000]);
  });

  test('raise applies from the second year', () {
    final flat = project(start: {}, mix: mix, monthly: 100, months: 24, yearlyReturn: {Kind.fund: 0});
    final raised = project(start: {}, mix: mix, monthly: 100, months: 24, yearlyReturn: {Kind.fund: 0}, raisePercent: 10);
    expect(raised.end - flat.end, closeTo(12 * 10, 1e-9));
    expect(raised.contributed[13] - raised.contributed[12], closeTo(110, 1e-9));
  });

  test("today's money is the end amount over the inflation of the whole period", () {
    final real = project(start: {Kind.fund: 20000}, mix: mix, monthly: 300, months: 240, yearlyReturn: {Kind.fund: 6.5}, realTerms: true);
    final nominal = project(start: {Kind.fund: 20000}, mix: mix, monthly: 300, months: 240, yearlyReturn: {Kind.fund: 6.5});
    expect(real.end, closeTo(nominal.end / math.pow(1.02, 20), 1e-6));
    // A euro added at the start of year 20, at no return, is worth 1 / 1.02^20 today:
    // it still loses the 19 years of inflation before it was added.
    final late = project(start: {}, mix: mix, monthly: 0, months: 240, yearlyReturn: {Kind.fund: 0}, oneOffs: const [OneOff(229, 1)], realTerms: true);
    expect(late.end, closeTo(1 / math.pow(1.02, 20), 1e-12));
  });

  test('each kind grows at its own rate', () {
    final p = project(start: {Kind.fund: 1000, Kind.crypto: 1000}, mix: mix, monthly: 0, months: 12, yearlyReturn: {Kind.fund: 10, Kind.crypto: -20});
    expect(p.end, closeTo(1000 * 1.1 + 1000 * 0.8, 1e-9));
  });

  test('the chart scale steps in round amounts and sits just above the top', () {
    bool round(double step) {
      final e = math.pow(10, (math.log(step) / math.ln10).floor()).toDouble();
      return [1.0, 2.0, 2.5, 5.0, 10.0].any((m) => (step - m * e).abs() < e * 1e-9);
    }

    for (var v = 50.0; v < 5e7; v *= 1.0137) {
      for (final short in [true, false]) {
        final (top, n) = chartScale(v, short: short);
        expect(round(top / n), isTrue, reason: '$v: steps of ${top / n}');
        expect(top, greaterThanOrEqualTo(v * 1.04 - 1e-6));
        expect(top, lessThan(v * 2), reason: '$v: no more than double the room it needs');
      }
    }
    expect(chartScale(216000, short: false), (250000.0, 5), reason: 'was €250K in steps of €62.5K');
    expect([for (var i = 0; i <= 5; i++) shortEur(250000 * i / 5)], ['€0', '€50K', '€100K', '€150K', '€200K', '€250K']);
    expect(shortEur(2500), '€2.5K');
    expect(shortEur(1250000), '€1.25M');
  });
}
