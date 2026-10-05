/* Public app shell only: never cache credentials, API data, or user media. */
const CACHE_NAME = 'advise-public-shell-v16';
const CORE = [
  './', 'index.html', 'manifest.json', 'flutter_bootstrap.js', 'main.dart.js',
  'favicon.png', 'icons/Icon-192.png', 'icons/Icon-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CORE)));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys().then((keys) => Promise.all(
    keys.filter((key) => key.startsWith('advise-public-shell-') && key !== CACHE_NAME)
      .map((key) => caches.delete(key)),
  )).then(() => self.clients.claim()));
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || request.headers.has('Authorization')) return;
  const url = new URL(request.url);
  const scope = new URL(self.registration.scope);
  if (url.origin !== scope.origin || !url.pathname.startsWith(scope.pathname)) return;
  const path = url.pathname.slice(scope.pathname.length);
  const isShell = CORE.includes(path) || path === '' ||
    path.startsWith('assets/') || path.startsWith('canvaskit/') ||
    path === 'flutter.js' || path === 'main.dart.wasm' || path === 'main.dart.mjs';
  if (!isShell || path.startsWith('api/') || path.startsWith('uploads/')) return;

  event.respondWith(fetch(request).then((response) => {
    if (response.ok && response.type === 'basic') {
      const copy = response.clone();
      event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.put(request, copy)));
    }
    return response;
  }).catch(() => caches.match(request).then((cached) =>
    cached || Promise.reject(new Error('Public app file unavailable offline')))));
});
