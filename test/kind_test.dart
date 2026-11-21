import 'dart:math' as math;

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
    expect(s.unitsOver(btc, [day(1), day(3), day(7), day(9)]), [1.5, 2.5, 3.5, 3]); // 3 - 1 - 1 + 0.5, ...
  });

  test('a trade in another asset does not move the units', () {
    final s = snap([_trade('ETH', Kind.crypto, 'buy', 5, 500, day(5))]);
    expect(s.unitsOver(btc, [day(1)]), [3]);
  });

  test('a kind\'s value is units times price, the price holding until the next one', () {
    final grid = [day(0), day(1), day(2), day(3)];
    final v = valueSeries(grid, [
      (units: [1.0, 1.0, 2.0, 2.0], prices: [(day(1), 10.0), (day(3), 20.0)], fallback: 0.0),
      (units: [4.0, 4.0, 4.0, 4.0], prices: const <(DateTime, double)>[], fallback: 5.0),
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
    final s = snap(const []).repriced([null], day(11));
    expect(s.value, 300);
    expect(s.pricedAt, isNull, reason: 'no price was read, so the numbers are still the sync\'s');
    final live = snap(const []).repriced([120], day(11));
    expect((live.value, live.pricedAt), (360.0, day(11)));
  });

  test('the value line goes on to the live prices, and only past its end', () {
    final s = Snapshot(generatedAt: day(10), holdings: const [btc], monthly: const [], history: {'week': [(day(3), 250.0), (day(10), 290.0)]});
    expect(s.historyNow('week'), s.history['week'], reason: 'no live prices yet');
    expect(s.repriced([120], day(11)).historyNow('week')!.last, (day(11), 360.0));
    expect(s.repriced([120], day(9)).historyNow('week')!.length, 2, reason: 'prices older than the line add nothing');
  });

  test('a candle\'s close sits at the candle\'s end, and the line starts at the first open', () {
    Map<String, dynamic> candle(DateTime t, double open, double close) => {
          'attributes': {'open': '$open', 'close': '$close', 'time': {'unix': '${t.millisecondsSinceEpoch ~/ 1000}'}},
        };
    // Daily candles, out of order, the last one still going.
    final line = candleLine([candle(day(1), 11, 12), candle(day(0), 10, 11), candle(day(2), 12, 15)], day(2).add(const Duration(hours: 6)));
    expect(line, [(day(0), 10.0), (day(1), 11.0), (day(2), 12.0), (day(2).add(const Duration(hours: 6)), 15.0)]);
  });

  test('a pause between sessions is not a longer candle', () {
    Map<String, dynamic> candle(DateTime t, double close) => {
          'attributes': {'open': '1', 'close': '$close', 'time': {'unix': '${t.millisecondsSinceEpoch ~/ 1000}'}},
        };
    DateTime at(int d, int h) => day(d).add(Duration(hours: h));
    final line = candleLine([candle(at(0, 15), 2), candle(at(0, 16), 3), candle(at(1, 9), 4)], day(5));
    expect([for (final p in line) p.$1], [at(0, 15), at(0, 16), at(0, 17), at(1, 10)], reason: 'hourly candles: the evening close is at 17:00, not the next morning');
  });

  test('the comparison puts the same euros into the index at the same moments', () {
    // The index doubles from day 0 to day 2 and stays; €100 at the start, €50 more bought on day 1.
    final index = [(day(0), 10.0), (day(1), 15.0), (day(2), 20.0)];
    final pts = [(day(0), 100.0), (day(1), 160.0), (day(2), 170.0), (day(3), 175.0)];
    final line = benchmarkLine(pts, index, [
      _trade('BTC', Kind.crypto, 'buy', 1, 50, day(1)),
      _trade('VWCE', Kind.fund, 'buy', 1, 999, day(1)), // another kind: left out below
      _trade('BTC', Kind.crypto, 'buy', 1, 30, day(-1)), // before the line starts: already in its first value
    ], kinds: {Kind.crypto});
    // 10 units at €10, then €50 buys 3.33 units at €15: 13.33 units.
    expect([for (final p in line) p.$2], [100.0, closeTo(200, 1e-9), closeTo(266.67, 0.01), closeTo(266.67, 0.01)]);
    expect([for (final p in line) p.$1], [for (final p in pts) p.$1]);
    final sale = benchmarkLine(pts, index, [_trade('BTC', Kind.crypto, 'sell', 1, 100, day(2))]);
    expect(sale.last.$2, closeTo(100, 1e-9), reason: '10 units, worth €200 on day 2, less €100 sold');
    expect(benchmarkLine([(day(-30), 90.0), ...pts], index, const []), isEmpty, reason: 'the index starts a month after the line: nothing to compare the start with');
  });

  test('units over a grid match counting back from today at every moment', () {
    // The plain way, one moment at a time, against random buys, sells and transfers.
    final r = math.Random(7);
    final trades = [
      for (var i = 0; i < 500; i++)
        _trade(r.nextInt(5) == 0 ? 'ETH' : 'BTC', Kind.crypto, const ['buy', 'sell', 'in', 'out', 'reward'][r.nextInt(5)], r.nextDouble(), 10, t0.add(Duration(hours: r.nextInt(24 * 60)))),
    ];
    final s = snap(trades);
    final grid = [for (var h = -24; h < 24 * 62; h += 7) t0.add(Duration(hours: h)), t0.add(const Duration(hours: 300))]..sort();
    double plain(DateTime t) {
      var units = btc.amount;
      for (final x in trades) {
        final d = DateTime.parse(x.date);
        if (x.symbol != 'BTC' || !d.isAfter(t)) continue;
        units -= switch (x.side) { 'buy' || 'in' => x.amount, 'sell' || 'out' => -x.amount, _ => 0 };
      }
      return units < 0 ? 0 : units;
    }

    final fast = s.unitsOver(btc, grid);
    for (final (i, t) in grid.indexed) {
      expect(fast[i], closeTo(plain(t), 1e-9), reason: '$t');
    }
  });
}
