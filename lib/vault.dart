import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// PBKDF2-SHA256 into AES-256-GCM, the layout tools/snapshot.mjs writes:
/// base64 salt and iv, and the ciphertext with its 16 byte tag at the end.
/// The same code seals the passphrase on this device under the PIN.
const _iterations = 600000;
final _aes = AesGcm.with256bits();

class WrongSecret implements Exception {
  const WrongSecret();
}

Future<SecretKey> _key(String secret, List<int> salt, int iterations) =>
    Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256)
        .deriveKeyFromPassword(password: secret, nonce: salt);

Future<Map<String, dynamic>> seal(String text, String secret) async {
  final salt = _aes.newNonce();
  final box = await _aes.encrypt(utf8.encode(text), secretKey: await _key(secret, salt, _iterations));
  return {
    'v': 1,
    'iter': _iterations,
    'salt': base64.encode(salt),
    'iv': base64.encode(box.nonce),
    'ct': base64.encode([...box.cipherText, ...box.mac.bytes]),
  };
}

Future<String> open(Map<String, dynamic> sealed, String secret) async {
  final ct = base64.decode(sealed['ct'] as String);
  final box = SecretBox(
    ct.sublist(0, ct.length - 16),
    nonce: base64.decode(sealed['iv'] as String),
    mac: Mac(ct.sublist(ct.length - 16)),
  );
  try {
    final key = await _key(secret, base64.decode(sealed['salt'] as String), sealed['iter'] as int);
    return utf8.decode(await _aes.decrypt(box, secretKey: key));
  } on SecretBoxAuthenticationError {
    throw const WrongSecret();
  }
}
