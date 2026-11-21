import 'device_key_stub.dart' if (dart.library.js_interop) 'device_key_web.dart' as platform;

/// A key this browser keeps and nothing can read out (see web/devicekey.js).
/// Replaceable so tests can stand in for the browser.
class DeviceKey {
  const DeviceKey._();

  /// [text] sealed under the key, or null where the browser keeps no keys.
  static Future<String?> Function(String text) wrap = platform.wrap;

  /// The text back, or null when the key is gone.
  static Future<String?> Function(String sealed) unwrap = platform.unwrap;

  /// Forgets the key for good.
  static Future<void> Function() erase = platform.erase;
}
