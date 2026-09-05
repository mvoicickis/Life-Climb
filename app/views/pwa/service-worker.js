const CACHE_VERSION = "v8"
const CACHE_NAME = `lifepoints-${CACHE_VERSION}`
const OFFLINE_URL = "/offline.html"
const ASSET_DESTINATIONS = ["style", "script", "font", "image"]
const HTML_CONTENT_TYPES = [
  "text/html",
  "application/xhtml+xml",
  "text/vnd.turbo-stream.html"
]

const PRECACHE_URLS = [
  OFFLINE_URL,
  "/icon.png",
  "/icon-192.png",
  "/icon-maskable-512.png"
]

const DEFAULT_ACTIONS = [
  { action: "quick_add", title: "Quick-add battle" },
  { action: "snooze", title: "Remind me later" }
]

const ACTION_PATHS = {
  quick_add: "/notifications/quick_add",
  mark_done: "/notifications/mark_done",
  snooze: "/notifications/snooze"
}

// Intensity from push JSON (NotificationPreference). iOS/WebKit ignores
// silent / vibrate / requireInteraction — options are dropped, not errors.
function intensityOptions(intensity) {
  switch (intensity) {
    case "gentle":
      return {
        silent: true,
        requireInteraction: false,
        vibrate: []
      }
    case "persistent":
      return {
        requireInteraction: true,
        vibrate: [200, 100, 200],
        silent: false
      }
    default:
      // normal / missing / unknown — omit intensity options (browser defaults)
      return {}
  }
}

function notificationActions(data) {
  if (Array.isArray(data.actions) && data.actions.length > 0) return data.actions
  return DEFAULT_ACTIONS
}

self.addEventListener("install", (event) => {
  event.waitUntil(
    (async () => {
      try {
        const cache = await caches.open(CACHE_NAME)
        await cache.addAll(PRECACHE_URLS)
      } catch (_error) {
        // Precache miss must not block skipWaiting — clients need this fetch fix.
      }
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

  if (isDocumentRequest(request)) {
    event.respondWith(networkOnlyDocument(request))
    return
  }

  if (isStaticAsset(request)) {
    event.respondWith(cacheFirstAsset(request))
    return
  }

  event.respondWith(networkOnlyNoStore(request))
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
    actions: notificationActions(data),
    data: {
      url: data.url || "/dashboard",
      token: data.token || "",
      battle_id: data.battle_id || ""
    },
    ...intensityOptions(data.intensity)
  }

  event.waitUntil(self.registration.showNotification(title, options))
})

self.addEventListener("notificationclick", (event) => {
  const action = event.action || ""
  const data = (event.notification && event.notification.data) || {}
  event.notification.close()

  if (ACTION_PATHS[action]) {
    event.waitUntil(handleNotificationAction(action, data))
    return
  }

  const targetUrl = data.url || "/dashboard"
  event.waitUntil(openApp(targetUrl))
})

async function handleNotificationAction(action, data) {
  const path = ACTION_PATHS[action]
  if (!path) return

  try {
    const response = await fetch(path, {
      method: "POST",
      credentials: "omit",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json"
      },
      body: JSON.stringify({
        token: data.token || "",
        battle_id: data.battle_id || ""
      })
    })
    const payload = await response.json().catch(() => ({}))
    const ok = response.ok && payload.ok
    await self.registration.showNotification(
      ok ? "LifePoints" : "LifePoints",
      {
        body: ok
          ? payload.message || "Done."
          : payload.error || "Could not update your battle.",
        icon: "/icon-192.png",
        badge: "/icon-192.png",
        data: { url: data.url || "/dashboard", token: data.token || "" },
        silent: true
      }
    )
  } catch (_error) {
    await self.registration.showNotification("LifePoints", {
      body: "Could not update your battle.",
      icon: "/icon-192.png",
      badge: "/icon-192.png",
      data: { url: data.url || "/dashboard" },
      silent: true
    })
  }
}

async function openApp(targetUrl) {
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
}

function isDocumentRequest(request) {
  const accept = request.headers.get("accept") || ""
  return (
    request.mode === "navigate" ||
    request.destination === "document" ||
    accept.includes("text/html")
  )
}

function isStaticAsset(request) {
  return ASSET_DESTINATIONS.includes(request.destination)
}

function isHtmlContentType(response) {
  const contentType = response.headers.get("content-type") || ""
  return HTML_CONTENT_TYPES.some((type) => contentType.includes(type))
}

async function networkOnlyDocument(request) {
  try {
    const response = await fetch(request)
    return response
  } catch (_error) {
    const cache = await caches.open(CACHE_NAME)
    const offline = await cache.match(OFFLINE_URL)
    return offline || Response.error()
  }
}

async function networkOnlyNoStore(request) {
  try {
    return await fetch(request)
  } catch (_error) {
    return Response.error()
  }
}

async function cacheFirstAsset(request) {
  const cache = await caches.open(CACHE_NAME)
  const cached = await cache.match(request)
  if (cached) return cached

  try {
    const response = await fetch(request)
    if (response.ok && !isHtmlContentType(response)) {
      cache.put(request, response.clone())
    }
    return response
  } catch (_error) {
    return Response.error()
  }
}
