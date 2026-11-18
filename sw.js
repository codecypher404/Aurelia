const CACHE_NAME = 'aurelia-sage-offline-v2.4';
const SAFE_OFFLINE_ASSETS = [
  '/',
  '/manifest.webmanifest'
];
// Never cache sensitive identity documents, payment secrets, or private guest PII records
self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(SAFE_OFFLINE_ASSETS)));
});
