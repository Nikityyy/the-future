import 'dart:math' as math;

import 'projection.dart';
import 'snapshot.dart';

/// Made-up numbers so the app can be tried without Bitpanda.
Snapshot demoSnapshot([DateTime? now]) {
  now ??= DateTime.now().toUtc();
  const fund = <double>[310, 300, 300, 350, 300, 300, 320, 300, 300, 400, 300, 300];
  const crypto = <double>[60, 80, 0, 100, 60, 60, 120, 60, 80, 60, 40, 60];
  // A wobbly walk that ends at today's value, the way a real portfolio moves.
  const total = 27673.20;
  List<(DateTime, double)> walk(Duration span, int points, double drift, double noise, int seed) {
    final r = math.Random(seed);
    final v = <double>[total];
    for (var i = 1; i < points; i++) {
      v.add(v.last / (1 + drift / points + (r.nextDouble() - 0.5) * noise));
    }
    return [for (var i = 0; i < points; i++) (now!.subtract(span * ((points - 1 - i) / (points - 1))), v[points - 1 - i])];
  }

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
      Holding(name: 'FTSE All-World UCITS ETF', symbol: 'VWCE', kind: Kind.fund, amount: 142.6, value: 18420.35, invested: 15920.00),
      Holding(name: 'MSCI World UCITS ETF', symbol: 'IWDA', kind: Kind.fund, amount: 38.2, value: 3611.90, invested: 3250.00),
      Holding(name: 'Bitcoin', symbol: 'BTC', kind: Kind.crypto, amount: 0.0412, value: 2874.10, invested: 1980.00),
      Holding(name: 'Ethereum', symbol: 'ETH', kind: Kind.crypto, amount: 0.78, value: 1655.40, invested: 1720.00),
      Holding(name: 'Solana', symbol: 'SOL', kind: Kind.crypto, amount: 4.6, value: 612.85, invested: 540.00),
      Holding(name: 'Gold', symbol: 'XAU', kind: Kind.metal, amount: 2.1, value: 498.60, invested: 420.00),
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
