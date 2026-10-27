import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_future/snapshot.dart';
import 'package:the_future/vault.dart';

void main() {
  test('opens what it sealed, and only with the same secret', () async {
    final sealed = await seal('{"a":1}', '123456');
    expect(await open(sealed, '123456'), '{"a":1}');
    expect(() => open(sealed, '654321'), throwsA(isA<WrongSecret>()));
  });

  test('reads a snapshot sealed by tools/sync.mjs', () async {
    final sealed = jsonDecode(File('test/fixtures/sealed.json').readAsStringSync()) as Map<String, dynamic>;
    final s = Snapshot.fromJson(jsonDecode(await open(sealed, 'correct horse battery')) as Map<String, dynamic>);
    expect(s.holdings.single.symbol, 'BTC');
    expect(s.monthly.single.month, '2026-09');
  });
}
