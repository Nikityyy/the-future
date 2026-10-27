import 'dart:js_interop';

import 'package:flutter/widgets.dart';

@JS('futureSafeArea')
external JSString _safeArea();

@JS('futureHideSplash')
external void _hideSplash();

@JS('futureSaveFile')
external void _saveFile(JSString name, JSString text);

void saveFile(String name, String text) {
  try {
    _saveFile(name.toJS, text.toJS);
  } catch (_) {}
}

EdgeInsets safeArea() {
  try {
    final v = _safeArea().toDart.split(',').map(double.parse).toList();
    return EdgeInsets.fromLTRB(v[3], v[0], v[1], v[2]);
  } catch (_) {
    return EdgeInsets.zero;
  }
}

void hideSplash() {
  try {
    _hideSplash();
  } catch (_) {}
}
