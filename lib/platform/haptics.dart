import 'haptics_stub.dart' if (dart.library.js_interop) 'haptics_web.dart' as platform;

/// Short physical feedback. Call it from the tap handler itself: Android
/// browsers only vibrate during a gesture, and iPhones only tick for a tap
/// whose handler called it while the finger was down (see web/haptics.js).
class Haptics {
  const Haptics._();

  static void init() => platform.init();
  static void tick() => platform.tick();
  static void selection() => platform.selection();
  static void confirm() => platform.confirm();
}
