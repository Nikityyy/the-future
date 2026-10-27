import 'dart:math' as math;

import 'prices.dart' show chartPeriods;
import 'projection.dart';
import 'snapshot.dart';

/// Made-up numbers so the app can be tried without Bitpanda.
Snapshot demoSnapshot([DateTime? now]) {
  now ??= DateTime.now().toUtc();
  const fund = <double>[310, 300, 300, 350, 300, 300, 320, 300, 300, 400, 300, 300];
  const crypto = <double>[60, 80, 0, 100, 60, 60, 120, 60, 80, 60, 40, 60];
  const total = 27673.20;
  List<(DateTime, double)> walk(Duration span, int points, double drift, double noise, int seed) => _walk(now!, total, span, points, drift, noise, seed);

  return Snapshot(
    generatedAt: now,
    history: {
      'day': walk(const Duration(days: 1), 96, 0.004, 0.003, 1),
      'week': walk(const Duration(days: 7), 84, 0.012, 0.006, 2),
      'month': walk(const Duration(days: 30), 90, 0.03, 0.01, 3),
      'six_month': walk(const Duration(days: 182), 120, 0.2, 0.02, 4),
      'year': walk(const Duration(days: 365), 180, 0.38, 0.025, 5),
      'all': walk(const Duration(days: 730), 240, 0.75, 0.03, 5),
    },
    holdings: const [
      Holding(name: 'FTSE All-World UCITS ETF', symbol: 'VWCE', kind: Kind.fund, amount: 142.6, value: 18420.35, invested: 15920.00, pid: 'demo'),
      Holding(name: 'MSCI World UCITS ETF', symbol: 'IWDA', kind: Kind.fund, amount: 38.2, value: 3611.90, invested: 3250.00, pid: 'demo'),
      Holding(name: 'Bitcoin', symbol: 'BTC', kind: Kind.crypto, amount: 0.0412, value: 2874.10, invested: 1980.00, pid: 'demo'),
      Holding(name: 'Ethereum', symbol: 'ETH', kind: Kind.crypto, amount: 0.78, value: 1655.40, invested: 1720.00, pid: 'demo'),
      Holding(name: 'Solana', symbol: 'SOL', kind: Kind.crypto, amount: 4.6, value: 612.85, invested: 540.00, pid: 'demo'),
      Holding(name: 'Gold', symbol: 'XAU', kind: Kind.metal, amount: 2.1, value: 498.60, invested: 420.00, pid: 'demo'),
    ],
    monthly: [
      for (var i = 0; i < 12; i++)
        () {
          final d = DateTime.utc(now!.year, now.month - 11 + i);
          return MonthRow(
            '${d.year}-${d.month.toString().padLeft(2, '0')}',
            {Kind.fund: fund[i], Kind.crypto: crypto[i], Kind.metal: 0},
          );
        }(),
    ],
    trades: [
      for (var i = 0; i < 12; i++)
        for (final (sym, name, kind, eur, price) in [('VWCE', 'FTSE All-World UCITS ETF', Kind.fund, fund[i], 118.0 + i), ('BTC', 'Bitcoin', Kind.crypto, crypto[i], 58000.0 + i * 900)])
          if (eur > 0)
            Trade(
              date: DateTime.utc(now.year, now.month - 11 + i, 3, 9).toIso8601String(),
              symbol: sym,
              name: name,
              kind: kind,
              side: 'buy',
              type: 'TRADE',
              amount: eur / price,
              price: price,
              value: eur,
            ),
    ],
  );
}

/// A wobbly walk that ends at [end] now, the way a real price moves.
List<(DateTime, double)> _walk(DateTime now, double end, Duration span, int points, double drift, double noise, int seed) {
  final r = math.Random(seed);
  final v = <double>[end];
  for (var i = 1; i < points; i++) {
    v.add(v.last / (1 + drift / points + (r.nextDouble() - 0.5) * noise));
  }
  return [for (var i = 0; i < points; i++) (now.subtract(span * ((points - 1 - i) / (points - 1))), v[points - 1 - i])];
}

/// Made-up prices for a demo holding over one of [chartPeriods]; crypto swings more.
List<(DateTime, double)> demoPrices(Holding h, String period) {
  final price = h.amount > 0 ? h.value / h.amount : 1.0;
  final wild = h.kind == Kind.crypto ? 2.5 : 1.0;
  final seed = h.symbol.codeUnits.fold(0, (a, c) => a * 31 + c) + period.length;
  final (days, points, drift) = switch (period) {
    'day' => (1, 96, 0.004),
    'week' => (7, 84, 0.012),
    'month' => (30, 90, 0.03),
    'six_month' => (182, 120, 0.15),
    'year' => (365, 180, 0.25),
    _ => (1826, 260, 0.9),
  };
  return _walk(DateTime.now(), price, Duration(days: days), points, drift * wild, 0.012 * wild * (points / 100), seed);
}
