import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_future/projection.dart';
import 'package:the_future/screens/asset.dart';
import 'package:the_future/snapshot.dart';

void main() {
  testWidgets('years of transactions build only the cards on screen', (tester) async {
    final start = DateTime.utc(2023, 1, 1, 9);
    final trades = [
      for (var i = 0; i < 1095; i++)
        Trade(date: start.add(Duration(days: i)).toIso8601String(), symbol: 'BTC', name: 'Bitcoin', kind: Kind.crypto, side: 'buy', type: 'TRADE', amount: 0.0001, price: 50000, value: 5),
    ];
    const h = Holding(name: 'Bitcoin', symbol: 'BTC', kind: Kind.crypto, amount: 0.1095, value: 6000, invested: 5475);
    final s = Snapshot(generatedAt: DateTime.utc(2026, 1, 1), holdings: const [h], monthly: const [], trades: trades);
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: MediaQuery(data: const MediaQueryData(size: Size(390, 844)), child: AssetPage(h, s))));
    await tester.pump(const Duration(seconds: 2));
    final built = find.textContaining('Bought ', skipOffstage: false).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(100), reason: '$built of ${trades.length} rows built');
    expect(find.text('2025', skipOffstage: false), findsOneWidget, reason: 'newest year first');
  });
}
