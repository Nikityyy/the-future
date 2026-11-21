// A key that never leaves this browser: an AES key made non-extractable, so
// script can use it but nothing can read it out, kept in IndexedDB.
//
// The PIN vault is sealed under the PIN and then once more under this key. A
// six-digit PIN has a million values, few enough to try them all on a copy of
// the browser's storage; without this key a copy cannot even be tried. Here,
// in the app, the tries are counted and the vault erased after ten.
(function () {
  'use strict';

  var DB = 'the-future', STORE = 'keys', ID = 'device';

  function request(r) {
    return new Promise(function (ok, fail) {
      r.onsuccess = function () { ok(r.result); };
      r.onerror = function () { fail(r.error); };
    });
  }
  function db() {
    var r = indexedDB.open(DB, 1);
    r.onupgradeneeded = function () { r.result.createObjectStore(STORE); };
    return request(r);
  }
  // The key, made the first time it is asked for when [create] is true.
  function key(create) {
    return db().then(function (d) {
      return request(d.transaction(STORE).objectStore(STORE).get(ID)).then(function (k) {
        if (k || !create) return k || null;
        return crypto.subtle.generateKey({ name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']).then(function (k) {
          return request(d.transaction(STORE, 'readwrite').objectStore(STORE).put(k, ID)).then(function () { return k; });
        });
      });
    });
  }
  function b64(buf) {
    var s = '';
    new Uint8Array(buf).forEach(function (b) { s += String.fromCharCode(b); });
    return btoa(s);
  }
  function unb64(s) {
    return Uint8Array.from(atob(s), function (c) { return c.charCodeAt(0); });
  }

  window.futureDeviceKey = {
    // The text sealed under the key as base64 (iv, then ciphertext), or null
    // where the browser keeps no keys (some private windows).
    wrap: function (text) {
      return key(true).then(function (k) {
        var iv = crypto.getRandomValues(new Uint8Array(12));
        return crypto.subtle.encrypt({ name: 'AES-GCM', iv: iv }, k, new TextEncoder().encode(text)).then(function (ct) {
          return b64(iv) + '.' + b64(ct);
        });
      }).catch(function () { return null; });
    },
    // The text back, or null when the key is gone or does not fit.
    unwrap: function (sealed) {
      return key(false).then(function (k) {
        if (!k) return null;
        var parts = sealed.split('.');
        return crypto.subtle.decrypt({ name: 'AES-GCM', iv: unb64(parts[0]) }, k, unb64(parts[1])).then(function (pt) {
          return new TextDecoder().decode(pt);
        });
      }).catch(function () { return null; });
    },
    // Forgets the key, so whatever it sealed can never be opened again.
    erase: function () {
      return db().then(function (d) {
        return request(d.transaction(STORE, 'readwrite').objectStore(STORE).delete(ID));
      }).then(function () { return true; }).catch(function () { return false; });
    },
  };
})();
