import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_future/export.dart';
import 'package:the_future/format.dart';
import 'package:the_future/projection.dart';
import 'package:the_future/snapshot.dart';
import 'package:the_future/state.dart';

Future<AppState> demo([Map<String, Object> saved = const {}]) async {
  SharedPreferences.setMockInitialValues({'mode': 'demo', ...saved});
  return AppState(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => hideAmounts = false);

  test('the filter starts on everything and a tap picks one kind', () async {
    final s = await demo();
    expect(s.active, {Kind.fund, Kind.crypto, Kind.metal});
    s.toggleKind(Kind.fund);
    expect(s.active, {Kind.fund});
    s.toggleKind(Kind.crypto);
    expect(s.active, {Kind.crypto}, reason: 'another chip switches to it, it does not add');
    s.toggleKind(Kind.crypto);
    expect(s.filter, isEmpty, reason: 'the same chip again shows everything');
  });

  test('the projection only counts the picked kinds', () async {
    final s = await demo();
    final all = s.projectionFor(1).end;
    s.toggleKind(Kind.fund);
    final funds = s.projectionFor(1).end;
    expect(funds, lessThan(all));
    expect(s.monthly, s.snapshot!.usualMonthly[Kind.fund]!.roundToDouble());
  });

  test('the filter and the hidden numbers are remembered', () async {
    final s = await demo();
    s.toggleKind(Kind.crypto);
    s.setHide(true);
    expect(eur(1234), '€•••••');
    final prefs = await SharedPreferences.getInstance();
    hideAmounts = false;
    final again = AppState(prefs);
    expect(again.filter, {Kind.crypto});
    expect(again.hide, isTrue);
    expect(hideAmounts, isTrue);
  });

  test('a savings account ends between cash and the plan, and the rate is remembered', () async {
    final s = await demo();
    await Future<void>.delayed(Duration.zero);
    final plan = s.projectionFor(1), save = s.savingsFor();
    expect(save.end, greaterThan(plan.contributed.last));
    expect(save.end, lessThan(plan.end));
    s.setPlan(savingsRate: 0);
    expect(s.savingsFor().end, closeTo(plan.contributed.last, 0.01));
    final again = await demo({'plan': '{"savings":2.5}'});
    expect(again.savingsRate, 2.5);
  });

  test('all is the sum of its parts, and each view keeps its own monthly amount', () async {
    final s = await demo();
    final all = s.projectionFor(1).end;
    var parts = 0.0;
    for (final k in s.snapshot!.kinds) {
      s.toggleKind(k);
      parts += s.projectionFor(1).end;
    }
    s.showAllKinds();
    expect(all, closeTo(parts, 1), reason: 'same money in, same returns, so the views must add up');

    s.setPlan(monthly: 1000.0);
    s.toggleKind(Kind.crypto);
    expect(s.monthly, s.snapshot!.usualFor({Kind.crypto}).roundToDouble(), reason: 'crypto does not inherit the amount set for all');
    s.setPlan(monthly: 50.0);
    s.showAllKinds();
    expect(s.monthly, 1000);
    s.toggleKind(Kind.crypto);
    expect(s.monthly, 50);
  });

  test('the Markdown export holds every holding and transaction, unmasked', () async {
    final s = await demo();
    hideAmounts = true;
    final md = exportMarkdown(s, DateTime.utc(2026, 10, 27));
    for (final h in s.snapshot!.holdings) {
      expect(md, contains('| ${h.name} | ${h.symbol} |'));
    }
    final rows = RegExp(r'^\| \d{4}-\d{2}-\d{2} ', multiLine: true).allMatches(md).length;
    expect(rows, s.snapshot!.trades.length);
    expect(s.snapshot!.trades, isNotEmpty);
    expect(md, contains(s.snapshot!.value.toStringAsFixed(2)), reason: 'hiding amounts on screen must not mask the file');
    expect(md, contains('MADE-UP DEMO NUMBERS'));
  });

  test('a goal says what monthly amount gets there, and that amount does', () async {
    final s = await demo();
    final year = DateTime.now().year + 10;
    s.setPlan(goal: (amount: 500000.0, year: year));
    final need = s.monthlyForGoal()!;
    expect(need, greaterThan(s.monthly), reason: '€500k in ten years needs more than the demo adds');
    expect(s.projectionFor(s.scenario, monthlyAmount: need, months: s.goalMonths).end, closeTo(500000, 1));
    s.setPlan(monthly: need + 1);
    expect(s.goalReachedIn(), lessThanOrEqualTo(year));
    s.setPlan(goal: (amount: 1000.0, year: year));
    expect(s.monthlyForGoal(), 0, reason: 'already there');
  });

  test('history change leaves out money added in the period', () async {
    final s = await demo();
    final t = s.snapshot!.trades.last;
    final at = DateTime.parse(t.date);
    final sameDay = s.snapshot!.trades.where((x) => x.date == t.date).fold(0.0, (a, x) => a + x.value!);
    expect(s.snapshot!.netAddedBetween(at.subtract(const Duration(days: 1)), at.add(const Duration(days: 1))), sameDay);
    expect(s.snapshot!.netAddedBetween(at.add(const Duration(days: 1)), at.add(const Duration(days: 2))), 0);
  });

  test('the history percent weights money by how long it was invested', () {
    // 1000 at the start, 1000 more at half time, 2100 at the end: a gain of 100
    // on 1000 + 1000 / 2 invested on average, so 6.67% (Modified Dietz).
    final t0 = DateTime.utc(2026, 1, 1), t1 = DateTime.utc(2026, 1, 31);
    final s = Snapshot(
      generatedAt: t1,
      holdings: const [],
      monthly: const [],
      trades: [Trade(date: t0.add(t1.difference(t0) ~/ 2).toIso8601String(), symbol: 'X', name: 'X', kind: Kind.fund, side: 'buy', type: 'TRADE', amount: 1, value: 1000)],
    );
    expect(2100 - 1000 - s.netAddedBetween(t0, t1), 100);
    expect(1000 + s.weightedAddedBetween(t0, t1), closeTo(1500, 1e-9));
  });
}
