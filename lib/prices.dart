import 'dart:convert';

import 'package:http/http.dart' as http;

import 'demo.dart';
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
  final data = (jsonDecode(res.body) as Map<String, dynamic>)['data'] as List;
  final out = <(DateTime, double)>[];
  for (final c in data) {
    final a = (c as Map<String, dynamic>)['attributes'] as Map<String, dynamic>;
    final t = int.tryParse('${(a['time'] as Map<String, dynamic>?)?['unix']}');
    final v = double.tryParse('${a['close']}');
    if (t != null && v != null) out.add((DateTime.fromMillisecondsSinceEpoch(t * 1000, isUtc: true), v));
  }
  return out..sort((x, y) => x.$1.compareTo(y.$1));
}
