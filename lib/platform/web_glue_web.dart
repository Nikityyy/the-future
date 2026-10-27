import 'dart:js_interop';

import 'package:flutter/widgets.dart';

@JS('futureSafeArea')
external JSString _safeArea();

@JS('futureHideSplash')
external void _hideSplash();

@JS('skipWaitingAndReload')
external void _applyUpdate();

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

void applyUpdate() {
  try {
    _applyUpdate();
  } catch (_) {}
}
