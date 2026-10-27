import 'projection.dart';
import 'snapshot.dart';

/// Made-up numbers so the app can be tried without Bitpanda.
Snapshot demoSnapshot([DateTime? now]) {
  now ??= DateTime.now().toUtc();
  const fund = [310.0, 300, 300, 350, 300, 300, 320, 300, 300, 400, 300, 300];
  const crypto = [60.0, 80, 0, 100, 60, 60, 120, 60, 80, 60, 40, 60];
  return Snapshot(
    generatedAt: now,
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
  );
}
