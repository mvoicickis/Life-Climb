// LifePoints PWA Phase B — versioned static cache + offline document fallback.
// Never cache HTML app pages, Turbo navigations, or auth/session POST traffic.

const CACHE_VERSION = "v2"
const CACHE_NAME = `lp-pwa-static-${CACHE_VERSION}`
const OFFLINE_URL = "/offline.html"

const PRECACHE_URLS = [
  OFFLINE_URL,
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
      Promise.all(
        keys
          .filter((key) => key.startsWith("lp-pwa-") && key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    ).then(() => self.clients.claim())
  )
})

function isNavigationRequest(request) {
  return request.mode === "navigate" ||
    (request.method === "GET" && (request.headers.get("accept") || "").includes("text/html"))
}

function isStaticAsset(url) {
  const path = url.pathname
  // Fingerprinted Propshaft/importmap assets + icons. Full URL identity means a
  // new digest after deploy is a cache miss (works with Turbo data-turbo-track).
  return path.startsWith("/assets/") ||
    path.startsWith("/icon") ||
    path === "/favicon.ico" ||
    path === "/apple-touch-icon.png"
}

async function cacheFirst(request) {
  const cache = await caches.open(CACHE_NAME)
  const cached = await cache.match(request)
  if (cached) return cached

  const response = await fetch(request)
  if (response.ok) cache.put(request, response.clone())
  return response
}

async function networkOnlyWithOfflineFallback(request) {
  try {
    // Always prefer a live document — do not read/write HTML app pages into cache.
    const response = await fetch(request)
    return response
  } catch (_) {
    const cache = await caches.open(CACHE_NAME)
    const offline = await cache.match(OFFLINE_URL)
    return offline || new Response("You're offline.", {
      status: 503,
      headers: { "Content-Type": "text/plain; charset=utf-8" }
    })
  }
}

self.addEventListener("fetch", (event) => {
  const request = event.request
  if (request.method !== "GET") return

  const url = new URL(request.url)
  if (url.origin !== self.location.origin) return

  // Offline shell itself: cache-first so the fallback stays available.
  if (url.pathname === OFFLINE_URL) {
    event.respondWith(cacheFirst(request))
    return
  }

  if (isNavigationRequest(request)) {
    event.respondWith(networkOnlyWithOfflineFallback(request))
    return
  }

  if (isStaticAsset(url)) {
    event.respondWith(cacheFirst(request))
  }
})
