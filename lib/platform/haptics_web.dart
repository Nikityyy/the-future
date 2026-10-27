import 'dart:js_interop';

@JS('futureHaptic')
external void _haptic(int kind);

@JS('futureHapticsInit')
external void _init();

void init() {
  try {
    _init();
  } catch (_) {}
}

void _play(int kind) {
  try {
    _haptic(kind);
  } catch (_) {}
}

void tick() => _play(0);
void selection() => _play(1);
void confirm() => _play(2);
