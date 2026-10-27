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
  const Snapshot({required this.generatedAt, required this.holdings, required this.monthly, this.trades = const [], this.history = const {}});

  factory Snapshot.fromJson(Map<String, dynamic> j) => Snapshot(
        generatedAt: DateTime.parse(j['generatedAt'] as String),
        holdings: [for (final h in j['holdings'] as List) Holding.fromJson(h as Map<String, dynamic>)],
        monthly: [
          for (final m in j['monthly'] as List)
            MonthRow((m as Map<String, dynamic>)['month'] as String, {
              Kind.fund: (m['fund'] as num).toDouble(),
              Kind.crypto: (m['crypto'] as num).toDouble(),
              Kind.metal: (m['metal'] as num).toDouble(),
            }),
        ],
        // Snapshots synced before the export existed have no trades.
        trades: [for (final t in j['trades'] as List? ?? const []) Trade.fromJson(t as Map<String, dynamic>)],
        history: {
          for (final e in (j['history'] as Map<String, dynamic>? ?? const {}).entries)
            e.key: [
              for (final p in e.value as List) (DateTime.fromMillisecondsSinceEpoch(((p as List)[0] as num).toInt() * 1000, isUtc: true), (p[1] as num).toDouble()),
            ],
        },
      );

  final DateTime generatedAt;
  final List<Holding> holdings;
  final List<MonthRow> monthly;
  final List<Trade> trades;

  /// The whole portfolio's value over time, by timeframe: day, week, month,
  /// six_month, year and all. Empty for snapshots synced before it existed.
  final Map<String, List<(DateTime, double)>> history;

  /// Money put in minus money taken out between two moments, from the trades.
  double netAddedBetween(DateTime from, DateTime to) {
    var sum = 0.0;
    for (final t in trades) {
      final d = DateTime.tryParse(t.date);
      if (d == null || t.value == null || d.isBefore(from) || d.isAfter(to)) continue;
      sum += t.side == 'sell' ? -t.value! : t.side == 'buy' ? t.value! : 0;
    }
    return sum;
  }

  /// Money added between two moments, each amount weighted by the share of
  /// the period it was invested (the Modified Dietz weights): bought on the
  /// first day counts in full, bought on the last day not at all.
  double weightedAddedBetween(DateTime from, DateTime to) {
    final span = to.difference(from).inSeconds;
    if (span <= 0) return 0;
    var sum = 0.0;
    for (final t in trades) {
      final d = DateTime.tryParse(t.date);
      if (d == null || t.value == null || d.isBefore(from) || d.isAfter(to)) continue;
      final w = to.difference(d).inSeconds / span;
      sum += w * (t.side == 'sell' ? -t.value! : t.side == 'buy' ? t.value! : 0);
    }
    return sum;
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

  /// Average net amount added per month over the last six months before the
  /// snapshot, by kind. A month without a purchase counts as zero.
  Map<Kind, double> get usualMonthly {
    final from = DateTime.utc(generatedAt.year, generatedAt.month - 6);
    final key = '${from.year}-${from.month.toString().padLeft(2, '0')}';
    final last = '${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}';
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
