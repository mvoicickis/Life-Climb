const CACHE_VERSION = "v3"
const CACHE_NAME = `lifepoints-${CACHE_VERSION}`
const OFFLINE_URL = "/offline.html"

const PRECACHE_URLS = [
  OFFLINE_URL,
  "/icon.png",
  "/icon-192.png",
  "/icon-512.png"
]

self.addEventListener("install", (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE_NAME)
      await cache.addAll(PRECACHE_URLS)
      await self.skipWaiting()
    })()
  )
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys()
      await Promise.all(
        keys
          .filter((key) => key.startsWith("lifepoints-") && key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
      await self.clients.claim()
    })()
  )
})

self.addEventListener("fetch", (event) => {
  const { request } = event
  if (request.method !== "GET") return

  const accept = request.headers.get("accept") || ""
  const isNavigation =
    request.mode === "navigate" || accept.includes("text/html")

  if (isNavigation) {
    event.respondWith(networkFirstNavigation(request))
    return
  }

  event.respondWith(cacheFirstAsset(request))
})

self.addEventListener("push", (event) => {
  let data = {}
  try {
    data = event.data ? event.data.json() : {}
  } catch (_error) {
    data = { body: event.data ? event.data.text() : "LifePoints" }
  }

  const title = data.title || "LifePoints"
  const options = {
    body: data.body || "",
    icon: data.icon || "/icon-192.png",
    badge: data.badge || "/icon-192.png",
    data: {
      url: data.url || "/dashboard"
    }
  }

  event.waitUntil(self.registration.showNotification(title, options))
})

self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const targetUrl = (event.notification.data && event.notification.data.url) || "/dashboard"

  event.waitUntil(
    (async () => {
      const allClients = await self.clients.matchAll({
        type: "window",
        includeUncontrolled: true
      })

      for (const client of allClients) {
        if ("focus" in client) {
          await client.focus()
          if ("navigate" in client) {
            try {
              await client.navigate(targetUrl)
            } catch (_error) {
              // Some browsers disallow navigate; open below as fallback.
            }
          }
          return
        }
      }

      if (self.clients.openWindow) {
        await self.clients.openWindow(targetUrl)
      }
    })()
  )
})

async function networkFirstNavigation(request) {
  try {
    const response = await fetch(request)
    return response
  } catch (_error) {
    const cache = await caches.open(CACHE_NAME)
    const offline = await cache.match(OFFLINE_URL)
    return offline || Response.error()
  }
}

async function cacheFirstAsset(request) {
  const cache = await caches.open(CACHE_NAME)
  const cached = await cache.match(request)
  if (cached) return cached

  try {
    const response = await fetch(request)
    if (response.ok) {
      cache.put(request, response.clone())
    }
    return response
  } catch (_error) {
    return Response.error()
  }
}
