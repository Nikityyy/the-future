import 'package:flutter/widgets.dart';

import '../format.dart';
import '../platform/web_glue.dart';
import '../snapshot.dart';
import '../theme.dart';
import '../ui/basics.dart';
import '../ui/chrome.dart';
import '../ui/filter.dart' show kindNames;
import '../ui/lists.dart';

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// One holding: what you own, what you paid on average, what it is worth now,
/// and every transaction in it, newest first.
class AssetPage extends StatelessWidget {
  const AssetPage(this.h, this.s, {super.key});

  final Holding h;
  final Snapshot s;

  @override
  Widget build(BuildContext context) {
    final trades = [
      for (final t in s.trades.reversed)
        if (t.symbol == h.symbol && t.name == h.name) t,
    ];
    final avg = h.amount > 0 ? h.invested / h.amount : 0.0;
    final now = h.amount > 0 ? h.value / h.amount : 0.0;
    final share = s.value > 0 ? h.value / s.value * 100 : 0.0;
    final up = h.gain >= 0;
    // Stable across rebuilds of the route, unique per holding.
    final name = GlobalObjectKey(h);
    String unit(double v) => eur(v, cents: v < 1000);

    return BackPage(
      title: h.name,
      titleKey: name,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: BackPage.space())),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${h.symbol}  ·  ${kindNames[h.kind]}', style: sans(14, color: C.ink2)),
                  const SizedBox(height: 4),
                  BlurText(h.name, key: name, style: serif(34, height: 1.05)),
                  const SizedBox(height: 18),
                  CountUp(h.value, style: serif(56, tracking: -1.8)),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${signedEur(h.gain)}  (${percent(h.gainPercent)})',
                          style: figures(sans(15, weight: FontWeight.w500, color: up ? C.greenInk : C.loss)),
                        ),
                        TextSpan(
                          text: '  on ${eur(h.invested)} invested',
                          style: figures(sans(15, color: C.ink2)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Group(
              header: 'YOUR POSITION',
              footer: avg <= 0 ? null : 'The price now is ${percent((now / avg - 1) * 100, sign: false)} ${now >= avg ? 'above' : 'below'} what you paid on average.',
              children: [
                Row2(
                  title: 'You own',
                  trailing: Text('${amountOf(h.amount)} ${h.symbol}', style: figures(sans(16))),
                ),
                Row2(
                  title: 'Average buy price',
                  subtitle: 'Per unit, fees included',
                  trailing: Text(unit(avg), style: figures(sans(16))),
                ),
                Row2(
                  title: 'Price now',
                  subtitle: 'Per unit, at the last sync',
                  trailing: Text(unit(now), style: figures(sans(16))),
                ),
                Row2(
                  title: 'Share of your portfolio',
                  trailing: Text('${share.toStringAsFixed(1)}%', style: figures(sans(16))),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Group(
              header: trades.isEmpty ? 'TRANSACTIONS' : 'TRANSACTIONS (${trades.length})',
              footer: trades.isEmpty ? 'Transactions show up after the next sync from Bitpanda.' : null,
              children: [
                if (trades.isEmpty) const Row2(title: 'None yet'),
                for (final t in trades) _TradeRow(t),
              ],
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 40 + browserSafeArea().bottom)),
        ],
      ),
    );
  }
}

class _TradeRow extends StatelessWidget {
  const _TradeRow(this.t);
  final Trade t;

  @override
  Widget build(BuildContext context) {
    final d = DateTime.tryParse(t.date)?.toLocal();
    final when = d == null ? '' : '${d.day} ${_monthNames[d.month - 1]} ${d.year}';
    final verb = switch (t.side) {
      'buy' => 'Bought',
      'sell' => 'Sold',
      'in' => _nice(t.type, 'Received'),
      _ => _nice(t.type, 'Sent'),
    };
    return Row2(
      title: '$verb ${amountOf(t.amount)} ${t.symbol}',
      subtitle: t.price == null ? when : '$when  ·  at ${eur(t.price!, cents: t.price! < 1000)}',
      trailing: t.value == null ? null : Text('${t.side == 'sell' ? '+' : ''}${eur(t.value!)}', style: figures(sans(16, color: t.side == 'sell' ? C.greenInk : C.ink))),
      subtrailing: t.fee == null || t.fee == 0 ? null : Text('fee ${eur(t.fee!, cents: true)}', style: figures(sans(12.5, color: C.ink2))),
    );
  }

  /// Bitpanda's own word for transfers, rewards and the like, read aloud.
  static String _nice(String type, String fallback) {
    if (type.isEmpty) return fallback;
    final w = type.toLowerCase().replaceAll('_', ' ');
    return w[0].toUpperCase() + w.substring(1);
  }
}
