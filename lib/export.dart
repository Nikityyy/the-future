import 'projection.dart';
import 'state.dart';
import 'version.dart';

const _kindName = {Kind.fund: 'Funds and stocks', Kind.crypto: 'Crypto', Kind.metal: 'Metals'};

String _n(double v, [int digits = 2]) => v.toStringAsFixed(digits);
String _opt(double? v, [int digits = 2]) => v == null ? '' : _n(v, digits);
String _units(double v) => v.toStringAsFixed(v.abs() >= 100 ? 2 : 8).replaceFirst(RegExp(r'\.?0+$'), '');
String _pct(double part, double whole) => whole == 0 ? '' : '${_n(part / whole * 100, 1)}%';

/// The whole portfolio as one Markdown file: holdings, every transaction, the
/// money added each month and the plan, with enough explanation that the file
/// alone is enough for someone (or an AI) to analyse it.
String exportMarkdown(AppState state, DateTime now) {
  final s = state.snapshot!;
  final b = StringBuffer();
  void line([String t = '']) => b.writeln(t);
  void table(List<String> head, Iterable<List<String>> rows) {
    line('| ${head.join(' | ')} |');
    line('|${head.map((h) => h.contains(RegExp('€|%|Units')) ? ' ---: ' : ' --- ').join('|')}|');
    for (final r in rows) {
      line('| ${r.map((c) => c.replaceAll('|', '/')).join(' | ')} |');
    }
    line();
  }

  final demo = state.mode == Mode.demo;
  line('# Portfolio export');
  line();
  line('- Exported: ${now.toUtc().toIso8601String()} by The Future ${AppVersion.label}');
  line('- Portfolio data as of: ${s.generatedAt.toUtc().toIso8601String()} (the last Bitpanda sync)');
  line('- Source: ${demo ? 'MADE-UP DEMO NUMBERS, not a real portfolio' : 'Bitpanda account, read through the Bitpanda public API with a read-only key'}');
  line('- Currency: EUR. Numbers use a dot for decimals and no thousands separators.');
  line();
  line('## How to read this file');
  line();
  line('- **Value** is what a holding was worth in EUR at the sync time above.');
  line('- **Invested** is Bitpanda\'s own figure for what was paid for the units still held (sold units no longer count).');
  line('- **Kinds**: "Funds and stocks" covers ETFs, stocks and ETCs; "Crypto" covers coins and tokens; "Metals" covers gold, silver and other metals. Cash balances are left out.');
  line('- **Transactions** list every booking in a non-cash asset, oldest first. `buy`/`sell` are trades; `in`/`out` are transfers, rewards, staking, airdrops and similar movements without a trade price. For trades, *Price* is the market rate per unit, *Value* is the EUR actually paid or received with fees included, and *Fee* is the difference between the two.');
  line('- **Money added per month** is net: buys count plus, sells count minus.');
  line();

  final value = s.value, invested = s.invested;
  line('## Summary');
  line();
  table(
    ['Part', 'Value €', 'Invested €', 'Gain €', 'Gain %', 'Share %'],
    [
      for (final k in Kind.values)
        if (s.kinds.contains(k))
          () {
            final v = s.valueOf(k), i = s.holdings.where((h) => h.kind == k).fold(0.0, (a, h) => a + h.invested);
            return [_kindName[k]!, _n(v), _n(i), _n(v - i), _pct(v - i, i), _pct(v, value)];
          }(),
      ['**Total**', '**${_n(value)}**', '**${_n(invested)}**', '**${_n(value - invested)}**', '**${_pct(value - invested, invested)}**', '100.0%'],
    ],
  );

  line('## Holdings');
  line();
  table(
    ['Asset', 'Symbol', 'Kind', 'Units', 'Value €', 'Invested €', 'Gain €', 'Gain %', 'Share %', 'Avg. cost per unit €'],
    [
      for (final h in s.holdings)
        [h.name, h.symbol, _kindName[h.kind]!, _units(h.amount), _n(h.value), _n(h.invested), _n(h.gain), _pct(h.gain, h.invested), _pct(h.value, value), h.amount > 0 ? _n(h.invested / h.amount, 4) : ''],
    ],
  );

  line('## Every transaction (${s.trades.length})');
  line();
  if (s.trades.isEmpty) {
    line('This snapshot has no transaction list. It comes from a sync made before exports existed: run the sync workflow on GitHub once and export again.');
    line();
  } else {
    final trades = s.trades.where((t) => t.side == 'buy' || t.side == 'sell');
    final bought = trades.where((t) => t.side == 'buy').fold(0.0, (a, t) => a + (t.value ?? 0));
    final sold = trades.where((t) => t.side == 'sell').fold(0.0, (a, t) => a + (t.value ?? 0));
    final fees = trades.fold(0.0, (a, t) => a + (t.fee ?? 0));
    line('First: ${s.trades.first.date.split('T').first}. Last: ${s.trades.last.date.split('T').first}. '
        'Bought for ${_n(bought)} €, sold for ${_n(sold)} €, ${_n(fees)} € in fees on trades.');
    line();
    table(
      ['Date', 'Asset', 'Symbol', 'Kind', 'Side', 'Type', 'Units', 'Price €', 'Value €', 'Fee €'],
      [
        for (final t in s.trades)
          [t.date.replaceFirst('T', ' ').split('.').first.replaceAll('Z', ''), t.name, t.symbol, _kindName[t.kind]!, t.side, t.type, _units(t.amount), _opt(t.price, 4), _opt(t.value), _opt(t.fee)],
      ],
    );
  }

  line('## Money added per month');
  line();
  table(
    ['Month', 'Funds and stocks €', 'Crypto €', 'Metals €', 'Total €'],
    [
      for (final m in s.monthly)
        [m.month, _n(m.byKind[Kind.fund]!), _n(m.byKind[Kind.crypto]!), _n(m.byKind[Kind.metal]!), _n(m.byKind.values.fold(0.0, (a, v) => a + v))],
    ],
  );
  line('Average over the last six full months: ${_n(s.usualMonthlyTotal)} € a month '
      '(${[for (final k in Kind.values) '${_kindName[k]} ${_n(s.usualMonthly[k]!)}'].join(', ')}).');
  line();

  line('## The plan set in the app');
  line();
  line('These are the owner\'s assumptions for the projection, not facts.');
  line();
  final monthly = state.monthlyBy['all'] ?? s.usualMonthlyTotal.roundToDouble();
  line('- Monthly amount added: ${_n(monthly)} €${state.monthlyBy['all'] == null ? ' (the six-month average)' : ' (set by hand)'}, split like recent purchases');
  line('- Monthly amount rises by ${_n(state.raisePercent, 1)}% a year');
  line('- Horizon: ${state.years} years. Inflation: ${_n(state.inflation, 1)}% a year. Savings account rate for comparison: ${_n(state.savingsRate, 2)}% a year');
  if (state.oneOffs.isNotEmpty) {
    line('- One-off deposits: ${state.oneOffs.map((o) => '${o.year}-${o.month.toString().padLeft(2, '0')}: ${_n(o.amount)} €').join('; ')}');
  }
  line();
  table(
    ['Kind', 'Cautious % a year', 'Expected % a year', 'Hopeful % a year'],
    [for (final k in Kind.values) [_kindName[k]!, for (final r in state.returns[k]!) _n(r, 1)]],
  );

  Projection run(Map<Kind, double> rate, {bool real = false}) => project(
        start: {for (final k in Kind.values) k: s.valueOf(k)},
        mix: s.mix,
        monthly: monthly,
        months: state.years * 12,
        yearlyReturn: rate,
        raisePercent: state.raisePercent,
        oneOffs: state.oneOffsNow,
        realTerms: real,
        inflation: state.inflation,
      );
  line('Projected value of the whole portfolio in ${state.years} years (${now.year + state.years}):');
  line();
  table(
    ['Scenario', 'Value €', 'In today\'s money €', 'Today plus all added €', 'Growth €'],
    [
      for (final (i, name) in [(0, 'Cautious'), (1, 'Expected'), (2, 'Hopeful')])
        () {
          final rate = {for (final k in Kind.values) k: state.returns[k]![i]};
          final p = run(rate);
          return [name, _n(p.end, 0), _n(run(rate, real: true).end, 0), _n(p.contributed.last, 0), _n(p.growth, 0)];
        }(),
      () {
        final p = run({for (final k in Kind.values) k: state.savingsRate});
        return ['Savings account instead', _n(p.end, 0), _n(run({for (final k in Kind.values) k: state.savingsRate}, real: true).end, 0), _n(p.contributed.last, 0), _n(p.growth, 0)];
      }(),
    ],
  );
  line('The projection adds money at the start of each month and compounds monthly at the yearly rates above. It is a simple model, not a forecast.');
  return b.toString();
}
