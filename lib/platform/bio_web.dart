import 'dart:js_interop';

@JS('futureBio.supported')
external JSPromise<JSBoolean> _supported();

@JS('futureBio.label')
external JSString _label();

@JS('futureBio.enroll')
external JSPromise<JSString?> _enroll();

@JS('futureBio.secret')
external JSPromise<JSString?> _secret(String id);

Future<bool> supported() async {
  try {
    return (await _supported().toDart).toDart;
  } catch (_) {
    return false;
  }
}

String label() {
  try {
    return _label().toDart;
  } catch (_) {
    return 'Face ID';
  }
}

Future<String?> enroll() async {
  try {
    return (await _enroll().toDart)?.toDart;
  } catch (_) {
    return null;
  }
}

Future<String?> secret(String id) async {
  try {
    return (await _secret(id).toDart)?.toDart;
  } catch (_) {
    return null;
  }
}
