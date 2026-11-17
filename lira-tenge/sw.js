// Простой service worker: кэширует оболочку приложения, чтобы оно открывалось офлайн.
// Курс всегда берётся из сети (сам сайт сохраняет последний курс в localStorage).
const C = "lira-tenge-v1";
const SHELL = ["./", "index.html", "manifest.json", "icon.svg", "icon-192.png", "icon-512.png",
  "https://cdnjs.cloudflare.com/ajax/libs/react/18.3.1/umd/react.production.min.js",
  "https://cdnjs.cloudflare.com/ajax/libs/react-dom/18.3.1/umd/react-dom.production.min.js"];
self.addEventListener("install", e => { e.waitUntil(caches.open(C).then(c => c.addAll(SHELL)).catch(() => {})); self.skipWaiting(); });
self.addEventListener("activate", e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== C).map(k => caches.delete(k))))); self.clients.claim(); });
self.addEventListener("fetch", e => {
  const u = e.request.url;
  if (e.request.method !== "GET" || /er-api|currency-api/.test(u)) return; // курс — только из сети
  e.respondWith(fetch(e.request).then(r => { const cp = r.clone(); caches.open(C).then(c => c.put(e.request, cp)); return r; })
    .catch(() => caches.match(e.request)));
});
