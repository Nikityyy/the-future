import 'projection.dart';

class Holding {
  const Holding({
    required this.name,
    required this.symbol,
    required this.kind,
    required this.amount,
    required this.value,
    required this.invested,
    this.pid,
  });

  factory Holding.fromJson(Map<String, dynamic> j) => Holding(
        name: j['name'] as String,
        symbol: j['symbol'] as String? ?? '',
        kind: switch (j['kind']) {
          'crypto' => Kind.crypto,
          'metal' => Kind.metal,
          _ => Kind.fund,
        },
        amount: (j['amount'] as num).toDouble(),
        value: (j['value'] as num).toDouble(),
        invested: (j['invested'] as num).toDouble(),
        pid: j['id'] as String?,
      );

  final String name;
  final String symbol;
  final Kind kind;
  final double amount;
  final double value;
  final double invested;

  /// Bitpanda's asset id, which its price charts use too; 'demo' for made-up prices.
  final String? pid;

  double get gain => value - invested;
  double get gainPercent => invested > 0 ? gain / invested * 100 : 0;

  /// The same holding worth [price] a unit.
  Holding at(double price) => Holding(name: name, symbol: symbol, kind: kind, amount: amount, value: amount * price, invested: invested, pid: pid);
}

/// One transaction as Bitpanda booked it. [price], [value] and [fee] are
/// only known for trades; [value] is what was paid or received, fees included.
class Trade {
  const Trade({required this.date, required this.symbol, required this.name, required this.kind, required this.side, required this.type, required this.amount, this.price, this.value, this.fee});

  factory Trade.fromJson(Map<String, dynamic> j) => Trade(
        date: j['date'] as String? ?? '',
        symbol: j['symbol'] as String? ?? '',
        name: j['name'] as String? ?? '',
        kind: Kind.values.firstWhere((k) => k.name == j['kind'], orElse: () => Kind.fund),
        side: j['side'] as String? ?? '',
        type: j['type'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        price: (j['price'] as num?)?.toDouble(),
        value: (j['value'] as num?)?.toDouble(),
        fee: (j['fee'] as num?)?.toDouble(),
      );

  final String date; // ISO 8601
  final String symbol;
  final String name;
  final Kind kind;
  final String side; // buy, sell, in, out
  final String type;
  final double amount;
  final double? price;
  final double? value;
  final double? fee;
}

/// What you put in during one calendar month (sells count as minus).
class MonthRow {
  const MonthRow(this.month, this.byKind);

  final String month; // 2026-09
  final Map<Kind, double> byKind;
}

class Snapshot {
  const Snapshot({required this.generatedAt, required this.holdings, required this.monthly, this.trades = const [], this.history = const {}, this.pricedAt});

  factory Snapshot.fromJson(Map<String, dynamic> j) {
    // Snapshots synced before the export existed have no trades.
    final trades = [for (final t in j['trades'] as List? ?? const []) Trade.fromJson(t as Map<String, dynamic>)];
    return Snapshot(
        generatedAt: DateTime.parse(j['generatedAt'] as String),
        holdings: [for (final h in j['holdings'] as List) Holding.fromJson(h as Map<String, dynamic>)],
        // The sync counts months in UTC and keeps three years; from the
        // trades they are every month, in this phone's own time.
        monthly: trades.isNotEmpty
            ? monthsOf(trades)
            : [
                for (final m in j['monthly'] as List)
                  MonthRow((m as Map<String, dynamic>)['month'] as String, {
                    Kind.fund: (m['fund'] as num).toDouble(),
                    Kind.crypto: (m['crypto'] as num).toDouble(),
                    Kind.metal: (m['metal'] as num).toDouble(),
                  }),
              ],
        trades: trades,
        history: {
          for (final e in (j['history'] as Map<String, dynamic>? ?? const {}).entries)
            e.key: [
              for (final p in e.value as List) (DateTime.fromMillisecondsSinceEpoch(((p as List)[0] as num).toInt() * 1000, isUtc: true), (p[1] as num).toDouble()),
            ],
        },
      );
  }

  /// Net money put in per calendar month in local time and per kind, from
  /// [trades]: buys count plus, sells minus. Oldest first; months without a
  /// buy or sell are left out.
  static List<MonthRow> monthsOf(List<Trade> trades) {
    final months = <String, Map<Kind, double>>{};
    for (final t in trades) {
      final d = DateTime.tryParse(t.date)?.toLocal();
      if (d == null || t.value == null || (t.side != 'buy' && t.side != 'sell')) continue;
      final row = months.putIfAbsent(monthKey(d), () => {for (final k in Kind.values) k: 0.0});
      row[t.kind] = row[t.kind]! + (t.side == 'sell' ? -t.value! : t.value!);
    }
    return [for (final k in months.keys.toList()..sort()) MonthRow(k, months[k]!)];
  }

  /// 2026-09 for any moment in September 2026.
  static String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  final DateTime generatedAt;

  /// When the holdings' prices were read live, after the sync; null while
  /// they are the sync's own.
  final DateTime? pricedAt;
  final List<Holding> holdings;
  final List<MonthRow> monthly;
  final List<Trade> trades;

  /// The whole portfolio's value over time, by timeframe: day, week, month,
  /// six_month, year and all. Empty for snapshots synced before it existed.
  final Map<String, List<(DateTime, double)>> history;

  /// Money put in minus money taken out between two moments, from the trades,
  /// for just [kinds] when given.
  double netAddedBetween(DateTime from, DateTime to, {Set<Kind>? kinds}) {
    var sum = 0.0;
    for (final t in trades) {
      final d = DateTime.tryParse(t.date);
      if (d == null || t.value == null || d.isBefore(from) || d.isAfter(to) || (kinds != null && !kinds.contains(t.kind))) continue;
      sum += t.side == 'sell' ? -t.value! : t.side == 'buy' ? t.value! : 0;
    }
    return sum;
  }

  /// Money added between two moments, each amount weighted by the share of
  /// the period it was invested (the Modified Dietz weights): bought on the
  /// first day counts in full, bought on the last day not at all.
  double weightedAddedBetween(DateTime from, DateTime to, {Set<Kind>? kinds}) {
    final span = to.difference(from).inSeconds;
    if (span <= 0) return 0;
    var sum = 0.0;
    for (final t in trades) {
      final d = DateTime.tryParse(t.date);
      if (d == null || t.value == null || d.isBefore(from) || d.isAfter(to) || (kinds != null && !kinds.contains(t.kind))) continue;
      final w = to.difference(d).inSeconds / span;
      sum += w * (t.side == 'sell' ? -t.value! : t.side == 'buy' ? t.value! : 0);
    }
    return sum;
  }

  /// How a value line did from its first point to its last, money added
  /// left out: the gain in euros, the money added, and the return in percent
  /// (Modified Dietz: the gain over what was invested on average during the
  /// period), null when nothing was invested. For just [kinds] when given.
  ({double gain, double added, double? percent}) change(List<(DateTime, double)> pts, {Set<Kind>? kinds}) {
    final (t0, v0) = pts.first;
    final (t1, v1) = pts.last;
    final added = netAddedBetween(t0, t1, kinds: kinds);
    final gain = v1 - v0 - added;
    final base = v0 + weightedAddedBetween(t0, t1, kinds: kinds);
    return (gain: gain, added: added, percent: base > 0 ? gain / base * 100 : null);
  }

  /// The day of the month your money usually goes in: the middle day of your
  /// buys in the half year before the snapshot, or null without any.
  int? get buyDay {
    final from = generatedAt.subtract(const Duration(days: 183));
    final days = [
      for (final t in trades)
        if (t.side == 'buy')
          if (DateTime.tryParse(t.date)?.toLocal() case final d? when d.isAfter(from)) d.day,
    ]..sort();
    return days.isEmpty ? null : days[days.length ~/ 2];
  }

  /// How many units of [h] you held at each moment of [grid] (oldest
  /// first): what you hold now, undone by the trades since. Anchored on
  /// today's amount, so a missing early trade does not shift the present.
  /// One pass back through the trades, however long the grid.
  List<double> unitsOver(Holding h, List<DateTime> grid) {
    final moves = <(DateTime, double)>[
      for (final x in trades)
        if (x.symbol == h.symbol && (h.symbol.isNotEmpty || x.name == h.name))
          if (DateTime.tryParse(x.date) case final d?) (d, switch (x.side) { 'buy' || 'in' => x.amount, 'sell' || 'out' => -x.amount, _ => 0.0 }),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final out = List<double>.filled(grid.length, 0);
    var since = 0.0, next = moves.length - 1;
    for (var i = grid.length - 1; i >= 0; i--) {
      for (; next >= 0 && moves[next].$1.isAfter(grid[i]); next--) {
        since += moves[next].$2;
      }
      final units = h.amount - since;
      out[i] = units < 0 ? 0 : units;
    }
    return out;
  }

  /// The same snapshot with the holdings at the prices read [at] ([prices]
  /// is one per holding, null where unknown).
  Snapshot repriced(List<double?> prices, DateTime at) => Snapshot(
        generatedAt: generatedAt,
        holdings: [for (final (i, h) in holdings.indexed) prices[i] == null ? h : h.at(prices[i]!)],
        monthly: monthly,
        trades: trades,
        history: history,
        pricedAt: prices.any((p) => p != null) ? at : pricedAt,
      );

  /// The value over [frame], up to the prices on screen: Bitpanda's history
  /// ends at the sync, so with live prices the line goes on to them, and its
  /// change matches the total above it.
  List<(DateTime, double)>? historyNow(String frame) {
    final pts = history[frame];
    final at = pricedAt;
    if (pts == null || pts.isEmpty || at == null || !at.isAfter(pts.last.$1)) return pts;
    return [...pts, (at, value)];
  }

  double get value => holdings.fold(0, (a, h) => a + h.value);
  double get invested => holdings.fold(0, (a, h) => a + h.invested);
  double get gain => value - invested;
  double get gainPercent => invested > 0 ? gain / invested * 100 : 0;

  double valueOf(Kind k) => holdings.where((h) => h.kind == k).fold(0, (a, h) => a + h.value);

  Set<Kind> get kinds => {for (final h in holdings) h.kind};

  /// Usual monthly amount for just these kinds.
  double usualFor(Set<Kind> kinds) => kinds.fold(0.0, (a, k) => a + usualMonthly[k]!);

  /// How new money splits across just these kinds.
  Map<Kind, double> mixFor(Set<Kind> kinds) {
    final m = mix;
    final total = kinds.fold(0.0, (a, k) => a + (m[k] ?? 0));
    if (total > 0) return {for (final k in kinds) k: (m[k] ?? 0) / total};
    final v = kinds.fold(0.0, (a, k) => a + valueOf(k));
    if (v > 0) return {for (final k in kinds) k: valueOf(k) / v};
    return {kinds.first: 1};
  }

  /// Average net amount added per month over the six full months before the
  /// snapshot's month, in local time, by kind. A month without a purchase
  /// counts as zero.
  Map<Kind, double> get usualMonthly {
    final at = generatedAt.toLocal();
    final key = monthKey(DateTime(at.year, at.month - 6));
    final last = monthKey(at);
    return {
      for (final k in Kind.values)
        k: (monthly.where((m) => m.month.compareTo(key) >= 0 && m.month.compareTo(last) < 0).fold(0.0, (a, m) => a + m.byKind[k]!) / 6)
            .clamp(0, double.infinity),
    };
  }

  double get usualMonthlyTotal => usualMonthly.values.fold(0, (a, b) => a + b);

  /// How new money splits across kinds: by recent purchases, else by what you hold.
  Map<Kind, double> get mix {
    final u = usualMonthly;
    final total = u.values.fold(0.0, (a, b) => a + b);
    if (total > 0) return {for (final k in Kind.values) k: u[k]! / total};
    if (value > 0) return {for (final k in Kind.values) k: valueOf(k) / value};
    return {Kind.fund: 1};
  }
}
