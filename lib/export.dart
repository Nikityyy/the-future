import 'projection.dart';
import 'snapshot.dart';
import 'state.dart';
import 'version.dart';

const _kindName = {Kind.fund: 'Funds and stocks', Kind.crypto: 'Crypto', Kind.metal: 'Metals'};

/// What a booking's type means in plain words, for the transactions table.
const _meaning = {
  'buy': 'Bought with euros',
  'sell': 'Sold for euros',
  'reward': 'Free reward (staking or similar)',
  'onetime_reward': 'One-off free reward',
  'stake': 'Into staking, no money',
  'unstake': 'Out of staking, no money',
  'transfer': 'Internal move, no money',
  'stock_exchange_reserve': 'Reserved at the exchange, no money',
  'merger_crypto': 'Swapped into another token, no money',
};

/// The value-history periods, as the app names them.
const _periods = [('day', '1 day'), ('week', '1 week'), ('month', '1 month'), ('six_month', '6 months'), ('year', '1 year'), ('all', 'Since the history starts')];

/// Euros to the cent.
String _n(double v, [int digits = 2]) => (v == 0 ? 0.0 : v).toStringAsFixed(digits);
String _opt(double? v) => v == null ? '' : _n(v);

/// Every digit that matters, up to eight decimals (twelve below a cent),
/// trailing zeros dropped: units and prices as Bitpanda books them.
String _exact(double v, {int min = 0}) {
  if (v == 0) return min == 0 ? '0' : _n(0, min);
  final s = v.toStringAsFixed(v.abs() < 0.01 ? 12 : 8).replaceFirst(RegExp(r'0+$'), '');
  final decimals = s.contains('.') ? s.length - s.indexOf('.') - 1 : 0;
  if (decimals >= min) return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
  return v.toStringAsFixed(min);
}

String _price(double? v) => v == null ? '' : _exact(v, min: 2);
String _pct(double part, double whole) => whole == 0 ? '' : '${_n(part / whole * 100)}%';
String _two(int v) => v.toString().padLeft(2, '0');

/// A moment in this device's local time, to the second, with its offset
/// from UTC, so it is exact wherever the file is read: 2026-03-01 00:30:00 +01:00.
String _local(DateTime t) {
  final d = t.toLocal(), o = d.timeZoneOffset;
  final sign = o.isNegative ? '-' : '+';
  return '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)} $sign${_two(o.inHours.abs())}:${_two(o.inMinutes.abs() % 60)}';
}

String _day(DateTime t) => _local(t).substring(0, 10);
String _when(String iso) => switch (DateTime.tryParse(iso)) { final d? => _local(d), null => iso };

/// The whole portfolio as one Markdown file: holdings, what each asset did
/// over all time, how the portfolio did, every transaction, the money added
/// each month and the plan, with enough explanation that the file alone is
/// enough for someone (or an AI) to analyse it.
String exportMarkdown(AppState state, DateTime now) {
  final s = state.snapshot!;
  final b = StringBuffer();
  void line([String t = '']) => b.writeln(t);
  void table(List<String> head, Iterable<List<String>> rows) {
    line('| ${head.join(' | ')} |');
    line('|${head.map((h) => h.contains(RegExp('€|%|Units|Count')) ? ' ---: ' : ' --- ').join('|')}|');
    for (final r in rows) {
      line('| ${r.map((c) => c.replaceAll('|', '/')).join(' | ')} |');
    }
    line();
  }

  final demo = state.mode == Mode.demo;
  final trades = [for (final t in s.trades) if (DateTime.tryParse(t.date) != null) t];
  final money = [for (final t in trades) if ((t.side == 'buy' || t.side == 'sell') && t.value != null) t];
  final bought = money.where((t) => t.side == 'buy').fold(0.0, (a, t) => a + t.value!);
  final sold = money.where((t) => t.side == 'sell').fold(0.0, (a, t) => a + t.value!);
  final fees = money.fold(0.0, (a, t) => a + (t.fee ?? 0));
  final value = s.value, invested = s.invested;

  line('# Portfolio export');
  line();
  line('- Exported: ${_local(now)} by The Future ${AppVersion.label}');
  line('- Holdings and transactions as of: ${_local(s.generatedAt)} (the last Bitpanda sync)');
  final priced = s.pricedAt;
  line(priced == null
      ? '- Prices as of: the same sync'
      : '- Prices as of: ${_local(priced)} (read live from the public Bitpanda price charts; every value below uses them)');
  line('- Source: ${demo ? 'MADE-UP DEMO NUMBERS, not a real portfolio' : 'Bitpanda account, read through the Bitpanda public API with a read-only key'}');
  line('- Currency: EUR. Numbers use a dot for decimals and no thousands separators. Euros are to the cent; units and prices carry every digit Bitpanda gives, up to 8 decimals (12 below a cent).');
  line('- Times: local time of the device that exported, with the offset from UTC on each one (Vienna is +01:00 in winter, +02:00 in summer). Months are calendar months in that local time.');
  line();

  line('## How to read this file');
  line();
  line('- **Value** is what a holding is worth at the prices time above: units times price.');
  line('- **Invested** is Bitpanda\'s own figure for what was paid for the units still held, fees included. Sold units no longer count, so a sale moves money out of Invested.');
  line('- **Unrealised gain** is Value minus Invested: what the units still held made so far.');
  line('- **All-time result** is Value plus everything sold minus everything bought. It counts gains on units already sold and the value of rewards; units moved in from outside Bitpanda would count as gain too, since no money was paid for them here.');
  line('- **Kinds**: "Funds and stocks" covers ETFs, stocks and ETCs; "Crypto" covers coins and tokens; "Metals" covers gold, silver and other metals. Cash balances are left out.');
  line('- **Return %** in Performance is the Modified Dietz return, the same the app shows: the gain without money added, over what was invested on average during the period (each deposit weighted by how long it was in).');
  line('- **Transactions** list every booking in a non-cash asset, oldest first. `buy`/`sell` are trades; `in`/`out` are transfers, rewards, staking, airdrops and similar movements without a trade price. For trades, *Price* is the market rate per unit, *Value* is the EUR actually paid or received with fees included, and *Fee* is the difference between the two. Rows without a price and value moved no money. Staking, unstaking, transfers and mergers show up as an `out` row and an `in` row of the same units: that is one internal move, not a sale and a purchase.');
  line('- **Money added** is net: the *Value* of buys counts plus, of sells minus.');
  line();

  line('## Summary');
  line();
  table(
    ['Part', 'Value €', 'Invested €', 'Unrealised gain €', 'Unrealised gain %', 'Share of value %'],
    [
      for (final k in Kind.values)
        if (s.kinds.contains(k))
          () {
            final v = s.valueOf(k), i = s.holdings.where((h) => h.kind == k).fold(0.0, (a, h) => a + h.invested);
            return [_kindName[k]!, _n(v), _n(i), _n(v - i), _pct(v - i, i), _pct(v, value)];
          }(),
      ['**Total**', '**${_n(value)}**', '**${_n(invested)}**', '**${_n(value - invested)}**', '**${_pct(value - invested, invested)}**', '**100.00%**'],
    ],
  );
  if (trades.isNotEmpty) {
    line('All time: bought for ${_n(bought)} €, sold for ${_n(sold)} €, so ${_n(bought - sold)} € net put in; ${_n(fees)} € of that went on trading fees. '
        'All-time result: ${_n(value + sold - bought)} € (${_pct(value + sold - bought, bought - sold)} of the net put in).');
    // Without sales, everything bought is still held, so it has to match
    // Bitpanda's Invested; if it does not, transactions are missing.
    if (sold == 0 && (bought - invested).abs() > invested * 0.02 + 1) {
      line();
      line('**Check:** nothing was sold, yet bought (${_n(bought)} €) and Invested (${_n(invested)} €) differ by ${_n(bought - invested)} €. Some transactions are missing from this file (or units came in from outside Bitpanda), so the all-time numbers are not reliable; Invested and Value are.');
    }
    line();
  }

  line('## Holdings');
  line();
  table(
    ['Asset', 'Symbol', 'Kind', 'Units', 'Price now €', 'Value €', 'Invested €', 'Avg. cost per unit €', 'Unrealised gain €', 'Unrealised gain %', 'Share of value %'],
    [
      for (final h in s.holdings)
        [
          h.name, h.symbol, _kindName[h.kind]!, _exact(h.amount), h.amount > 0 ? _price(h.value / h.amount) : '', _n(h.value), _n(h.invested),
          h.amount > 0 && h.invested > 0 ? _price(h.invested / h.amount) : '', _n(h.gain), _pct(h.gain, h.invested), _pct(h.value, value),
        ],
    ],
  );
  if (s.holdings.any((h) => h.invested <= 0)) {
    line('A holding with nothing invested was not bought here: a reward, an airdrop or a transfer in.');
    line();
  }

  if (trades.isNotEmpty) {
    line('## Every asset over all time');
    line();
    line('From the transactions, sold-off assets included. *Units now* is what Bitpanda holds today.');
    line();
    final assets = <String, List<Trade>>{};
    for (final t in trades) {
      assets.putIfAbsent('${t.symbol}|${t.name}', () => []).add(t);
    }
    table(
      ['Asset', 'Symbol', 'Kind', 'First booking', 'Last booking', 'Buys Count', 'Sells Count', 'Bought €', 'Sold €', 'Fees €', 'Units now', 'Value now €', 'All-time result €'],
      [
        for (final list in assets.values)
          () {
            final t = list.first;
            final held = s.holdings.where((h) => h.symbol == t.symbol && h.name == t.name).toList();
            final units = held.fold(0.0, (a, h) => a + h.amount), worth = held.fold(0.0, (a, h) => a + h.value);
            double sum(String side) => list.where((x) => x.side == side).fold(0.0, (a, x) => a + (x.value ?? 0));
            return [
              t.name, t.symbol, _kindName[t.kind]!, _day(DateTime.parse(list.first.date)), _day(DateTime.parse(list.last.date)),
              '${list.where((x) => x.side == 'buy').length}', '${list.where((x) => x.side == 'sell').length}',
              _n(sum('buy')), _n(sum('sell')), _n(list.fold(0.0, (a, x) => a + (x.fee ?? 0))), _exact(units), _n(worth), _n(worth + sum('sell') - sum('buy')),
            ];
          }(),
      ],
    );
  }

  final periods = [for (final (k, name) in _periods) if ((s.historyNow(k)?.length ?? 0) > 1) (name, s.historyNow(k)!)];
  if (periods.isNotEmpty) {
    line('## Performance');
    line();
    line('The whole portfolio, from Bitpanda\'s value history${priced == null ? '' : ', carried on to the live prices'}. *Gain* leaves out money added during the period.');
    line();
    table(
      ['Period', 'From', 'To', 'Value at start €', 'Value at end €', 'Money added €', 'Gain €', 'Return %'],
      [
        for (final (name, pts) in periods)
          () {
            final c = s.change(pts);
            return [name, _local(pts.first.$1), _local(pts.last.$1), _n(pts.first.$2), _n(pts.last.$2), _n(c.added), _n(c.gain), c.percent == null ? '' : '${_n(c.percent!)}%'];
          }(),
      ],
    );

    // The value at the last point of each month, from the longest history.
    final all = periods.last.$2;
    final ends = <String, (DateTime, double)>{};
    for (final p in all) {
      ends[Snapshot.monthKey(p.$1.toLocal())] = p;
    }
    final months = ends.entries.toList();
    line('### Value at each month end');
    line();
    line('The last value Bitpanda recorded in each month (the current month: the latest). *Gain* and *Return* are from the month before\'s end, money added left out.');
    line();
    table(
      ['Month', 'At', 'Value €', 'Money added €', 'Gain €', 'Return %'],
      [
        for (var i = 0; i < months.length; i++)
          () {
            final (t, v) = months[i].value;
            if (i == 0) return [months[i].key, _local(t), _n(v), '', '', ''];
            final c = s.change([months[i - 1].value, (t, v)]);
            return [months[i].key, _local(t), _n(v), _n(c.added), _n(c.gain), c.percent == null ? '' : '${_n(c.percent!)}%'];
          }(),
      ],
    );
  }

  line('## Every transaction (${trades.length})');
  line();
  if (trades.isEmpty) {
    line('This snapshot has no transaction list. It comes from a sync made before exports existed: run the sync workflow on GitHub once and export again.');
    line();
  } else {
    line('First: ${_when(trades.first.date)}. Last: ${_when(trades.last.date)}. ${money.where((t) => t.side == 'buy').length} buys, ${money.where((t) => t.side == 'sell').length} sells, ${trades.length - money.length} bookings without money.');
    line();
    table(
      ['Date', 'Asset', 'Symbol', 'Kind', 'Side', 'Type', 'Units', 'Price €', 'Value €', 'Fee €', 'Meaning'],
      [
        for (final t in trades)
          [_when(t.date), t.name, t.symbol, _kindName[t.kind]!, t.side, t.type, _exact(t.amount), _price(t.price), _opt(t.value), _opt(t.fee), _meaning[t.type.toLowerCase()] ?? _meaning[t.side] ?? ''],
      ],
    );
  }

  line('## Money added per month');
  line();
  var running = 0.0;
  table(
    ['Month', 'Funds and stocks €', 'Crypto €', 'Metals €', 'Total €', 'Total so far €'],
    [
      for (final m in s.monthly)
        () {
          final total = m.byKind.values.fold(0.0, (a, v) => a + v);
          running += total;
          return [m.month, _n(m.byKind[Kind.fund]!), _n(m.byKind[Kind.crypto]!), _n(m.byKind[Kind.metal]!), _n(total), _n(running)];
        }(),
    ],
  );
  line('Months without a buy or sell are left out (they are zero). Average over the six full months before this one: ${_n(s.usualMonthlyTotal)} € a month '
      '(${[for (final k in Kind.values) '${_kindName[k]} ${_n(s.usualMonthly[k]!)}'].join(', ')}). The app plans with this unless a monthly amount is set by hand.');
  line();

  line('## The plan set in the app');
  line();
  line('These are the owner\'s assumptions for the projection, not facts.');
  line();
  final monthly = state.monthlyBy['all'] ?? s.usualMonthlyTotal.roundToDouble();
  const scenarios = ['Cautious', 'Expected', 'Hopeful'];
  line('- Monthly amount added: ${_n(monthly)} €${state.monthlyBy['all'] == null ? ' (the six-month average)' : ' (set by hand)'}, split across kinds like recent purchases '
      '(${[for (final e in s.mix.entries) if (e.value > 0) '${_kindName[e.key]} ${_n(e.value * 100)}%'].join(', ')})');
  for (final e in state.monthlyBy.entries) {
    if (e.key != 'all') line('- Monthly amount set by hand for the ${e.key.replaceAll('+', ' and ')} view: ${_n(e.value)} €');
  }
  line('- Monthly amount rises by ${_n(state.raisePercent, 1)}% a year');
  line('- Horizon: ${state.years} years. Scenario picked in the app: ${scenarios[state.scenario]}');
  line('- Inflation: ${_n(state.inflation, 2)}% a year. Savings account rate for comparison: ${_n(state.savingsRate, 2)}% a year');
  final goal = state.goal;
  if (goal != null) {
    // The whole portfolio, whichever tab the app is on.
    final need = state.monthlyForGoal(goal, const {});
    final reached = state.goalReachedIn(goal, const {});
    final scenario = scenarios[state.scenario].toLowerCase();
    line('- Goal: ${_n(goal.amount)} € by the end of ${goal.year}, for the whole portfolio. '
        '${need == null ? 'Out of reach by then in the $scenario case' : need == 0 ? 'Reached by then without adding money in the $scenario case' : 'Takes ${_n(need)} € a month in the $scenario case'}'
        '${reached == null ? '' : '; at ${_n(monthly)} € a month it is reached in $reached'}');
  }
  for (final o in state.oneOffs) {
    line('- One-off deposit: ${_n(o.amount)} € in ${o.year}-${_two(o.month)}');
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
        addAt: state.addAt,
      );
  Map<Kind, double> rates(int i) => {for (final k in Kind.values) k: state.returns[k]![i]};
  final savingsRates = {for (final k in Kind.values) k: state.savingsRate};
  final runs = [for (var i = 0; i < 3; i++) run(rates(i))];
  final savings = run(savingsRates);
  line('Projected value of the whole portfolio in ${state.years} years (${now.toLocal().year + state.years}):');
  line();
  table(
    ['Scenario', 'Value €', 'In today\'s money €', 'Today plus all added €', 'Growth €'],
    [
      for (var i = 0; i < 3; i++) [scenarios[i], _n(runs[i].end), _n(run(rates(i), real: true).end), _n(runs[i].contributed.last), _n(runs[i].growth)],
      ['Savings account instead', _n(savings.end), _n(run(savingsRates, real: true).end), _n(savings.contributed.last), _n(savings.growth)],
    ],
  );
  line('Year by year, counted from today:');
  line();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  table(
    ['In', 'Today plus all added €', 'Cautious €', 'Expected €', 'Hopeful €', 'Savings account €'],
    [
      for (var y = 1; y <= state.years; y++)
        ['${months[now.toLocal().month - 1]} ${now.toLocal().year + y}', _n(runs[1].contributed[y * 12]), for (final r in runs) _n(r.values[y * 12]), _n(savings.values[y * 12])],
    ],
  );
  final day = s.buyDay;
  line('The projection adds the monthly amount ${day == null ? 'at the start of each month' : 'on day $day of each month, the day purchases usually happened,'} and compounds monthly at the yearly rates above. It is a simple model, not a forecast: no taxes, no fees, no ups and downs along the way.');
  return b.toString();
}
