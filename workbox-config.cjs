// Generates build/web/sw.js after `flutter build web`:
//   npx --yes workbox-cli@7.3.0 generateSW workbox-config.cjs
module.exports = {
  globDirectory: 'build/web/',
  globPatterns: ['**/*.{html,js,mjs,json,wasm,png,webp,svg,ttf,otf,frag,bin}'],
  globIgnores: [
    'sw.js',
    'workbox-*.js',
    'flutter_service_worker.js',
    '**/*.symbols',
    // Browsers with WasmGC (Chrome, Safari 18.2+) run main.dart.wasm on skwasm.
    // Older ones fall back to main.dart.js on CanvasKit: cached the first time
    // they load it (runtimeCaching below), not downloaded by everyone.
    'main.dart.js',
    'canvaskit/canvaskit.*',
    'canvaskit/skwasm_heavy*',
    'canvaskit/wimp*',
    'canvaskit/experimental_webparagraph/**',
    'canvaskit/chromium/**',
  ],
  swDest: 'build/web/sw.js',
  maximumFileSizeToCacheInBytes: 10 * 1024 * 1024,
  runtimeCaching: [{ urlPattern: /(main\.dart\.js|canvaskit\/canvaskit\.(js|wasm))$/, handler: 'NetworkFirst', options: { cacheName: 'fallback' } }],
  navigateFallback: 'index.html',
  // A new version takes over at once; the page then reloads itself (see index.html).
  skipWaiting: true,
  clientsClaim: true,
  cleanupOutdatedCaches: true,
  inlineWorkboxRuntime: true,
};
