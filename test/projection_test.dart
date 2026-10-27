import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_future/projection.dart';

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

  test('raise applies from the second year, real terms shrink the result', () {
    final flat = project(start: {}, mix: mix, monthly: 100, months: 24, yearlyReturn: {Kind.fund: 0});
    final raised = project(start: {}, mix: mix, monthly: 100, months: 24, yearlyReturn: {Kind.fund: 0}, raisePercent: 10);
    expect(raised.end - flat.end, closeTo(12 * 10, 1e-9));
    final real = project(start: {Kind.fund: 1000}, mix: mix, monthly: 0, months: 120, yearlyReturn: {Kind.fund: 5}, realTerms: true);
    final nominal = project(start: {Kind.fund: 1000}, mix: mix, monthly: 0, months: 120, yearlyReturn: {Kind.fund: 5});
    expect(real.end, lessThan(nominal.end));
  });
}
