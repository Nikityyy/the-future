import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter/widgets.dart';

import '../format.dart';
import '../platform/haptics.dart';
import '../projection.dart';
import '../snapshot.dart';
import '../state.dart';
import '../theme.dart';
import '../ui/basics.dart';
import '../ui/chrome.dart';
import '../ui/filter.dart';
import '../ui/history.dart';
import '../ui/lists.dart';
import 'asset.dart';
import 'connect.dart';

class PortfolioPage extends StatelessWidget {
  const PortfolioPage(this.state, {super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) => PageBuilder(
        listenable: state,
        builder: (context) {
          final s = state.snapshot;
          if (s == null) return const SizedBox();
          final shown = [for (final h in s.holdings) if (state.active.contains(h.kind)) h];
          final value = shown.fold(0.0, (a, h) => a + h.value);
          final invested = shown.fold(0.0, (a, h) => a + h.invested);
          final gain = value - invested;
          final gainPercent = invested > 0 ? gain / invested * 100 : 0.0;
          final gainColor = gain >= 0 ? C.greenInk : C.loss;
          return CustomScrollView(
            slivers: [
              LargeTitle(
                'Portfolio',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (state.mode == Mode.demo) const _Tag('Demo') else if (state.refreshing && !state.pulling) const Spinner(),
                  const SizedBox(width: 10),
                  EyeButton(state),
                ]),
              ),
              CupertinoSliverRefreshControl(
                // A short pull is enough, as on iPhone: the list rubber-bands, so a pull
                // that feels long to the finger is only about this far.
                refreshTriggerPullDistance: 70,
                refreshIndicatorExtent: 50,
                onRefresh: () async {
                  Haptics.confirm();
                  // The pull has its own spinner; the one by the title is for refreshes you did not ask for.
                  state.pulling = true;
                  // Never faster than a blink, so you see that it looked.
                  final blink = Future<void>.delayed(const Duration(milliseconds: 800));
                  if (state.mode == Mode.live) await state.refresh();
                  await blink;
                  state.pulling = false;
                },
                builder: (context, mode, pulled, trigger, indicator) => Center(child: Opacity(opacity: (pulled / trigger).clamp(0.0, 1.0), child: const Spinner())),
              ),
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 6), child: KindChips(state))),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total value', style: sans(14, color: C.ink2)),
                      const SizedBox(height: 6),
                      BlurIn(blur: 0, duration: const Duration(milliseconds: 500), child: CountUp(value, style: serif(64, tracking: -2))),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: '${signedEur(gain)}  (${percent(gainPercent)})', style: figures(sans(15, weight: FontWeight.w500, color: gainColor))),
                          TextSpan(text: '  on ${eur(invested)} invested', style: figures(sans(15, color: C.ink2))),
                        ]),
                      ),
                      if (state.mode == Mode.live) ...[
                        const SizedBox(height: 6),
                        Text(
                          state.error ?? (state.pricedAt == null ? 'Updated ${ago(s.generatedAt)}. Pull down to refresh.' : 'Prices ${ago(state.pricedAt!)} · holdings ${ago(s.generatedAt)}'),
                          style: sans(12.5, color: state.error == null ? C.ink3 : C.loss),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Bitpanda's history is the whole portfolio; for one kind the line is built from its prices.
              SliverToBoxAdapter(child: ValueHistory(s, only: state.filter.isEmpty ? null : state.active)),
              SliverToBoxAdapter(child: _Allocation(s, state.active)),
              for (final k in Kind.values)
                if (state.active.contains(k) && s.holdings.any((h) => h.kind == k))
                  SliverToBoxAdapter(
                    child: Group(
                      header: kindNames[k]!.toUpperCase(),
                      children: [for (final h in s.holdings.where((h) => h.kind == k)) _HoldingRow(h, s)],
                    ),
                  ),
              if (state.mode == Mode.demo)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Column(
                      children: [
                        Text('These are made-up numbers.', style: sans(13, color: C.ink2)),
                        const SizedBox(height: 10),
                        AppButton('Connect your Bitpanda', onTap: () => showPage<void>(context, (_) => ConnectSheet(state))),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: SizedBox(height: Dock.clearance(context) + 16)),
            ],
          );
        },
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: C.greenSoft, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: sans(12.5, weight: FontWeight.w600, color: C.greenInk)),
      );
}

class _HoldingRow extends StatelessWidget {
  const _HoldingRow(this.h, this.s);
  final Holding h;
  final Snapshot s;

  @override
  Widget build(BuildContext context) => Row2(
        title: h.name,
        subtitle: '${amountOf(h.amount)} ${h.symbol}',
        trailing: Text(eur(h.value), style: figures(sans(16, weight: FontWeight.w500))),
        subtrailing: Text(percent(h.gainPercent), style: figures(sans(13, color: h.gain >= 0 ? C.greenInk : C.loss))),
        chevron: true,
        onTap: () => showPage<void>(context, (_) => AssetPage(h, s)),
      );
}

class _Allocation extends StatelessWidget {
  const _Allocation(this.s, this.active);
  final Snapshot s;
  final Set<Kind> active;

  @override
  Widget build(BuildContext context) {
    final parts = [for (final k in Kind.values) if (active.contains(k) && s.valueOf(k) > 0) (k, s.valueOf(k))];
    final total = parts.fold(0.0, (a, p) => a + p.$2);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: double.infinity,
              height: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < parts.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(flex: (parts[i].$2 * 100).round().clamp(1, 1 << 30), child: ColoredBox(color: kindColors[parts[i].$1]!)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              for (final p in parts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: kindColors[p.$1], shape: BoxShape.circle)),
                    const SizedBox(width: 7),
                    Text('${kindNames[p.$1]}  ${(p.$2 / total * 100).round()}%', style: figures(sans(13, color: C.ink2))),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
