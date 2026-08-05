// LifePoints PWA Phase A — installable + icon precache only.
// Do not cache HTML / Turbo navigations or auth routes.

const CACHE_NAME = "lp-pwa-static-v1"
const PRECACHE_URLS = [
  "/icon.png?v=8",
  "/icon-192.png?v=8",
  "/icon-maskable-512.png?v=8",
  "/apple-touch-icon.png?v=8",
  "/icon.svg?v=8",
  "/favicon.ico?v=8"
]

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE_URLS)).then(() => self.skipWaiting())
  )
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)))
    ).then(() => self.clients.claim())
  )
})

function isStaticAsset(url) {
  const path = url.pathname
  return path.startsWith("/assets/") || path.startsWith("/icon") || path === "/favicon.ico" || path === "/apple-touch-icon.png"
}

self.addEventListener("fetch", (event) => {
  const request = event.request
  if (request.method !== "GET") return

  const url = new URL(request.url)
  if (url.origin !== self.location.origin) return
  if (!isStaticAsset(url)) return

  // Cache-first for fingerprinted assets and icons only.
  event.respondWith(
    caches.open(CACHE_NAME).then(async (cache) => {
      const cached = await cache.match(request)
      if (cached) return cached

      const response = await fetch(request)
      if (response.ok) cache.put(request, response.clone())
      return response
    })
  )
})
