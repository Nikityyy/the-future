import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_future/export.dart';
import 'package:the_future/format.dart';
import 'package:the_future/projection.dart';
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
}
