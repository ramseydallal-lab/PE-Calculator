const CACHE_NAME = 'pe-risk-calc-v3-20260330';
const ASSETS = [
  './PE_Risk_Calculator_NSQIP_v3.html',
  './PE_Risk_Calculator_NSQIP_v3_modeldata.js',
  './PE_Risk_Calculator_NSQIP_v3.webmanifest'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  event.respondWith(
    caches.match(request).then(cached => cached || fetch(request).then(response => {
      const clone = response.clone();
      caches.open(CACHE_NAME).then(cache => cache.put(request, clone)).catch(() => {});
      return response;
    }).catch(() => caches.match('./PE_Risk_Calculator_NSQIP_v3.html')))
  );
});
