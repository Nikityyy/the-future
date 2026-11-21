import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'demo.dart';
import 'projection.dart' show Kind;
import 'snapshot.dart';

/// The periods a price chart offers: Bitpanda's chart name, label, and words.
const chartPeriods = [
  ('day', '1D', 'in the past day'),
  ('week', '1W', 'in the past week'),
  ('month', '1M', 'in the past month'),
  ('six_month', '6M', 'in the past 6 months'),
  ('year', '1Y', 'in the past year'),
  ('five-years', '5Y', 'in the past 5 years'),
];

/// What the portfolio is compared with: Amundi Core MSCI World UCITS ETF
/// (Acc), as Bitpanda charts it in euros. It keeps its dividends in the
/// fund, so its price is the whole return of MSCI World, less its 0.13% a
/// year. Bitpanda's chart endpoint knows it by its ISIN; its history there
/// starts in January 2024.
const msciWorld = Holding(name: 'MSCI World', symbol: 'MWRE', kind: Kind.fund, amount: 0, value: 0, invested: 0, pid: 'IE000BI8OT95');

final _cache = <String, Future<List<(DateTime, double)>>>{};

/// A holding's price in euros over [period], oldest first, from Bitpanda's
/// public chart endpoint (no key; the browser may ask it directly). Kept for
/// the session; a failed load is forgotten so the next look tries again.
Future<List<(DateTime, double)>> prices(Holding h, String period) async {
  final pid = h.pid;
  if (pid == null) return const [];
  if (pid == 'demo') return demoPrices(h, period);
  // Six months is the last half of the daily year.
  if (period == 'six_month') {
    final from = DateTime.now().subtract(const Duration(days: 183));
    return [for (final p in await prices(h, 'year')) if (p.$1.isAfter(from)) p];
  }
  // A fund or stock trades in sessions, and Bitpanda's day is only today's
  // session. Today's change, as every market app shows it, is against the
  // last close before it, which the hourly week has.
  if (period == 'day' && h.kind != Kind.crypto) {
    final (day, week) = await (_cached(pid, 'day'), _cached(pid, 'week')).wait;
    if (day.isEmpty) return day;
    final before = [for (final p in week) if (p.$1.isBefore(day.first.$1)) p];
    return [if (before.isNotEmpty) before.last, ...day];
  }
  return _cached(pid, period);
}

Future<List<(DateTime, double)>> _cached(String pid, String period) async {
  final key = '$pid/$period';
  final load = _cache[key] ??= _load(pid, period);
  try {
    return await load;
  } catch (_) {
    _cache.remove(key);
    rethrow;
  }
}

Future<List<(DateTime, double)>> _load(String pid, String period) async {
  final res = await http.get(Uri.https('api.bitpanda.com', '/v3/ohlc/$pid/EUR/$period')).timeout(const Duration(seconds: 12));
  if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
  return candleLine((jsonDecode(res.body) as Map<String, dynamic>)['data'] as List, DateTime.now().toUtc());
}

/// The price line in Bitpanda's candles. A candle is stamped with the moment
/// it opens, and its close is the price when it ends: when the next one
/// opens, or [now] for the last, which is still going. So the line starts
/// at the first candle's open and puts each close at its candle's end; at
/// the stamps, every price would sit one candle early (a whole day on 1Y)
/// and the change would leave out the first candle.
List<(DateTime, double)> candleLine(List<dynamic> data, DateTime now) {
  final candles = <(int, double, double)>[];
  for (final c in data) {
    final a = (c as Map<String, dynamic>)['attributes'] as Map<String, dynamic>;
    final t = int.tryParse('${(a['time'] as Map<String, dynamic>?)?['unix']}');
    final (open, close) = (double.tryParse('${a['open']}'), double.tryParse('${a['close']}'));
    if (t != null && open != null && close != null) candles.add((t, open, close));
  }
  if (candles.isEmpty) return const [];
  candles.sort((x, y) => x.$1.compareTo(y.$1));
  // The length of one candle: the shortest step between two. A market
  // closes overnight, so a longer step is a pause, not a longer candle.
  var step = 0;
  for (var i = 1; i < candles.length; i++) {
    final d = candles[i].$1 - candles[i - 1].$1;
    if (d > 0 && (step == 0 || d < step)) step = d;
  }
  DateTime at(int s) => DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);
  final last = now.millisecondsSinceEpoch ~/ 1000;
  return [
    (at(candles.first.$1), candles.first.$2),
    for (final c in candles) (at(step == 0 ? last : math.min(c.$1 + step, last)), c.$3),
  ];
}

/// The price right now, from Bitpanda, never from the session cache; null
/// when it cannot be reached or looks unlike the price at the last sync
/// (a different unit, say). A fund before its market opens has no day yet:
/// then its last close, which the hourly week has.
Future<double?> latestPrice(Holding h) async {
  final pid = h.pid;
  if (pid == null || pid == 'demo' || h.amount <= 0) return null;
  try {
    var pts = await _load(pid, 'day');
    if (pts.isEmpty) pts = await _load(pid, 'week');
    if (pts.isEmpty) return null;
    final price = pts.last.$2, before = h.value / h.amount;
    return price > 0 && (price / before - 1).abs() < 0.5 ? price : null;
  } catch (_) {
    return null;
  }
}

/// What [kinds] of your holdings together were worth at each moment of
/// [grid]: the units you held then times the price then, summed. Bitpanda's
/// own history is only for the whole portfolio, so this is how a single kind
/// gets a line. A holding whose prices cannot be had stays at its price from
/// the last sync, so one odd coin does not take the whole line down.
Future<List<(DateTime, double)>> kindValues(Snapshot s, Set<Kind> kinds, String frame, List<DateTime> grid) async {
  final period = frame == 'all' ? 'five-years' : frame;
  final held = [for (final h in s.holdings) if (kinds.contains(h.kind)) h];
  final series = await Future.wait([
    for (final h in held)
      prices(h, period).then<List<(DateTime, double)>>((p) => p, onError: (Object _) => const <(DateTime, double)>[]),
  ]);
  return valueSeries(grid, [
    for (final (i, h) in held.indexed)
      (units: s.unitsOver(h, grid), prices: series[i], fallback: h.amount > 0 ? h.value / h.amount : 0.0),
  ]);
}

/// The sum over [parts] of units times price at every moment of [grid]. A
/// price holds until the next one; before the first it is the first.
/// [units] holds a part's units at each moment of [grid].
List<(DateTime, double)> valueSeries(List<DateTime> grid, List<({List<double> units, List<(DateTime, double)> prices, double fallback})> parts) {
  final next = List.filled(parts.length, 0);
  return [
    for (final (g, t) in grid.indexed)
      (t, () {
        var sum = 0.0;
        for (final (i, p) in parts.indexed) {
          var price = p.fallback;
          if (p.prices.isNotEmpty) {
            while (next[i] + 1 < p.prices.length && !p.prices[next[i] + 1].$1.isAfter(t)) {
              next[i]++;
            }
            price = p.prices[next[i]].$2;
          }
          sum += p.units[g] * price;
        }
        return sum;
      }()),
  ];
}

/// What the money in [pts] would have been worth in [index] instead. The
/// value at the first point buys index units at that moment's price, and
/// every buy or sell in [kinds] from then on buys or sells index units for
/// the same euros at its own moment: the same money in at the same times,
/// only the investment differs. A price holds until the next one. Empty
/// when [index] starts more than a week after [pts]: there is nothing to
/// compare the start with.
List<(DateTime, double)> benchmarkLine(List<(DateTime, double)> pts, List<(DateTime, double)> index, List<Trade> trades, {Set<Kind>? kinds}) {
  if (pts.isEmpty || index.isEmpty || index.first.$1.isAfter(pts.first.$1.add(const Duration(days: 7)))) return const [];
  double priceAt(DateTime t) {
    var lo = 0, hi = index.length - 1;
    if (index.first.$1.isAfter(t)) return index.first.$2;
    while (lo < hi) {
      final m = (lo + hi + 1) >> 1;
      index[m].$1.isAfter(t) ? hi = m - 1 : lo = m;
    }
    return index[lo].$2;
  }

  final t0 = pts.first.$1;
  final flows = [
    for (final t in trades)
      if ((t.side == 'buy' || t.side == 'sell') && t.value != null && (kinds == null || kinds.contains(t.kind)))
        if (DateTime.tryParse(t.date) case final d? when !d.isBefore(t0)) (d, t.side == 'sell' ? -t.value! : t.value!),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  var units = pts.first.$2 / priceAt(t0);
  var next = 0;
  return [
    for (final (t, _) in pts)
      () {
        for (; next < flows.length && !flows[next].$1.isAfter(t); next++) {
          units += flows[next].$2 / priceAt(flows[next].$1);
        }
        return (t, units * priceAt(t));
      }(),
  ];
}
