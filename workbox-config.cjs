// Generates build/web/sw.js after `flutter build web`:
//   npx --yes workbox-cli@7.3.0 generateSW workbox-config.cjs
module.exports = {
  globDirectory: 'build/web/',
  globPatterns: ['**/*.{html,js,json,wasm,png,webp,svg,ttf,otf,frag,bin}'],
  globIgnores: [
    'sw.js',
    'workbox-*.js',
    'flutter_service_worker.js',
    '**/*.symbols',
    'canvaskit/skwasm*',
    'canvaskit/wimp*',
    'canvaskit/experimental_webparagraph/**',
    'canvaskit/chromium/**',
  ],
  swDest: 'build/web/sw.js',
  // CanvasKit's wasm is ~7 MB.
  maximumFileSizeToCacheInBytes: 10 * 1024 * 1024,
  navigateFallback: 'index.html',
  // Wait for the app to ask (SKIP_WAITING message) before switching versions.
  skipWaiting: false,
  clientsClaim: true,
  cleanupOutdatedCaches: true,
  inlineWorkboxRuntime: true,
};
