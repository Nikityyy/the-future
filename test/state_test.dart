import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  test('the filter starts on everything and a first tap picks one kind', () async {
    final s = await demo();
    expect(s.active, {Kind.fund, Kind.crypto, Kind.metal});
    s.toggleKind(Kind.fund);
    expect(s.active, {Kind.fund});
    s.toggleKind(Kind.crypto);
    expect(s.active, {Kind.fund, Kind.crypto});
    s.toggleKind(Kind.fund);
    s.toggleKind(Kind.crypto);
    expect(s.filter, isEmpty, reason: 'nothing left falls back to all');
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
}
