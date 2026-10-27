// Haptics for the web build.
//
// Android browsers have navigator.vibrate.
//
// iOS Safari (and the home screen PWA) has no web API for haptics, but plays
// the system tick when the finger flips an <input type="checkbox" switch>.
// Flipping one from script stays silent since iOS 26.5 (tested on an iPhone
// with iOS 27: the finger has to do it). So one invisible switch lies over
// the whole app, inside <flutter-view>: every touch lands on it, bubbles on
// to Flutter as usual, and Flutter decides whether that tap buzzes. A tap
// handler that calls futureHaptic() while the finger is down arms it; when
// the finger lifts without that, the switch lets the click through to the
// app below, so it does not flip and nothing buzzes.
//
// On iOS that means haptics only for taps, on release: Haptics.selection()
// while dragging a wheel, or a tick after something finishes, stays silent.
(function () {
  'use strict';

  // kinds: 0 tick, 1 selection, 2 confirm
  var PATTERNS = [10, 6, [12, 50, 12]];
  var MIN_GAP_MS = 28;
  var last = 0;

  if (typeof navigator.vibrate === 'function') {
    window.futureHaptic = function (kind) {
      var now = performance.now();
      if (now - last < MIN_GAP_MS) return;
      last = now;
      try {
        navigator.vibrate(PATTERNS[kind] || PATTERNS[0]);
      } catch (_) {}
    };
    window.futureHapticsInit = function () {};
    return;
  }

  var coarse =
    typeof window.matchMedia === 'function' &&
    window.matchMedia('(pointer: coarse)').matches;
  var ios =
    /iPhone|iPad|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  if (!coarse || !ios) {
    window.futureHaptic = function () {};
    window.futureHapticsInit = function () {};
    return;
  }

  var layer = null;
  var down = false;
  var armed = false;
  var restoreTimer = 0;

  function passThrough(on) {
    if (layer) layer.style.pointerEvents = on ? 'none' : 'auto';
  }

  // A text field has the keyboard: the switch stays out of its way, so
  // taps place the cursor and the field keeps its focus.
  function editing() {
    var el = document.activeElement;
    return !!el && el !== layer && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable);
  }

  window.futureHaptic = function () {
    if (down) armed = true;
  };

  // Called once the app runs. Flutter has its pointer listeners on window
  // by then, so the pointerup listener here runs after the app's tap
  // handlers.
  window.futureHapticsInit = function () {
    var view = document.querySelector('flutter-view');
    if (layer || !view) return;
    layer = document.createElement('input');
    layer.type = 'checkbox';
    layer.setAttribute('switch', '');
    layer.tabIndex = -1;
    layer.setAttribute('aria-hidden', 'true');
    // Native appearance and opacity 0 (not display:none): the switch has to
    // be really there under the finger for the tick to play.
    layer.style.cssText =
      'position:fixed;left:0;top:0;width:100vw;height:100vh;margin:0;padding:0;' +
      'appearance:auto;-webkit-appearance:auto;opacity:0;z-index:2147483000;' +
      'touch-action:none;-webkit-tap-highlight-color:transparent;' +
      '-webkit-touch-callout:none;-webkit-user-select:none;user-select:none';
    view.appendChild(layer);

    // Never takes focus: a focused switch would pull it from the app and
    // its text fields. Flipping does not need it.
    layer.addEventListener('mousedown', function (e) {
      e.preventDefault();
    });
    layer.addEventListener('focus', function () {
      layer.blur();
    });
    layer.addEventListener('pointerdown', function (e) {
      if (!e.isPrimary) return;
      down = true;
      armed = false;
    });
    window.addEventListener('pointerup', function (e) {
      if (!e.isPrimary || !down) return;
      down = false;
      if (armed) return;
      // Not a tap that buzzes: the click that follows goes to the app
      // below instead of flipping the switch.
      passThrough(true);
      clearTimeout(restoreTimer);
      restoreTimer = setTimeout(function () {
        if (!editing()) passThrough(false);
      }, 250);
    });
    window.addEventListener('pointercancel', function () {
      down = false;
      armed = false;
    });
    window.addEventListener(
      'click',
      function (e) {
        if (e.target === layer || editing()) return;
        clearTimeout(restoreTimer);
        setTimeout(function () {
          if (!editing()) passThrough(false);
        }, 0);
      },
      true
    );
    document.addEventListener('focusin', function () {
      if (editing()) passThrough(true);
    });
    document.addEventListener('focusout', function () {
      setTimeout(function () {
        if (!editing()) passThrough(false);
      }, 0);
    });
  };
})();
