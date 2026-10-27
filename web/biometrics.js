// Face ID, Touch ID and fingerprint through a passkey (WebAuthn).
//
// Checking a face is not enough on its own: the app needs a secret that only
// a successful check can produce. The PRF extension gives exactly that: the
// passkey derives the same 32 bytes every time, but only after the biometric
// check. The app seals the passphrase under them (see lib/state.dart).
// iOS has it from 18, Chrome and Edge on Android and desktop from 116.
(function () {
  'use strict';

  var SALT = new TextEncoder().encode('the-future/vault/v1');

  function rnd(n) {
    return crypto.getRandomValues(new Uint8Array(n));
  }
  function b64(buf) {
    var s = '';
    new Uint8Array(buf).forEach(function (b) { s += String.fromCharCode(b); });
    return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }
  function unb64(s) {
    s = s.replace(/-/g, '+').replace(/_/g, '/');
    var bin = atob(s + '==='.slice((s.length + 3) % 4));
    return Uint8Array.from(bin, function (c) { return c.charCodeAt(0); });
  }

  window.futureBio = {
    supported: function () {
      if (!window.PublicKeyCredential || !navigator.credentials) return Promise.resolve(false);
      return PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable().catch(function () { return false; });
    },

    label: function () {
      var ua = navigator.userAgent;
      if (/iPhone|iPad/.test(ua)) return 'Face ID';
      if (/Macintosh/.test(ua)) return 'Touch ID';
      return 'biometrics';
    },

    // Creates the passkey. Returns its id, or null when this device cannot do PRF.
    enroll: function () {
      return navigator.credentials
        .create({
          publicKey: {
            challenge: rnd(32),
            rp: { name: 'The Future' },
            user: { id: rnd(16), name: 'the-future', displayName: 'The Future' },
            pubKeyCredParams: [{ type: 'public-key', alg: -7 }, { type: 'public-key', alg: -257 }],
            authenticatorSelection: { authenticatorAttachment: 'platform', userVerification: 'required', residentKey: 'preferred' },
            timeout: 60000,
            extensions: { prf: {} },
          },
        })
        .then(function (cred) {
          var ext = cred.getClientExtensionResults();
          return ext.prf && ext.prf.enabled ? b64(cred.rawId) : null;
        });
    },

    // Asks for the face and returns the secret, or null.
    secret: function (id) {
      return navigator.credentials
        .get({
          publicKey: {
            challenge: rnd(32),
            allowCredentials: [{ type: 'public-key', id: unb64(id) }],
            userVerification: 'required',
            timeout: 60000,
            extensions: { prf: { eval: { first: SALT } } },
          },
        })
        .then(function (a) {
          var r = a.getClientExtensionResults();
          var f = r.prf && r.prf.results && r.prf.results.first;
          return f ? b64(f) : null;
        });
    },
  };
})();
