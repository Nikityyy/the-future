import 'package:flutter_test/flutter_test.dart';
import 'package:the_future/prices.dart';
import 'package:the_future/projection.dart';
import 'package:the_future/snapshot.dart';

Trade _trade(String symbol, Kind kind, String side, double amount, double value, DateTime d) =>
    Trade(date: d.toIso8601String(), symbol: symbol, name: symbol, kind: kind, side: side, type: 'TRADE', amount: amount, value: value);

void main() {
  final t0 = DateTime.utc(2026, 1, 1);
  DateTime day(int n) => t0.add(Duration(days: n));
  const btc = Holding(name: 'Bitcoin', symbol: 'BTC', kind: Kind.crypto, amount: 3, value: 300, invested: 200);

  Snapshot snap(List<Trade> trades) => Snapshot(generatedAt: day(10), holdings: const [btc], monthly: const [], trades: trades);

  test('units held then: today\'s amount, undone by the trades since', () {
    final s = snap([_trade('BTC', Kind.crypto, 'buy', 1, 50, day(2)), _trade('BTC', Kind.crypto, 'buy', 1, 60, day(6)), _trade('BTC', Kind.crypto, 'sell', 0.5, 40, day(8))]);
    expect(s.unitsAt(btc, day(1)), 1.5); // 3 - 1 - 1 + 0.5
    expect(s.unitsAt(btc, day(3)), 2.5);
    expect(s.unitsAt(btc, day(7)), 3.5);
    expect(s.unitsAt(btc, day(9)), 3);
  });

  test('a trade in another asset does not move the units', () {
    final s = snap([_trade('ETH', Kind.crypto, 'buy', 5, 500, day(5))]);
    expect(s.unitsAt(btc, day(1)), 3);
  });

  test('a kind\'s value is units times price, the price holding until the next one', () {
    final grid = [day(0), day(1), day(2), day(3)];
    final v = valueSeries(grid, [
      (units: (DateTime t) => t.isBefore(day(2)) ? 1.0 : 2.0, prices: [(day(1), 10.0), (day(3), 20.0)], fallback: 0.0),
      (units: (DateTime _) => 4.0, prices: const [], fallback: 5.0),
    ]);
    // Before its first price a holding uses that first price; one with no prices stays at its fallback.
    expect([for (final p in v) p.$2], [1 * 10 + 20, 1 * 10 + 20, 2 * 10 + 20, 2 * 20 + 20]);
  });

  test('money added counts only for the kinds asked', () {
    final s = snap([_trade('BTC', Kind.crypto, 'buy', 1, 100, day(2)), _trade('VWCE', Kind.fund, 'buy', 1, 300, day(2))]);
    expect(s.netAddedBetween(day(0), day(10)), 400);
    expect(s.netAddedBetween(day(0), day(10), kinds: {Kind.crypto}), 100);
    expect(s.weightedAddedBetween(day(0), day(10), kinds: {Kind.fund}), closeTo(300 * 0.8, 1e-9));
  });

  test('a holding at a new price keeps what was invested', () {
    final h = btc.at(120);
    expect((h.value, h.invested, h.amount), (360.0, 200.0, 3.0));
    final s = snap(const []).repriced([null]);
    expect(s.value, 300);
    expect(snap(const []).repriced([120]).value, 360);
  });
}
