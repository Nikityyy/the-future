import 'bio_stub.dart' if (dart.library.js_interop) 'bio_web.dart' as platform;

/// Face ID, Touch ID or fingerprint through a passkey (see web/biometrics.js).
class Bio {
  const Bio._();

  static Future<bool> supported() => platform.supported();

  /// "Face ID" on an iPhone.
  static String get label => platform.label();

  /// Creates the passkey: its id, or null when the device cannot derive a secret.
  static Future<String?> enroll() => platform.enroll();

  /// Asks for the face or finger: the secret for [id], or null when cancelled.
  static Future<String?> secret(String id) => platform.secret(id);
}
