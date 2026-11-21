import 'dart:js_interop';

@JS('futureDeviceKey.wrap')
external JSPromise<JSString?> _wrap(String text);

@JS('futureDeviceKey.unwrap')
external JSPromise<JSString?> _unwrap(String sealed);

@JS('futureDeviceKey.erase')
external JSPromise<JSBoolean> _erase();

Future<String?> wrap(String text) async {
  try {
    return (await _wrap(text).toDart)?.toDart;
  } catch (_) {
    return null;
  }
}

Future<String?> unwrap(String sealed) async {
  try {
    return (await _unwrap(sealed).toDart)?.toDart;
  } catch (_) {
    return null;
  }
}

Future<void> erase() async {
  try {
    await _erase().toDart;
  } catch (_) {}
}
