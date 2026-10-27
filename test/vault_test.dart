import 'package:flutter_test/flutter_test.dart';
import 'package:the_future/vault.dart';

void main() {
  test('opens what it sealed, and only with the same secret', () async {
    final sealed = await seal('{"a":1}', '123456');
    expect(await open(sealed, '123456'), '{"a":1}');
    expect(() => open(sealed, '654321'), throwsA(isA<WrongSecret>()));
  });
}
