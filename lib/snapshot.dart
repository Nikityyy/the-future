import 'projection.dart';

class Holding {
  const Holding({
    required this.name,
    required this.symbol,
    required this.kind,
    required this.amount,
    required this.value,
    required this.invested,
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
      );

  final String name;
  final String symbol;
  final Kind kind;
  final double amount;
  final double value;
  final double invested;

  double get gain => value - invested;
  double get gainPercent => invested > 0 ? gain / invested * 100 : 0;
}

/// What you put in during one calendar month (sells count as minus).
class MonthRow {
  const MonthRow(this.month, this.byKind);

  final String month; // 2026-09
  final Map<Kind, double> byKind;
}

class Snapshot {
  const Snapshot({required this.generatedAt, required this.holdings, required this.monthly});

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
      );

  final DateTime generatedAt;
  final List<Holding> holdings;
  final List<MonthRow> monthly;

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
