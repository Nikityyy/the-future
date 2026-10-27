import 'dart:math' as math;

enum Kind { fund, crypto, metal }

/// Yearly return per asset kind: [cautious, expected, hopeful], in percent.
typedef Returns = Map<Kind, List<double>>;

const defaultReturns = <Kind, List<double>>{
  Kind.fund: [3.0, 6.5, 9.0],
  Kind.crypto: [-5.0, 7.0, 18.0],
  Kind.metal: [0.0, 3.0, 6.0],
};

const defaultInflation = 2.0;

/// What a plain savings account pays a year, in percent. Raiffeisen's online
/// daily-savings rate at several regional banks, October 2026.
const defaultSavingsRate = 1.25;

class OneOff {
  const OneOff(this.monthsFromNow, this.amount);

  /// 1 is next month.
  final int monthsFromNow;
  final double amount;
}

class Projection {
  const Projection(this.values, this.contributed);

  /// Total value at the end of every month, index 0 is today.
  final List<double> values;

  /// Start value plus everything added so far.
  final List<double> contributed;

  double get end => values.last;
  double get added => contributed.last - contributed.first;
  double get growth => end - contributed.last;
}

/// Month by month: money is added at the start of the month, then the month's
/// growth applies. [monthly] rises by [raisePercent] each year. With
/// [realTerms] the returns are taken after [inflation], so the result reads
/// in today's money.
Projection project({
  required Map<Kind, double> start,
  required Map<Kind, double> mix,
  required double monthly,
  required int months,
  required Map<Kind, double> yearlyReturn,
  double raisePercent = 0,
  List<OneOff> oneOffs = const [],
  bool realTerms = false,
  double inflation = defaultInflation,
}) {
  final bal = {for (final k in Kind.values) k: start[k] ?? 0};
  final rate = {
    for (final k in Kind.values)
      k: math.pow(
            (1 + (yearlyReturn[k] ?? 0) / 100) / (realTerms ? 1 + inflation / 100 : 1),
            1 / 12,
          ).toDouble() -
          1,
  };
  final values = <double>[bal.values.fold(0, (a, b) => a + b)];
  final contributed = <double>[values.first];
  var put = values.first;
  for (var m = 1; m <= months; m++) {
    final add = monthly * math.pow(1 + raisePercent / 100, (m - 1) ~/ 12) +
        oneOffs.where((o) => o.monthsFromNow == m).fold(0.0, (a, o) => a + o.amount);
    put += add;
    for (final k in Kind.values) {
      bal[k] = (bal[k]! + add * (mix[k] ?? 0)) * (1 + rate[k]!);
    }
    values.add(bal.values.fold(0, (a, b) => a + b));
    contributed.add(put);
  }
  return Projection(values, contributed);
}
