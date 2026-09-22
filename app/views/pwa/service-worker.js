const CACHE_VERSION = "v9"
const CACHE_NAME = `lifepoints-${CACHE_VERSION}`
const PAGE_CACHE_NAME = `${CACHE_NAME}-pages`
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

async function syncAppBadgeFromPayload(data) {
  try {
    if (data.badge === undefined || data.badge === null) return
    const count = Number.parseInt(String(data.badge), 10)
    if (!Number.isFinite(count) || count <= 0) {
      if (typeof navigator.clearAppBadge === "function") {
        await navigator.clearAppBadge()
      }
      return
    }
    if (typeof navigator.setAppBadge === "function") {
      await navigator.setAppBadge(count)
    }
  } catch (_error) {
    /* Badging API unsupported in this context */
  }
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
          .filter(
            (key) =>
              key.startsWith("lifepoints-") &&
              key !== CACHE_NAME &&
              key !== PAGE_CACHE_NAME
          )
          .map((key) => caches.delete(key))
      )
      await self.clients.claim()
    })()
  )
})

self.addEventListener("fetch", (event) => {
  const { request } = event
  if (request.method !== "GET") return

  if (isFullPageDocument(request)) {
    const url = new URL(request.url)
    if (url.origin === self.location.origin && isOfflinePageNavigationPath(url.pathname)) {
      event.respondWith(networkFirstOfflinePage(request))
      return
    }
    event.respondWith(networkOnlyDocument(request))
    return
  }

  if (isStaticAsset(request)) {
    event.respondWith(cacheFirstAsset(request))
    return
  }

  event.respondWith(networkOnlyNoStore(request))
})

self.addEventListener("message", (event) => {
  if (event.data && event.data.type === "CLEAR_PAGE_CACHE") {
    event.waitUntil(caches.delete(PAGE_CACHE_NAME))
  }
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
      token: data.token || ""
    },
    ...intensityOptions(data.intensity)
  }

  event.waitUntil(
    (async () => {
      await self.registration.showNotification(title, options)
      await syncAppBadgeFromPayload(data)
    })()
  )
})

async function clearAppBadgeSafe() {
  try {
    if (typeof navigator.clearAppBadge === "function") {
      await navigator.clearAppBadge()
    }
  } catch (_error) {
    /* unsupported */
  }
}

self.addEventListener("notificationclick", (event) => {
  const action = event.action || ""
  const data = (event.notification && event.notification.data) || {}
  event.notification.close()

  if (ACTION_PATHS[action]) {
    event.waitUntil(
      (async () => {
        await clearAppBadgeSafe()
        await handleNotificationAction(action, data)
      })()
    )
    return
  }

  const targetUrl = data.url || "/dashboard"
  event.waitUntil(
    (async () => {
      await clearAppBadgeSafe()
      await openApp(targetUrl)
    })()
  )
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
      body: JSON.stringify({ token: data.token || "" })
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

function isFullPageDocument(request) {
  if (!isDocumentRequest(request)) return false
  if (request.headers.get("Turbo-Frame")) return false
  const accept = request.headers.get("accept") || ""
  if (accept.includes("text/vnd.turbo-stream.html")) return false
  return true
}

function isOfflinePageNavigationPath(pathname) {
  return (
    pathname === "/" ||
    pathname === "/dashboard" ||
    /^\/life_journeys\/\d+$/.test(pathname)
  )
}

function isAllowedPageCachePath(pathname) {
  return pathname === "/dashboard" || /^\/life_journeys\/\d+$/.test(pathname)
}

function pageCacheLookupPath(pathname) {
  return pathname === "/" ? "/dashboard" : pathname
}

function pageCacheRequestForPath(pathname) {
  const path = pageCacheLookupPath(pathname)
  return new Request(new URL(path, self.location.origin).href, { method: "GET" })
}

function isCacheableHtmlDocument(response) {
  const contentType = response.headers.get("content-type") || ""
  if (contentType.includes("text/vnd.turbo-stream.html")) return false
  return contentType.includes("text/html") || contentType.includes("application/xhtml+xml")
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
    return offlineDocumentFallback()
  }
}

async function offlineDocumentFallback() {
  const cache = await caches.open(CACHE_NAME)
  const offline = await cache.match(OFFLINE_URL)
  return offline || Response.error()
}

async function networkFirstOfflinePage(request) {
  const url = new URL(request.url)
  try {
    const response = await fetch(request)
    const finalUrl = new URL(response.url)
    if (
      response.ok &&
      response.status === 200 &&
      !response.redirected &&
      response.type === "basic" &&
      isCacheableHtmlDocument(response) &&
      isAllowedPageCachePath(finalUrl.pathname)
    ) {
      await putPageCache(finalUrl.pathname, response)
    }
    return response
  } catch (_error) {
    const cached = await matchPageCache(pageCacheLookupPath(url.pathname))
    if (cached) return cached
    return offlineDocumentFallback()
  }
}

async function putPageCache(pathname, response) {
  const cachedAt = new Date().toISOString()
  const clone = response.clone()
  const headers = new Headers(clone.headers)
  headers.set("X-LP-Page-Cached-At", cachedAt)
  const body = await clone.arrayBuffer()
  const stored = new Response(body, {
    status: 200,
    statusText: clone.statusText,
    headers
  })
  const cache = await caches.open(PAGE_CACHE_NAME)
  await cache.put(pageCacheRequestForPath(pathname), stored)
}

async function matchPageCache(pathname) {
  const cache = await caches.open(PAGE_CACHE_NAME)
  const cached = await cache.match(pageCacheRequestForPath(pathname))
  if (!cached) return null

  const cachedAt = cached.headers.get("X-LP-Page-Cached-At") || new Date().toISOString()
  const html = await cached.text()
  const meta = `<meta name="lp-offline-snapshot-at" content="${cachedAt.replace(/"/g, "&quot;")}">`
  const injected = html.includes("<head>")
    ? html.replace("<head>", `<head>${meta}`)
    : `${meta}${html}`

  return new Response(injected, {
    headers: { "Content-Type": "text/html; charset=utf-8" }
  })
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
