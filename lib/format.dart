import 'package:intl/intl.dart';

final _whole = NumberFormat.decimalPattern('en')..maximumFractionDigits = 0;
final _cents = NumberFormat.decimalPattern('en')
  ..minimumFractionDigits = 2
  ..maximumFractionDigits = 2;

String eur(double v, {bool cents = false}) => '${v < 0 ? '−' : ''}€${(cents ? _cents : _whole).format(v.abs())}';

String signedEur(double v) => '${v < 0 ? '−' : '+'}€${_whole.format(v.abs())}';

String percent(double v, {bool sign = true}) => '${sign ? (v < 0 ? '−' : '+') : ''}${v.abs().toStringAsFixed(1)}%';

String amountOf(double v) =>
    (NumberFormat.decimalPattern('en')..maximumFractionDigits = v.abs() >= 100 ? 1 : 4).format(v);

String ago(DateTime t, [DateTime? now]) {
  final d = (now ?? DateTime.now().toUtc()).difference(t);
  if (d.inMinutes < 2) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 36) return '${d.inHours} h ago';
  return '${d.inDays} days ago';
}
